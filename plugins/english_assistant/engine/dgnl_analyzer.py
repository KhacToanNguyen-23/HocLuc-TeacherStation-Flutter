"""
DGNL Analyzer Engine
Integrates spaCy Pipeline, CEFR Lexicon, and Academic Collocation List (ACL).
Provides:
1. Multi-layer span detection with POS-aware disambiguation.
2. Pedagogical metrics (Lexical Density, CEFR Profile, Assessment Gauge).
3. Rule-based Cloze Test & Distractor Generation without LLM hallucinations.
"""

import os
import json
import random
from typing import List, Dict, Any, Optional
import spacy
from spacy.matcher import Matcher, PhraseMatcher

from grammar_rules import setup_grammar_matcher, setup_dependency_grammar_matcher, GRAMMAR_METADATA

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

class DgnlEngine:
    def __init__(self, nlp_instance=None):
        if nlp_instance is not None:
            self.nlp = nlp_instance
        else:
            try:
                # Prefer en_core_web_md for accurate dependency parsing with low footprint
                self.nlp = spacy.load("en_core_web_md", disable=["ner"])
            except Exception:
                try:
                    self.nlp = spacy.load("en_core_web_sm", disable=["ner"])
                except Exception:
                    self.nlp = None

        self.cefr_db = {}
        self.collocations_list = []
        self.collocation_map = {}
        self.grammar_matcher = None
        self.dep_grammar_matcher = None
        self.phrase_matcher = None

        self._load_datasets()
        self._init_matchers()

    def _load_datasets(self):
        cefr_path = os.path.join(DATA_DIR, "cefr_lexicon.json")
        if os.path.exists(cefr_path):
            with open(cefr_path, "r", encoding="utf-8") as f:
                self.cefr_db = json.load(f)

        colloc_path = os.path.join(DATA_DIR, "academic_collocations.json")
        if os.path.exists(colloc_path):
            with open(colloc_path, "r", encoding="utf-8") as f:
                self.collocations_list = json.load(f)
                for item in self.collocations_list:
                    self.collocation_map[item["phrase"].lower()] = item

    def _init_matchers(self):
        if not self.nlp:
            return

        # 1. Grammar matcher (token patterns and dependency trees)
        self.grammar_matcher = setup_grammar_matcher(self.nlp)
        self.dep_grammar_matcher = setup_dependency_grammar_matcher(self.nlp)

        # 2. Phrase matcher for Academic Collocations (using LEMMA for inflections like made -> make)
        self.phrase_matcher = PhraseMatcher(self.nlp.vocab, attr="LEMMA")
        patterns = []
        for item in self.collocations_list:
            patterns.append(self.nlp(item["phrase"]))
        if patterns:
            self.phrase_matcher.add("COLLOCATION", patterns)

        # 3. Flexible Matcher for split collocations (e.g. "take these factors into account")
        self.split_colloc_matcher = Matcher(self.nlp.vocab)
        split_rules = [
            ("take into account", [
                {"LEMMA": "take"},
                {"OP": "*", "DEP": {"IN": ["det", "amod", "dobj", "compound", "poss", "nmod"]}},
                {"LOWER": "into"},
                {"LOWER": "account"}
            ]),
            ("pay attention to", [
                {"LEMMA": "pay"},
                {"OP": "*", "DEP": {"IN": ["det", "amod", "compound", "poss"]}},
                {"LOWER": "attention"},
                {"LOWER": "to"}
            ]),
            ("draw attention to", [
                {"LEMMA": "draw"},
                {"OP": "*", "DEP": {"IN": ["det", "amod", "compound", "poss"]}},
                {"LOWER": "attention"},
                {"LOWER": "to"}
            ]),
            ("keep track of", [
                {"LEMMA": "keep"},
                {"OP": "*", "DEP": {"IN": ["det", "amod", "compound", "poss"]}},
                {"LOWER": "track"},
                {"LOWER": "of"}
            ]),
        ]
        for key, pat in split_rules:
            self.split_colloc_matcher.add(key, [pat])

    def get_cefr_level(self, token) -> Optional[str]:
        """Look up CEFR level with POS-awareness (e.g. address|NOUN vs address|VERB)."""
        lemma = token.lemma_.lower()
        pos = token.pos_
        # 1. Dual POS key
        key = f"{lemma}|{pos}"
        if key in self.cefr_db:
            return self.cefr_db[key]
        # 2. Fallback to lemma
        if lemma in self.cefr_db:
            return self.cefr_db[lemma]
        return None

    def analyze(self, text: str) -> Dict[str, Any]:
        """Performs multi-layer syntactic, collocation, and lexical analysis."""
        if not self.nlp or not text.strip():
            return {
                "text_length": len(text),
                "total_words": 0,
                "metrics": {
                    "total_words": 0,
                    "content_words": 0,
                    "lexical_density": 0.0,
                    "cefr_profile": {"A1_B1": 100.0, "B2": 0.0, "C1_C2": 0.0},
                    "evaluation": "Văn bản rỗng hoặc mô hình spaCy chưa sẵn sàng.",
                    "status": "neutral"
                },
                "highlights": []
            }

        doc = self.nlp(text)
        highlights = []

        # A. Grammar Patterns (Inversion, Participles, Cleft, etc.)
        if self.grammar_matcher:
            grammar_matches = self.grammar_matcher(doc)
            for match_id, start, end in grammar_matches:
                rule_name = self.nlp.vocab.strings[match_id]
                meta = GRAMMAR_METADATA.get(rule_name, {})
                span = doc[start:end]
                highlights.append({
                    "start": span.start_char,
                    "end": span.end_char,
                    "text": span.text,
                    "type": meta.get("name", rule_name),
                    "rule_id": rule_name,
                    "category": "grammar",
                    "color": meta.get("color", "#3B82F6"),
                    "note": meta.get("note", "Cấu trúc ngữ pháp trọng tâm phân loại trong đề ĐGNL."),
                    "description": meta.get("description", "")
                })

        # A2. Dependency-based Grammar Patterns (Passive Voice, Relative Clause)
        if hasattr(self, "dep_grammar_matcher") and self.dep_grammar_matcher:
            dep_matches = self.dep_grammar_matcher(doc)
            for match_id, token_indices in dep_matches:
                rule_name = self.nlp.vocab.strings[match_id]
                meta = GRAMMAR_METADATA.get(rule_name, {})
                tokens = [doc[i] for i in sorted(token_indices)]
                if not tokens:
                    continue
                start_char = min(t.idx for t in tokens)
                end_char = max(t.idx + len(t.text) for t in tokens)
                span_text = text[start_char:end_char]

                already_exists = any(
                    h.get("category") == "grammar" and
                    (h["start"] <= start_char and h["end"] >= end_char or
                     start_char <= h["start"] and end_char >= h["end"])
                    for h in highlights
                )
                if not already_exists:
                    highlights.append({
                        "start": start_char,
                        "end": end_char,
                        "text": span_text,
                        "type": meta.get("name", rule_name),
                        "rule_id": rule_name,
                        "category": "grammar",
                        "color": meta.get("color", "#89b4fa"),
                        "note": meta.get("note", "Cấu trúc ngữ pháp phân hóa cao trong đề thi ĐGNL."),
                        "description": meta.get("description", "")
                    })

        # B. Academic Collocations
        seen_colloc_spans = set()
        if self.phrase_matcher:
            colloc_matches = self.phrase_matcher(doc)
            for match_id, start, end in colloc_matches:
                span = doc[start:end]
                phrase_key = " ".join([t.lemma_.lower() for t in span])
                meta = self.collocation_map.get(phrase_key) or self.collocation_map.get(span.text.lower(), {})
                raw_cat = meta.get("category", "collocation")
                if "phrasal" in raw_cat:
                    mwu_type = "Phrasal Verb (Cụm động từ)"
                    mwu_cat = "collocation"
                    mwu_color = "#10B981"
                elif "idiom" in raw_cat:
                    mwu_type = "Idiom (Thành ngữ)"
                    mwu_cat = "vocabulary"
                    mwu_color = "#8B5CF6"
                elif "compound" in raw_cat:
                    mwu_type = "Compound Word (Từ ghép)"
                    mwu_cat = "collocation"
                    mwu_color = "#F59E0B"
                elif "grammar" in raw_cat:
                    mwu_type = "Grammar Expression (Cụm ngữ pháp)"
                    mwu_cat = "grammar"
                    mwu_color = "#3B82F6"
                else:
                    mwu_type = "Academic Collocation"
                    mwu_cat = "collocation"
                    mwu_color = "#10B981"

                seen_colloc_spans.add((span.start_char, span.end_char))
                highlights.append({
                    "start": span.start_char,
                    "end": span.end_char,
                    "text": span.text,
                    "type": mwu_type,
                    "category": mwu_cat,
                    "color": mwu_color,
                    "note": meta.get("explanation", f"{mwu_type}: '{span.text}'"),
                    "target_word": meta.get("target_word", ""),
                    "distractors": meta.get("distractors", [])
                })

        if hasattr(self, "split_colloc_matcher") and self.split_colloc_matcher:
            split_matches = self.split_colloc_matcher(doc)
            for match_id, start, end in split_matches:
                span = doc[start:end]
                if (span.start_char, span.end_char) in seen_colloc_spans:
                    continue
                rule_key = self.nlp.vocab.strings[match_id]
                meta = self.collocation_map.get(rule_key, {})
                seen_colloc_spans.add((span.start_char, span.end_char))
                highlights.append({
                    "start": span.start_char,
                    "end": span.end_char,
                    "text": span.text,
                    "type": "Academic Collocation",
                    "category": "collocation",
                    "color": "#10B981",
                    "note": meta.get("explanation", "Cụm từ cố định học thuật - hay gặp trong bài đọc/điền từ."),
                    "target_word": meta.get("target_word", ""),
                    "distractors": meta.get("distractors", [])
                })

        # C. CEFR Vocabulary (B1, B2, C1, C2)
        content_tokens = []
        all_word_tokens = []
        b2_count = 0
        c1_c2_count = 0

        for token in doc:
            if not token.is_alpha or token.is_space:
                continue
            all_word_tokens.append(token)

            level = self.get_cefr_level(token)
            is_content = token.pos_ in ("NOUN", "VERB", "ADJ", "ADV")
            if is_content:
                content_tokens.append(token)
                if level == "B2":
                    b2_count += 1
                elif level in ("C1", "C2"):
                    c1_c2_count += 1

            if level in ("B1", "B2", "C1", "C2"):
                color = "#38BDF8" if level == "B1" else ("#F59E0B" if level == "B2" else "#8B5CF6")
                highlights.append({
                    "start": token.idx,
                    "end": token.idx + len(token.text),
                    "text": token.text,
                    "lemma": token.lemma_.lower(),
                    "pos": token.pos_,
                    "type": f"CEFR {level}",
                    "level": level,
                    "category": "vocabulary",
                    "color": color,
                    "note": f"Từ vựng cấp độ {level} ({token.pos_}) - thích hợp ra đề hỏi từ đồng nghĩa/đục lỗ."
                })

        # Calculate Pedagogical Metrics
        total_words = len(all_word_tokens)
        content_words = len(content_tokens)
        lexical_density = round((content_words / max(1, total_words)) * 100, 1)

        b2_pct = round((b2_count / max(1, content_words)) * 100, 1)
        c1_c2_pct = round((c1_c2_count / max(1, content_words)) * 100, 1)
        a1_b1_pct = round(max(0.0, 100.0 - b2_pct - c1_c2_pct), 1)
        b2_c1_total = round(b2_pct + c1_c2_pct, 1)

        if 15.0 <= b2_c1_total <= 30.0:
            evaluation = f"Đoạn văn đạt chuẩn phân hóa đề thi ĐGNL (B2–C1 chiếm {b2_c1_total}%)."
            status = "optimal"
        elif b2_c1_total < 15.0:
            evaluation = f"Ngữ liệu tương đối dễ (B2–C1 chiếm {b2_c1_total}%). Thích hợp luyện tập nền tảng hoặc đề thi tốt nghiệp THPT."
            status = "easy"
        else:
            evaluation = f"Ngữ liệu có mật độ học thuật cao (B2–C1 chiếm {b2_c1_total}%). Phù hợp cho câu hỏi phân loại điểm 9-10 hoặc đề thi V-SAT/IELTS."
            status = "advanced"

        # Sort highlights by position and priority (Grammar > Collocation > Vocabulary)
        cat_priority = {"grammar": 0, "collocation": 1, "vocabulary": 2}
        highlights.sort(key=lambda x: (x["start"], cat_priority.get(x["category"], 9), -(x["end"] - x["start"])))

        return {
            "text_length": len(text),
            "total_words": total_words,
            "metrics": {
                "total_words": total_words,
                "content_words": content_words,
                "lexical_density": lexical_density,
                "cefr_profile": {
                    "A1_B1": a1_b1_pct,
                    "B2": b2_pct,
                    "C1_C2": c1_c2_pct,
                    "B2_C1_total": b2_c1_total
                },
                "evaluation": evaluation,
                "status": status
            },
            "highlights": highlights,
            "sentences_count": len(list(doc.sents))
        }

    def generate_cloze(self, text: str, selected_types: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Generates high-yield Cloze Test items with curated zero-hallucination distractors."""
        if not self.nlp or not text.strip():
            return []

        doc = self.nlp(text)
        cloze_questions = []
        q_idx = 1

        for sent in doc.sents:
            sent_text = sent.text.strip()
            if len(sent_text) < 15:
                continue

            # 1. Collocation Masking (Priority 1)
            colloc_matches = []
            if self.phrase_matcher:
                for match_id, start, end in self.phrase_matcher(sent):
                    span = sent[start:end]
                    phrase_key = " ".join([t.lemma_.lower() for t in span])
                    meta = self.collocation_map.get(phrase_key) or self.collocation_map.get(span.text.lower())
                    if meta:
                        colloc_matches.append(meta)

            if not colloc_matches and hasattr(self, "split_colloc_matcher") and self.split_colloc_matcher:
                for match_id, start, end in self.split_colloc_matcher(sent):
                    rule_key = self.nlp.vocab.strings[match_id]
                    meta = self.collocation_map.get(rule_key)
                    if meta:
                        colloc_matches.append(meta)

            for meta in colloc_matches:
                if meta and meta.get("target_word"):
                    target = meta["target_word"]
                    pattern = r"\b" + re_escape(target) + r"\b"
                    import re
                    if re.search(pattern, sent_text, re.IGNORECASE):
                        masked = re.sub(pattern, "[ _______ ]", sent_text, count=1, flags=re.IGNORECASE)
                        opts = [target] + meta.get("distractors", ["option1", "option2", "option3"])[:3]
                        rnd = random.Random(len(sent_text) + q_idx)
                        rnd.shuffle(opts)
                        cloze_questions.append({
                            "id": f"cloze_q{q_idx}",
                            "target_type": "collocation",
                            "target_word": target,
                            "original_sentence": sent_text,
                            "masked_sentence": masked,
                            "options": opts,
                            "correct_answer": target,
                            "explanation": meta.get("explanation", f"Cụm từ cố định: '{meta.get('phrase')}'.")
                        })
                        q_idx += 1
                        break # Max 1 question per sentence

            # 2. Grammar Inversion / Participle Masking (Priority 1)
            if self.grammar_matcher:
                grammar_matches = self.grammar_matcher(sent)
                for match_id, start, end in grammar_matches:
                    rule_name = self.nlp.vocab.strings[match_id]
                    meta = GRAMMAR_METADATA.get(rule_name)
                    if meta:
                        span = sent[start:end]
                        # Target word is the opening keyword (Hardly / No sooner / Having / Were / Had / Should)
                        first_token = span[0].text
                        import re
                        pattern = r"\b" + re_escape(first_token) + r"\b"
                        if re.search(pattern, sent_text, re.IGNORECASE):
                            masked = re.sub(pattern, "[ _______ ]", sent_text, count=1, flags=re.IGNORECASE)
                            
                            # Curated distractors per grammar structure
                            if "INVERSION_NEG" in rule_name:
                                distractors = ["Almost", "Nearly", "Usually"]
                                correct = first_token
                                opts = [correct] + distractors
                            elif "INVERSION_NO_SOONER" in rule_name:
                                distractors = ["No later", "Not sooner", "Hardly sooner"]
                                correct = first_token
                                opts = [correct] + distractors
                            elif "PARTICIPLE" in rule_name:
                                distractors = ["Have", "To have", "Had"]
                                correct = first_token
                                opts = [correct] + distractors
                            elif "COND" in rule_name:
                                distractors = ["If", "Unless", "Whether"]
                                correct = first_token
                                opts = [correct] + distractors
                            else:
                                distractors = ["Although", "However", "Because"]
                                correct = first_token
                                opts = [correct] + distractors

                            rnd = random.Random(len(sent_text) + q_idx)
                            rnd.shuffle(opts)
                            cloze_questions.append({
                                "id": f"cloze_q{q_idx}",
                                "target_type": f"grammar_{rule_name.lower()}",
                                "target_word": correct,
                                "original_sentence": sent_text,
                                "masked_sentence": masked,
                                "options": opts,
                                "correct_answer": correct,
                                "explanation": meta.get("description", meta.get("note", "Điểm ngữ pháp đảo ngữ/phân từ."))
                            })
                            q_idx += 1
                            break

            # 3. Vocabulary Masking for B2/C1 (if no grammar/collocation in this sentence)
            if not any(q["original_sentence"] == sent_text for q in cloze_questions):
                for token in sent:
                    lvl = self.get_cefr_level(token)
                    if lvl in ("B2", "C1") and token.is_alpha and len(token.text) > 4:
                        import re
                        target = token.text
                        pattern = r"\b" + re_escape(target) + r"\b"
                        if re.search(pattern, sent_text, re.IGNORECASE):
                            masked = re.sub(pattern, "[ _______ ]", sent_text, count=1, flags=re.IGNORECASE)
                            # Pick alternative B2/C1 distractors
                            sample_candidates = ["feasible", "preliminary", "resilient", "inevitable", "profound", "comprehensive"]
                            distractors = [c for c in sample_candidates if c != target.lower()][:3]
                            opts = [target] + distractors
                            rnd = random.Random(len(sent_text) + q_idx)
                            rnd.shuffle(opts)
                            cloze_questions.append({
                                "id": f"cloze_q{q_idx}",
                                "target_type": f"vocabulary_{lvl.lower()}",
                                "target_word": target,
                                "original_sentence": sent_text,
                                "masked_sentence": masked,
                                "options": opts,
                                "correct_answer": target,
                                "explanation": f"Từ vựng cấp độ {lvl}: '{target}' (nguyên mẫu: {token.lemma_})."
                            })
                            q_idx += 1
                            break

        return cloze_questions


def re_escape(s: str) -> str:
    import re
    return re.escape(s)
