"""
Grammar Rules & Matchers for English Assessment Exams (ĐGNL / V-SAT / High School Graduation).
Detects high-yield discriminating grammar structures:
1. Inversion with Negative Adverbs
2. Conditional Inversion (Should / Were / Had)
3. Participle Clauses (Perfect Participle, Present/Past Participle opening clauses)
4. Cleft Sentences (It is/was ... that/who)
5. Special Concession Clauses (Adj/Adv + as/though, No matter how/what)
"""

from typing import List, Dict, Any
from spacy.matcher import Matcher, DependencyMatcher


def setup_dependency_grammar_matcher(nlp) -> DependencyMatcher:
    """Configures and returns a spaCy DependencyMatcher for relational syntactic structures."""
    dep_matcher = DependencyMatcher(nlp.vocab)

    # 1. General Passive Voice: Verb with auxpass dependent
    passive_pattern = [
        {
            "RIGHT_ID": "verb_anchor",
            "RIGHT_ATTRS": {"POS": {"IN": ["VERB", "AUX"]}}
        },
        {
            "LEFT_ID": "verb_anchor",
            "REL_OP": ">",
            "RIGHT_ID": "aux_passive",
            "RIGHT_ATTRS": {"DEP": "auxpass"}
        }
    ]
    dep_matcher.add("PASSIVE_VOICE", [passive_pattern])

    # 2. Relative Clause:
    # A: Relative pronoun as dependent of relcl verb (e.g. "who spend", "which caused")
    relcl_pronoun_pattern = [
        {
            "RIGHT_ID": "rel_verb",
            "RIGHT_ATTRS": {"DEP": "relcl"}
        },
        {
            "LEFT_ID": "rel_verb",
            "REL_OP": ">",
            "RIGHT_ID": "rel_pronoun",
            "RIGHT_ATTRS": {"LOWER": {"IN": ["who", "whom", "which", "that", "whose", "where", "when", "why"]}}
        }
    ]
    # B: Fallback for contact relative clauses (omitted pronoun, e.g. "the book I read")
    relcl_omitted_pattern = [
        {
            "RIGHT_ID": "noun_anchor",
            "RIGHT_ATTRS": {"POS": {"IN": ["NOUN", "PROPN", "PRON"]}}
        },
        {
            "LEFT_ID": "noun_anchor",
            "REL_OP": ">",
            "RIGHT_ID": "rel_verb",
            "RIGHT_ATTRS": {"DEP": "relcl"}
        }
    ]
    dep_matcher.add("RELATIVE_CLAUSE", [relcl_pronoun_pattern, relcl_omitted_pattern])

    # 3. Gerund after Preposition (Prep + V-ing, e.g. "in passing", "of giving")
    gerund_prep_pattern = [
        {
            "RIGHT_ID": "prep_anchor",
            "RIGHT_ATTRS": {"POS": "ADP", "DEP": {"IN": ["prep", "cc"]}}
        },
        {
            "LEFT_ID": "prep_anchor",
            "REL_OP": ">",
            "RIGHT_ID": "gerund_verb",
            "RIGHT_ATTRS": {"DEP": "pcomp", "TAG": "VBG"}
        }
    ]
    dep_matcher.add("GERUND_AFTER_PREP", [gerund_prep_pattern])

    return dep_matcher


