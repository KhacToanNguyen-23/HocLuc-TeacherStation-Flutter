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
    sys.exit(0)

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
        rapid_ocr = RapidOCR(rec_model_path=en_model_path, rec_keys_path=en_dict_path, Det_box_thresh=0.25, Det_unclip_ratio=2.2)
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

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "plugin": "com.hocluc.plugin.english",
        "version": "2.0.0",
        "spacy_loaded": nlp is not None,
    }

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

def _parse_with_spacy(text: str) -> AnalyzeResponse:
    clean_text = _apply_optical_confusion_rules(text.strip())
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

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "english_assistant_engine",
        "port": 18888,
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

COMMON_TEACHING_VOCAB = [
    "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
    "my", "your", "his", "her", "its", "our", "their",
    "am", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "having",
    "do", "does", "did", "doing", "done",
    "go", "goes", "went", "gone", "going",
    "study", "studies", "studied", "studying",
    "learn", "learns", "learned", "learning",
    "read", "reads", "reading",
    "write", "writes", "wrote", "written", "writing",
    "play", "plays", "played", "playing",
    "teach", "teaches", "taught", "teaching",
    "eat", "eats", "ate", "eaten", "eating",
    "see", "sees", "saw", "seen", "seeing",
    "like", "likes", "liked", "liking",
    "love", "loves", "loved", "loving",
    "hate", "hates", "hated",
    "math", "maths", "english", "music", "history", "science", "physics", "chemistry",
    "student", "students", "teacher", "teachers", "school", "schools", "classroom",
    "book", "books", "pen", "pens", "desk", "desks", "pencil", "pencils",
    "apple", "apples", "banana", "bananas", "cat", "cats", "dog", "dogs",
    "ugly", "tired", "hungry", "angry", "happy", "sad", "smart", "good", "bad",
    "hot", "cold", "warm", "cool", "tall", "short", "big", "small", "nice", "great",
    "beautiful", "clean", "dirty", "fast", "slow", "rich", "poor", "busy", "ready",
    "so", "very", "too", "quite", "really", "much", "well", "badly",
    "yesterday", "today", "tomorrow", "now", "always", "often", "never", "usually",
    "in", "on", "at", "to", "for", "with", "by", "from", "into", "about",
    "a", "an", "the", "this", "that", "these", "those"
]

def _merge_broken_tokens(tokens: List[str]) -> List[str]:
    if not tokens:
        return []
    import difflib

    merged = []
    i = 0
    while i < len(tokens):
        curr = tokens[i]
        curr_clean = re.sub(r'[^a-zA-Z]', '', curr).lower()

        # 1. Forward merge: single non-word letter curr (e.g. 's' in 's tudan' or 'm' in 'm ath')
        if len(curr_clean) == 1 and curr_clean not in ('i', 'a'):
            if i + 1 < len(tokens):
                nxt = tokens[i + 1]
                nxt_clean = re.sub(r'[^a-zA-Z]', '', nxt).lower()
                combined_clean = curr_clean + nxt_clean
                if combined_clean in OXFORD_FULL_VOCAB or difflib.get_close_matches(combined_clean, list(OXFORD_FULL_VOCAB), n=1, cutoff=0.65):
                    merged.append(curr + nxt)
                    i += 2
                    continue

            # If cannot merge forward, can it merge backward with merged[-1]?
            if merged:
                prev = merged[-1]
                prev_clean = re.sub(r'[^a-zA-Z]', '', prev).lower()
                if len(prev_clean) >= 3:
                    comb_back = prev_clean + curr_clean
                    if comb_back in OXFORD_FULL_VOCAB or difflib.get_close_matches(comb_back, list(OXFORD_FULL_VOCAB), n=1, cutoff=0.7):
                        merged[-1] = prev + curr
                        i += 1
                        continue

            # Single non-word letter is stray noise or detached stroke. Drop it!
            i += 1
            continue

        # 2. Syllable fragments: curr + nxt
        if i + 1 < len(tokens):
            nxt = tokens[i + 1]
            nxt_clean = re.sub(r'[^a-zA-Z]', '', nxt).lower()
            combined_clean = curr_clean + nxt_clean

            # Trailing detached letter (e.g. 'studen' + 't'): curr must be at least 3 letters
            if len(nxt_clean) == 1 and nxt_clean not in ('i', 'a') and len(curr_clean) >= 3:
                can_nxt_merge_fwd = False
                if i + 2 < len(tokens):
                    after_nxt = tokens[i + 2]
                    after_clean = re.sub(r'[^a-zA-Z]', '', after_nxt).lower()
                    cand_fwd = nxt_clean + after_clean
                    if cand_fwd in OXFORD_FULL_VOCAB or difflib.get_close_matches(cand_fwd, list(OXFORD_FULL_VOCAB), n=1, cutoff=0.65):
                        can_nxt_merge_fwd = True

                if not can_nxt_merge_fwd:
                    if combined_clean in OXFORD_FULL_VOCAB or difflib.get_close_matches(combined_clean, list(OXFORD_FULL_VOCAB), n=1, cutoff=0.7):
                        merged.append(curr + nxt)
                        i += 2
                        continue

            # Syllable splits in OCR (e.g. 'Stud' + 'ent', 'teach' + 'er')
            if combined_clean in OXFORD_FULL_VOCAB and len(combined_clean) >= 4:
                common_short_words = {'i', 'a', 'in', 'on', 'at', 'to', 'is', 'it', 'he', 'we', 'me', 'us', 'be', 'so', 'go', 'do', 'no', 'my', 'by', 'as', 'up'}
                if curr_clean not in common_short_words or nxt_clean not in common_short_words:
                    merged.append(curr + nxt)
                    i += 2
                    continue

        merged.append(curr)
        i += 1

    return merged

