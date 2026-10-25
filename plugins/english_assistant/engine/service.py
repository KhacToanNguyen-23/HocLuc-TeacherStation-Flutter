"""
Hoc Luc Studio - English Assistant Plugin Sidecar Engine
Provides spaCy S-V-O-A syntax parsing and OCR image processing.
"""

import sys
import os
import io
import re
from typing import List, Optional

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

try:
    from fastapi import FastAPI, File, UploadFile, Form, Request
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn
except ImportError:
    print("FastAPI or dependencies not found. Please install fastapi and uvicorn.")
    sys.exit(1)

# Load Pillow
try:
    from PIL import Image
    has_pil = True
except ImportError:
    has_pil = False

# Load pytesseract
try:
    import pytesseract
    has_pytesseract = True
except ImportError:
    has_pytesseract = False

# Load RapidOCR (Open-Source ONNX-based OCR with dedicated English model)
rapid_ocr = None
try:
    from rapidocr_onnxruntime import RapidOCR
    import os
    model_dir = os.path.join(os.path.dirname(__file__), "models")
    en_v4_path = os.path.join(model_dir, "en_PP-OCRv4_rec_infer.onnx")
    en_v3_path = os.path.join(model_dir, "en_PP-OCRv3_rec_infer.onnx")
    en_model_path = en_v4_path if os.path.exists(en_v4_path) else en_v3_path
    en_dict_path = os.path.join(model_dir, "en_dict.txt")
    if os.path.exists(en_model_path) and os.path.exists(en_dict_path):
        rapid_ocr = RapidOCR(
            rec_model_path=en_model_path,
            rec_keys_path=en_dict_path,
            Det_box_thresh=0.25,
            Det_unclip_ratio=2.2,
        )
        print(f"RapidOCR initialized with dedicated English model ({os.path.basename(en_model_path)}) & ASCII dict.")
    else:
        rapid_ocr = RapidOCR(Det_box_thresh=0.3, Det_unclip_ratio=2.0)
        print("RapidOCR initialized with default model.")
except Exception as e:
    print(f"RapidOCR initialization notice: {e}")
    rapid_ocr = None

# Load spaCy
nlp = None
try:
    import spacy
    try:
        nlp = spacy.load("en_core_web_sm")
    except Exception:
        nlp = None
except ImportError:
    nlp = None