def setup_grammar_matcher(nlp) -> Matcher:
    """Configures and returns a spaCy Matcher initialized with DGNL grammar patterns."""
    matcher = Matcher(nlp.vocab)

    # 1. Negative Inversion: [Neg Adverb] + [Aux/Verb] + (det/amod/compound)* + [Subject]
    neg_adverbs = [
        "hardly", "scarcely", "seldom", "rarely", "barely", "never",
        "little", "not only"
    ]
    neg_inversion_pattern = [
        {"LOWER": {"IN": neg_adverbs}},
        {"POS": {"IN": ["AUX", "VERB"]}},
        {"DEP": {"IN": ["det", "poss", "compound", "amod", "advmod"]}, "OP": "*"},
        {"DEP": {"IN": ["nsubj", "nsubjpass"]}}
    ]
    matcher.add("INVERSION_NEG", [neg_inversion_pattern])

    # No sooner inversion: [No] + [sooner] + [Aux/Verb] + (det/amod/compound)* + [Subject]
    no_sooner_pattern = [
        {"LOWER": "no"},
        {"LOWER": "sooner"},
        {"POS": {"IN": ["AUX", "VERB"]}},
        {"DEP": {"IN": ["det", "poss", "compound", "amod", "advmod"]}, "OP": "*"},
        {"DEP": {"IN": ["nsubj", "nsubjpass"]}}
    ]
    matcher.add("INVERSION_NO_SOONER", [no_sooner_pattern])

    # 2. Conditional Inversion (Should / Were / Had)
    # Had + S + (not)? + VBN (Condition Type 3)
    cond_had_pattern = [
        {"LOWER": "had"},
        {"DEP": {"IN": ["det", "poss", "compound", "amod"]}, "OP": "*"},
        {"DEP": {"IN": ["nsubj", "nsubjpass"]}},
        {"LOWER": "not", "OP": "?"},
        {"TAG": {"IN": ["VBN", "VBD"]}}
    ]
    matcher.add("INVERSION_COND_HAD", [cond_had_pattern])

    # Were + S + to + VB (Condition Type 2)
    cond_were_pattern = [
        {"LOWER": "were"},
        {"DEP": {"IN": ["det", "poss", "compound", "amod"]}, "OP": "*"},
        {"DEP": {"IN": ["nsubj", "nsubjpass"]}},
        {"LOWER": "to"},
        {"TAG": "VB"}
    ]
    matcher.add("INVERSION_COND_WERE", [cond_were_pattern])

    # Should + S + VB (Condition Type 1)
    cond_should_pattern = [
        {"LOWER": "should"},
        {"DEP": {"IN": ["det", "poss", "compound", "amod"]}, "OP": "*"},
        {"DEP": {"IN": ["nsubj", "nsubjpass"]}},
        {"TAG": "VB"}
    ]
    matcher.add("INVERSION_COND_SHOULD", [cond_should_pattern])

    # 3. Participle Clauses
    # Perfect Participle: Having + (been)? + VBN/VBD
    having_participle_pattern = [
        {"LOWER": "having"},
        {"LOWER": "been", "OP": "?"},
        {"TAG": {"IN": ["VBN", "VBD"]}}
    ]
    matcher.add("PARTICIPLE_PERFECT", [having_participle_pattern])

    # 4. Cleft Sentences: It + [is/was/has been] + ... + [that/who/whom/which]
    cleft_pattern = [
        {"LOWER": "it"},
        {"LOWER": {"IN": ["is", "was", "will", "has"]}},
        {"OP": "+"},
        {"LOWER": {"IN": ["that", "who", "whom", "which"]}}
    ]
    matcher.add("CLEFT_SENTENCE", [cleft_pattern])

    # 6. Used to + Verb
    used_to_pattern = [
        {"LOWER": "used"},
        {"LOWER": "to"},
        {"TAG": "VB"}
    ]
    matcher.add("USED_TO", [used_to_pattern])

    # 7. Future Passive: be going to be + VBN
    going_to_be_pattern = [
        {"LOWER": {"IN": ["is", "are", "am", "was", "were"]}},
        {"LOWER": "going"},
        {"LOWER": "to"},
        {"LOWER": "be"},
        {"TAG": {"IN": ["VBN", "VBD"]}}
    ]
    matcher.add("PASSIVE_FUTURE", [going_to_be_pattern])

    return matcher