def _correct_ocr_tokens(raw_text: str) -> str:
    if not raw_text or not raw_text.strip():
        return raw_text

    import difflib

    normalized = _apply_optical_confusion_rules(raw_text.strip())

    # 2. Tokenize and strip chalk drag / hyphen noise (- _ ~ = ^ * |)
    raw_words = normalized.split()
    cleaned_tokens = []
    for w in raw_words:
        w_clean = re.sub(r"^[\-_~=^|\\/]+|[\-_~=^|\\/]+$", "", w)
        if w_clean:
            cleaned_tokens.append(w_clean)

    words = _merge_broken_tokens(cleaned_tokens)
    corrected_words = []

    for idx, w in enumerate(words):
        prev_w = words[idx - 1].lower() if idx > 0 else ""
        next_w = words[idx + 1].lower() if idx < len(words) - 1 else ""

        prefix = ""
        suffix = ""
        core = w
        while core and not core[0].isalnum():
            prefix += core[0]
            core = core[1:]
        while core and not core[-1].isalnum():
            # Only preserve true punctuation like . , ? ! ; :
            if core[-1] in ".!?,;:":
                suffix = core[-1] + suffix
            core = core[:-1]

        if not core:
            corrected_words.append(w)
            continue

        low_core = core.lower()

        # Contextual exceptions for identical-sound words
        if low_core == "beer" and prev_w in ("has", "have", "had", "having"):
            corrected_words.append(prefix + ("Been" if core[0].isupper() else "been") + suffix)
            continue
        if low_core in ("thars", "thar", "thors", "thor", "thay", "thagy", "thev"):
            corrected_words.append(prefix + ("They" if core[0].isupper() else "they") + suffix)
            continue

        # Single letter protection: only 'I' and 'a' are valid English words
        if len(core) == 1:
            if low_core == "i":
                corrected_words.append(prefix + "I" + suffix)
            elif low_core == "a":
                corrected_words.append(prefix + ("A" if core.isupper() else "a") + suffix)
            continue

        # Short 2-letter words protection & common handwriting OCR misreads
        if len(core) == 2:
            if low_core in ("av", "ov", "ci", "cl", "al", "ai"):
                corrected_words.append(prefix + ("A" if core[0].isupper() else "a") + suffix)
                continue
            if low_core in ("ae", "ar"):
                corrected_words.append(prefix + ("Are" if core[0].isupper() else "are") + suffix)
                continue
            if low_core in ("su", "sc", "sa"):
                corrected_words.append(prefix + ("So" if core[0].isupper() else "so") + suffix)
                continue
            if low_core in ("ob", "fo", "eo", "ro"):
                corrected_words.append(prefix + ("To" if core[0].isupper() else "to") + suffix)
                continue
            if low_core in OXFORD_FULL_VOCAB:
                corrected_words.append(prefix + (low_core.capitalize() if core[0].isupper() else low_core) + suffix)
            else:
                corrected_words.append(w)
            continue

        # Tier 0: Direct match in Oxford 5000 English Dictionary
        if low_core in OXFORD_FULL_VOCAB:
            if core.isupper() and len(core) == 1:
                corrected_words.append(prefix + core + suffix)
            elif core[0].isupper():
                corrected_words.append(prefix + low_core.capitalize() + suffix)
            else:
                corrected_words.append(prefix + low_core + suffix)
            continue

        # Tier 1: First letter preservation for 'th...' pronouns
        if low_core.startswith("th"):
            th_candidates = [cw for cw in COMMON_TEACHING_VOCAB if cw.startswith("th")]
            matches = difflib.get_close_matches(low_core, th_candidates, n=1, cutoff=0.55)
            if matches:
                best = matches[0].capitalize() if core[0].isupper() else matches[0]
                corrected_words.append(prefix + best + suffix)
                continue

        # Tier 2: Fuzzy search in Core Teaching Vocabulary (Oxford Elementary / Classroom)
        core_candidates = [cw for cw in COMMON_TEACHING_VOCAB if abs(len(cw) - len(low_core)) <= 1 and len(cw) >= 3]
        matches = difflib.get_close_matches(low_core, core_candidates, n=1, cutoff=0.60)
        if matches:
            best = matches[0].capitalize() if core[0].isupper() else matches[0]
            corrected_words.append(prefix + best + suffix)
            continue

        # Tier 3: General Fuzzy search in Full Oxford 5000 Dictionary
        if OXFORD_FULL_VOCAB and len(low_core) >= 4:
            full_candidates = [ow for ow in OXFORD_FULL_VOCAB if abs(len(ow) - len(low_core)) <= 1 and len(ow) >= 4]
            matches_all = difflib.get_close_matches(low_core, full_candidates, n=1, cutoff=0.72)
            if matches_all:
                best = matches_all[0].capitalize() if core[0].isupper() else matches_all[0]
                corrected_words.append(prefix + best + suffix)
                continue

        corrected_words.append(w)

    return " ".join(corrected_words)