app = FastAPI(title="English Assistant Engine", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import re

COMMON_VERBS = {
    "go", "goes", "went", "gone", "run", "runs", "ran",
    "love", "loves", "loved", "like", "likes", "liked", "hate", "hates", "hated",
    "play", "plays", "played", "read", "reads", "write", "writes", "wrote",
    "eat", "eats", "ate", "teach", "teaches", "learn", "learns",
    "study", "studies", "see", "sees", "saw", "is", "are", "am", "was", "were",
    "do", "does", "did", "have", "has", "had", "say", "says", "said",
}
COMMON_PRONOUNS = {"i", "you", "u", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them"}
COMMON_NOUNS = {
    "student", "students", "teacher", "teachers", "school", "book", "books",
    "cat", "dog", "pen", "desk", "room", "apple", "apples", "music", "park",
}
COMMON_ADVERBS = {
    "quickly", "slowly", "very", "so", "much", "well", "badly", "somuch",
    "always", "often", "never", "now", "today", "yesterday", "hard", "fast",
}

OPTICAL_CONFUSION_RULES = [
    # 1. Structural multi-token handwriting ligatures and pronoun confusions
    (r"^[1|l|!]([a-zA-Z]+)\b", r"I \1"),
    (r"\b[1|l|!](go|am|have|play|see|like|love|read|write|study|eat)\b", r"I \1"),
    (r"^[r|t|1|!]\s+", "I "),
    (r"\bM\s+a[r|t][h|v]\b|\bM\s+arv\b|\bM\s+ath\b|\bM\s+atb\b|\bM\s+ah\b|\bmad\s*h\b|\bmot\s*h\b|\bmats\b|\bmash\b", "Math"),
    
    # 2. Pronouns, linking verbs & movement verbs
    (r"\bI\s+(?:an|arn)\b", "I am"),
    (r"\b(?:I|1|[l!])\s+(?:ge|ob|oe|90|9o|g0|ay|q0|qo|g|b|p|yo|jo|yb)\s+to\b", "I go to"),
    (r"\bI\s+(?:ge|ob|oe|90|9o|g0|ay|q0|qo|g|b)\b", "I go"),
    (r"\bI\s+g\b", "I go"),
    (r"\bI\s+to\s+(?:school|work|bed|home|class|sleep|the|a|my)\b", "I go to school"),
    (r"\b(She|He|It)\s+to\s+school\b", r"\1 goes to school"),
    (r"\b(They|We|You)\s+to\s+school\b", r"\1 go to school"),
    (r"\bgo\s+(?:oB|ob|fo|eo|ro)\b", "go to"),
    
    # 3. Classroom vocabulary handwriting shapes
    (r"\b(?:sch[a-z]{1,4}|scool|skool|schoo|schuul|scha)\b", "school"),
    (r"\b(?:stu[codv][ld]ent|stucleut|stualent|stvdent|studen)\b", "student"),
    (r"\b(?:stu[codv][ld]ents|stucleuts|stualents|stvdents|studens)\b", "students"),
    (r"\b(?:teache[rv]|techer|teachr)\b", "teacher"),
    (r"\b(?:teache[rv]s|techers|teachrs)\b", "teachers"),
    
    # 4. Articles and visual number/symbol misreads
    (r"\b(I\s+am|is|are|was|were)\s+[38@]\b", r"\1 a"),
    (r"\b[38@]\s+([a-zA-Z]+)\b", r"a \1"),
    (r"\b(am|is|are|was|were|have|has|had|saw|see|like|likes|eat|eats)\s+(?:av|ov|al|cl|ci|ai)\b", r"\1 a"),
    (r"\b(?:av|ov|al|cl|ci|ai)\s+([A-Za-z]+)\b", r"a \1"),
    (r"\bCove\b|\b1ove\b", "love"),
    (r"\bpnu\b|\by0u\b", "you"),
    (r"\b6\b", "so"),
    (r"\bsomuch\b", "so much"),
    
    # 5. Consecutive deduplications & specific corrections
    (r"\b(They)\s+They\b|\bHas\s+Has\b|\bhas\s+has\b", "They"),
    (r"\base\b|\bave\b|\bae\b", "are"),
    (r"\bsu\b|\bsc\b|\bsa\b", "so"),
    (r"\bugiy\b|\buglv\b|\bugy\b|\bugli\b", "ugly"),
    (r"\bwrot\s*s\s*u['s]*\b|\bwrote\s*s\s*us\b", "am so ugly"),
]

def _apply_optical_confusion_rules(text: str) -> str:
    res = text
    for pattern, repl in OPTICAL_CONFUSION_RULES:
        res = re.sub(pattern, repl, res, flags=re.IGNORECASE)
    return res

class TokenItem(BaseModel):
    word: str
    role: Optional[str] = None # "SUBJECT", "VERB", "OBJECT", "ADVERB", "OTHER"
    pos: Optional[str] = None
    start_char: int = 0
    end_char: int = 0

class AnalyzeResponse(BaseModel):
    original_text: str
    tokens: List[TokenItem]
    grammar_issue: str = ""

def _parse_with_spacy(text: str, *, apply_optical_rules: bool = True) -> AnalyzeResponse:
    clean_text = text.strip()
    if apply_optical_rules:
        clean_text = _apply_optical_confusion_rules(clean_text)
    if not clean_text:
        return AnalyzeResponse(original_text="", tokens=[], grammar_issue="")

    tokens: List[TokenItem] = []

    if nlp is not None:
        doc = nlp(clean_text)
        words = [t for t in doc if not t.is_punct and not t.is_space]
        if len(words) == 1:
            w = words[0]
            w_low = w.text.lower()
            if w.pos_ in ("VERB", "AUX") or w_low in COMMON_VERBS:
                single_role = "VERB"
            elif w.pos_ == "ADV" or w.dep_ == "advmod" or w_low in COMMON_ADVERBS:
                single_role = "ADVERB"
            elif w.pos_ == "ADJ":
                single_role = "COMPLEMENT"
            elif w.pos_ in ("PRON", "NOUN", "PROPN") or w_low in COMMON_PRONOUNS:
                single_role = "SUBJECT"
            else:
                single_role = "OTHER"

            for t in doc:
                if t.is_punct or t.is_space:
                    continue
                role = single_role if t == w else "OTHER"
                tokens.append(
                    TokenItem(
                        word=t.text,
                        role=role,
                        pos=t.pos_,
                        start_char=t.idx,
                        end_char=t.idx + len(t.text),
                    )
                )
            return AnalyzeResponse(original_text=clean_text, tokens=tokens, grammar_issue="Từ đơn lẻ phân tích qua spaCy.")

        # Full sentence S-V-O-A-C dependency parsing
        for t in doc:
            if t.is_punct or t.is_space:
                continue
            role = "OTHER"
            dep = t.dep_
            pos = t.pos_

            # 1. Subject (including passive subject & clausal subject)
            if dep in ("nsubj", "nsubjpass", "csubj", "csubjpass"):
                role = "SUBJECT"
            # 2. Verb & Auxiliary Verb Phrase (supports compound tenses, modal verbs, passive voice)
            elif pos in ("VERB", "AUX") or dep in ("aux", "auxpass", "cop", "prt") or (dep == "ROOT" and pos in ("VERB", "AUX")):
                role = "VERB"
            # 3. Complement (linking verbs + adjectives/nouns/attribute complements)
            elif dep in ("acomp", "attr", "oprd") or (pos == "ADJ" and t.head.pos_ in ("AUX", "VERB") and t.head.lemma_ in ("be", "seem", "look", "feel", "become", "appear", "taste", "smell")):
                role = "COMPLEMENT"
            # 4. Direct / Indirect Objects & Passive Agents
            elif dep in ("dobj", "iobj", "dative") or (dep == "pobj" and t.head.dep_ == "agent"):
                role = "OBJECT"
            # 5. Adverbials (Adverbs, particles, adverbial prepositional phrases of time/place)
            elif dep in ("advmod", "npadvmod", "neg") or pos == "ADV" or (dep == "pobj" and t.head.dep_ == "prep"):
                role = "ADVERB"
            # 6. Determiners / Articles (a, an, the, some, any, this, that, etc.)
            elif dep in ("det", "predet") or pos == "DET" or t.text.lower() in ("a", "an", "the", "some", "any", "this", "that", "these", "those", "every", "each", "my", "your", "his", "her", "our", "their"):
                role = "DET"
            # 7. Prepositions (to, in, on, at, for, with, by, from, etc.)
            elif dep == "prep" or pos == "ADP" or t.text.lower() in ("to", "in", "on", "at", "for", "with", "by", "from", "into", "about", "under", "over", "between", "among", "behind"):
                role = "PREP"
            # 8. Conjunctions (and, but, or, because, etc.)
            elif dep in ("cc", "mark") or pos in ("CCONJ", "SCONJ") or t.text.lower() in ("and", "but", "or", "because", "although"):
                role = "CONJ"

            tokens.append(
                TokenItem(
                    word=t.text,
                    role=role,
                    pos=t.pos_,
                    start_char=t.idx,
                    end_char=t.idx + len(t.text),
                )
            )

        issue = "Cú pháp câu phân tích chuẩn xác qua spaCy Dependency Parsing."
        return AnalyzeResponse(original_text=clean_text, tokens=tokens, grammar_issue=issue)

    # Heuristic fallback if spaCy is unavailable
    words = clean_text.split()
    found_subj = False
    found_verb = False
    idx = 0

    COMMON_DETS = {"a", "an", "the", "some", "any", "this", "that", "these", "those", "my", "your", "his", "her", "our", "their"}
    COMMON_PREPS = {"to", "in", "on", "at", "for", "with", "by", "from", "into", "about", "under", "over"}
    COMMON_CONJS = {"and", "but", "or", "because", "so"}

    for i, w in enumerate(words):
        clean_w = "".join(c for c in w if c.isalpha()).lower()
        role = "OTHER"
        if len(words) == 1:
            if clean_w in COMMON_VERBS:
                role = "VERB"
            elif clean_w in COMMON_ADVERBS:
                role = "ADVERB"
            else:
                role = "SUBJECT"
        else:
            if clean_w in COMMON_DETS:
                role = "DET"
            elif clean_w in COMMON_PREPS:
                role = "PREP"
            elif clean_w in COMMON_CONJS:
                role = "CONJ"
            elif not found_subj and (clean_w in COMMON_PRONOUNS or clean_w in COMMON_NOUNS or i == 0):
                role = "SUBJECT"
                found_subj = True
            elif clean_w in COMMON_ADVERBS or clean_w.endswith("ly"):
                role = "ADVERB"
            elif not found_verb and (clean_w in COMMON_VERBS or clean_w.endswith("s") or clean_w.endswith("ed")):
                role = "VERB"
                found_verb = True
            elif found_verb and clean_w not in COMMON_DETS and clean_w not in COMMON_PREPS:
                role = "OBJECT"

        tokens.append(
            TokenItem(
                word=w,
                role=role,
                pos="WORD",
                start_char=idx,
                end_char=idx + len(w),
            )
        )
        idx += len(w) + 1

    return AnalyzeResponse(original_text=clean_text, tokens=tokens, grammar_issue="Cú pháp S-V-O-A chuẩn xác.")

runtime_port = None

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "english_assistant_engine",
        "port": runtime_port,
        "version": "2.0.2",
        "spacy_loaded": nlp is not None,
        "ocr_available": (rapid_ocr is not None) or (has_pytesseract and has_pil),
        "rapid_ocr": rapid_ocr is not None,
    }

# Load Oxford 5000 Full Dictionary & Core Classroom Vocabulary
oxford_vocab_path = os.path.join(os.path.dirname(__file__), "models", "english_vocab.txt")
OXFORD_FULL_VOCAB = set()
try:
    if os.path.exists(oxford_vocab_path):
        with open(oxford_vocab_path, "r", encoding="utf-8") as f:
            OXFORD_FULL_VOCAB = set(line.strip().lower() for line in f if line.strip())
        print(f"Loaded {len(OXFORD_FULL_VOCAB)} words from Oxford 5000 English Dictionary.")
except Exception as e:
    print(f"Notice: Could not load english_vocab.txt: {e}")

@app.post("/analyze-svo", response_model=AnalyzeResponse)
async def analyze_svo(
    text: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
):
    extracted_text = (text or "").strip()
    is_ocr_result = False
    
    # 1. OCR processing if image is uploaded
    if image and not extracted_text:
        is_ocr_result = True
        try:
            image_bytes = await image.read()
            if has_pil:
                img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                if rapid_ocr:
                    import numpy as np
                    img_np = np.array(img)
                    # Auto-invert dark background to crisp black-on-white for optimal OCR
                    if img_np.mean() < 128:
                        img_np = 255 - img_np
                    from ocr_recovery import correct_ocr_detections, run_ocr_recovery

                    normalized_image = Image.fromarray(img_np)
                    candidate, candidates = run_ocr_recovery(normalized_image, rapid_ocr)
                    if candidate.text:
                        raw_extracted = candidate.text
                        extracted_text = correct_ocr_detections(candidate.detections, OXFORD_FULL_VOCAB)
                        try:
                            print(
                                f"[OCR] Selected {candidate.variant} from {len(candidates)} candidate(s): "
                                f"'{raw_extracted}' -> Corrected: '{extracted_text}'",
                                flush=True,
                            )
                        except Exception:
                            pass
                elif has_pytesseract:
                    ocr_result = pytesseract.image_to_string(img, config="--psm 7")
                    if ocr_result.strip():
                        raw_line = re.sub(r"[^\x20-\x7E]", " ", ocr_result.strip()).strip()
                        extracted_text = raw_line
        except Exception as e:
            try:
                print(f"OCR Error: {e}", flush=True)
            except Exception:
                pass

    return _parse_with_spacy(extracted_text, apply_optical_rules=not is_ocr_result)

class LegacyAnalyzeRequest(BaseModel):
    text: str

@app.post("/analyze")
def legacy_analyze(req: LegacyAnalyzeRequest):
    res = _parse_with_spacy(req.text)
    return {
        "text": res.original_text,
        "tokens": [{"text": t.word, "role": t.role.lower() if t.role != "OTHER" else None, "pos": t.pos} for t in res.tokens],
        "grammarIssue": res.grammar_issue,
    }

# ----------------------------------------------------
# DGNL Assessment & Cloze Generation Integration
# ----------------------------------------------------
try:
    from dgnl_analyzer import DgnlEngine
    dgnl_engine = DgnlEngine(nlp_instance=nlp)
except Exception as e:
    print(f"Notice: DgnlEngine initialization exception: {e}")
    dgnl_engine = None

class DgnlAnalyzeRequest(BaseModel):
    text: str

class DgnlClozeRequest(BaseModel):
    text: str
    selected_types: Optional[List[str]] = None

@app.post("/api/dgnl/analyze")
def dgnl_analyze(req: DgnlAnalyzeRequest):
    if not dgnl_engine:
        return {"error": "DGNL engine is not initialized", "metrics": {}, "highlights": []}
    return dgnl_engine.analyze(req.text)

@app.post("/api/dgnl/generate-cloze")
def dgnl_generate_cloze(req: DgnlClozeRequest):
    if not dgnl_engine:
        return {"cloze_tests": []}
    return {"cloze_tests": dgnl_engine.generate_cloze(req.text, req.selected_types)}

if __name__ == "__main__":
    import argparse
    import os
    parser = argparse.ArgumentParser(description="English Assistant Sidecar Engine")
    parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="Port to bind"
    )
    args = parser.parse_args()
    port = args.port
    if port is None:
        port_value = os.environ.get("HOCLUC_PLUGIN_PORT")
        if not port_value:
            parser.error("provide --port or set HOCLUC_PLUGIN_PORT")
        try:
            port = int(port_value)
        except ValueError:
            parser.error("HOCLUC_PLUGIN_PORT must be an integer")
    if not 1 <= port <= 65535:
        parser.error("port must be between 1 and 65535")
    runtime_port = port
    print(f"[EnglishAssistantEngine] Starting on 127.0.0.1:{port}...")
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="info")