GRAMMAR_METADATA: Dict[str, Dict[str, str]] = {
    "INVERSION_NEG": {
        "name": "Đảo ngữ với Trạng từ Phủ định",
        "description": "Cấu trúc: Trạng từ phủ định (Hardly/Seldom/Never...) + Trợ động từ + Chủ ngữ.",
        "note": "Cấu trúc trọng tâm phân loại trong đề thi ĐGNL.",
        "cloze_target": "adverb",
        "color": "#3B82F6",
    },
    "INVERSION_NO_SOONER": {
        "name": "Đảo ngữ với No sooner ... than",
        "description": "Cấu trúc: No sooner + had + S + V3/ed + than + S + V2/ed.",
        "note": "Rất thường gặp trong phần hoàn thành câu và tìm lỗi sai.",
        "cloze_target": "adverb",
        "color": "#3B82F6",
    },
    "INVERSION_COND_HAD": {
        "name": "Đảo ngữ Câu điều kiện Loại 3",
        "description": "Cấu trúc: Had + S + (not) + V3/ed, S + would have + V3/ed.",
        "note": "Dạng đảo ngữ thay thế cho mệnh đề 'If + had + V3/ed'.",
        "cloze_target": "aux",
        "color": "#3B82F6",
    },
    "INVERSION_COND_WERE": {
        "name": "Đảo ngữ Câu điều kiện Loại 2",
        "description": "Cấu trúc: Were + S + to V / Were + S + Adj/Noun.",
        "note": "Dạng đảo ngữ thay thế cho mệnh đề 'If + S + V2/ed'.",
        "cloze_target": "aux",
        "color": "#3B82F6",
    },
    "INVERSION_COND_SHOULD": {
        "name": "Đảo ngữ Câu điều kiện Loại 1",
        "description": "Cấu trúc: Should + S + V (nguyên thể).",
        "note": "Dạng đảo ngữ trang trọng thay thế cho 'If + S + V(s/es)'.",
        "cloze_target": "aux",
        "color": "#3B82F6",
    },
    "PARTICIPLE_PERFECT": {
        "name": "Mệnh đề Phân từ Hoàn thành (Having + V3)",
        "description": "Cấu trúc: Having + V3/ed rút gọn mệnh đề trạng ngữ chỉ hành động xảy ra trước.",
        "note": "Điểm ngữ pháp phân hóa cao trong câu kết hợp câu hoặc sửa lỗi sai.",
        "cloze_target": "participle",
        "color": "#3B82F6",
    },
    "CLEFT_SENTENCE": {
        "name": "Câu chẻ nhấn mạnh (Cleft Sentence)",
        "description": "Cấu trúc: It is/was + [Thành phần nhấn mạnh] + that/who...",
        "note": "Dùng để nhấn mạnh chủ ngữ, tân ngữ hoặc trạng ngữ.",
        "cloze_target": "relative",
        "color": "#3B82F6",
    },
    "CONCESSION_NO_MATTER": {
        "name": "Mệnh đề Nhượng bộ (No matter...)",
        "description": "Cấu trúc: No matter how/what + S + V = Although / Despite.",
        "note": "Thường xuyên xuất hiện trong phần viết lại câu đồng nghĩa.",
        "cloze_target": "conjunction",
        "color": "#3B82F6",
    },
    "USED_TO": {
        "name": "Cấu trúc Thói quen quá khứ (Used to + V)",
        "description": "Cấu trúc: S + used to + V (nguyên mẫu) diễn tả thói quen trong quá khứ không còn ở hiện tại.",
        "note": "Phân biệt với be used to + V-ing (quen với việc gì).",
        "cloze_target": "verb",
        "color": "#3B82F6",
    },
    "PASSIVE_FUTURE": {
        "name": "Câu bị động tương lai gần (be going to be + V3)",
        "description": "Cấu trúc: S + is/are/am going to be + V3/ed.",
        "note": "Dạng bị động diễn tả kế hoạch hoặc dự đoán có căn cứ.",
        "cloze_target": "passive",
        "color": "#3B82F6",
    },
    "PASSIVE_VOICE": {
        "name": "Câu bị động (Passive Voice)",
        "description": "Cấu trúc: Be + V3/ed diễn tả hành động được thực hiện lên chủ ngữ.",
        "note": "Cấu trúc ngữ pháp nền tảng phân loại cao trong đề thi ĐGNL.",
        "cloze_target": "passive",
        "color": "#89b4fa",
    },
    "RELATIVE_CLAUSE": {
        "name": "Mệnh đề quan hệ (Relative Clause)",
        "description": "Cấu trúc: Mệnh đề phụ bổ nghĩa cho danh từ đứng trước bằng đại từ quan hệ (who, whom, which, that).",
        "note": "Cấu trúc câu phức phân hóa cao trong phần nối câu và tìm lỗi sai.",
        "cloze_target": "relative",
        "color": "#89b4fa",
    },
    "GERUND_AFTER_PREP": {
        "name": "Danh động từ sau giới từ (Prep + V-ing)",
        "description": "Cấu trúc: Giới từ (in/of/at/about/by...) đi kèm động từ dạng V-ing đóng vai trò tân ngữ giới từ.",
        "note": "Kiến thức ngữ pháp phân loại hay gặp trong các câu trắc nghiệm chia dạng thức từ.",
        "cloze_target": "gerund",
        "color": "#89b4fa",
    },
}