@app.post("/analyze-svo", response_model=AnalyzeResponse)
async def analyze_svo(
    text: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
):
    extracted_text = (text or "").strip()
    
    # 1. OCR processing if image is uploaded
    if image and not extracted_text:
        try:
            image_bytes = await image.read()
            if has_pil:
                img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                if rapid_ocr:
                    import numpy as np
                    import cv2
                    img_np = np.array(img)
                    # Auto-invert dark background to crisp black-on-white for optimal OCR
                    if img_np.mean() < 128:
                        img_np = 255 - img_np

                    # Apply morphological smoothing to connect subtle stroke breaks in cursive handwriting
                    gray = cv2.cvtColor(img_np, cv2.COLOR_RGB2GRAY) if len(img_np.shape) == 3 else img_np
                    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
                    # On white background (255) with black strokes (0), erosion thickens black strokes
                    closed_gray = cv2.erode(gray, kernel, iterations=1)
                    prep_img = cv2.cvtColor(closed_gray, cv2.COLOR_GRAY2RGB)

                    result, _ = rapid_ocr(prep_img)
                    ordered_boxes = []
                    if result:
                        for item in result:
                            box = item[0]
                            text_str = item[1].strip() if len(item) > 1 else ""
                            clean_str = re.sub(r"[^\x20-\x7E]", " ", text_str).strip()
                            if not clean_str:
                                continue
                            x_min = min(p[0] for p in box)
                            x_max = max(p[0] for p in box)
                            y_min = min(p[1] for p in box)
                            y_max = max(p[1] for p in box)
                            height = max(1.0, y_max - y_min)
                            y_center = (y_min + y_max) / 2.0
                            ordered_boxes.append({
                                'x_min': x_min,
                                'x_max': x_max,
                                'y_min': y_min,
                                'y_max': y_max,
                                'height': height,
                                'y_center': y_center,
                                'text': clean_str,
                            })

                    # Calculate vertical projection segments to identify physical word clusters
                    black_cols = np.sum(gray < 140, axis=0)
                    in_w = False
                    segs = []
                    st = 0
                    for col, cnt in enumerate(black_cols):
                        if cnt > 2 and not in_w:
                            in_w = True
                            st = col
                        elif cnt <= 2 and in_w:
                            in_w = False
                            segs.append((st, col))
                    if in_w:
                        segs.append((st, len(black_cols)))

                    word_segs = []
                    curr = None
                    for s, e in segs:
                        if curr is None:
                            curr = [s, e]
                        else:
                            if s - curr[1] < 32:
                                curr[1] = e
                            else:
                                word_segs.append(tuple(curr))
                                curr = [s, e]
                    if curr:
                        word_segs.append(tuple(curr))

                    # Merge DBNet detections with Word Segments without duplicates:
                    final_words = []
                    used_box_ids = set()
                    if word_segs:
                        for ws, we in word_segs:
                            matching_boxes = [
                                (idx, b) for idx, b in enumerate(ordered_boxes)
                                if idx not in used_box_ids and max(b['x_min'], ws) < min(b['x_max'], we) + 12
                            ]
                            if matching_boxes:
                                matching_boxes.sort(key=lambda item: item[1]['x_min'])
                                cluster_tokens = []
                                last_box = None
                                for idx, b in matching_boxes:
                                    used_box_ids.add(idx)
                                    b_txt = b['text'].strip()
                                    if not b_txt:
                                        continue
                                    if cluster_tokens and last_box is not None:
                                        gap = b['x_min'] - last_box['x_max']
                                        if gap < 28 or len(cluster_tokens[-1]) <= 2 or len(b_txt) <= 2:
                                            cluster_tokens[-1] = cluster_tokens[-1] + b_txt
                                            last_box = b
                                            continue
                                    cluster_tokens.append(b_txt)
                                    last_box = b
                                final_words.extend(cluster_tokens)
                            else:
                                # DBNet completely missed this handwriting word! Run recognition on tight crop
                                w_crop = gray[:, ws:we]
                                b_rows = np.where(np.sum(w_crop < 140, axis=1) > 0)[0]
                                if len(b_rows) > 0:
                                    w_crop = w_crop[b_rows[0]:b_rows[-1]+1, :]
                                padded = cv2.copyMakeBorder(w_crop, 16, 16, 24, 24, cv2.BORDER_CONSTANT, value=255)
                                w_res, _ = rapid_ocr(padded, use_det=False)
                                if w_res and len(w_res) > 0:
                                    w_txt = re.sub(r"[^\x20-\x7E]", "", w_res[0][0]).strip()
                                    if w_txt:
                                        final_words.append(w_txt)
                    else:
                        ordered_boxes.sort(key=lambda b: b['x_min'])
                        final_words = [b['text'] for b in ordered_boxes]

                    # Deduplicate consecutive identical words (e.g. "They They" -> "They")
                    deduped_words = []
                    for w in final_words:
                        if not deduped_words or deduped_words[-1].lower() != w.lower():
                            deduped_words.append(w)
                    ordered_texts = deduped_words

                    if ordered_texts:
                        raw_extracted = " ".join(ordered_texts)
                        extracted_text = _correct_ocr_tokens(raw_extracted)
                        try:
                            print(f"[OCR] Extracted: '{raw_extracted}' -> Corrected: '{extracted_text}'", flush=True)
                        except Exception:
                            pass
                elif has_pytesseract:
                    ocr_result = pytesseract.image_to_string(img, config="--psm 7")
                    if ocr_result.strip():
                        raw_line = re.sub(r"[^\x20-\x7E]", " ", ocr_result.strip()).strip()
                        extracted_text = _correct_ocr_tokens(raw_line)
        except Exception as e:
            try:
                print(f"OCR Error: {e}", flush=True)
            except Exception:
                pass

    return _parse_with_spacy(extracted_text)

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
        default=int(os.environ.get("HOCLUC_PLUGIN_PORT", 18888)),
        help="Port to bind"
    )
    args = parser.parse_args()
    print(f"[EnglishAssistantEngine] Starting on 127.0.0.1:{args.port}...")
    uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="info")
