"""
Builder script to generate `cefr_lexicon.json` and `academic_collocations.json`.
"""

import json
import os

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(DATA_DIR, exist_ok=True)

# 1. ACADEMIC COLLOCATIONS LIST (ACL)
COLLOCATIONS = [
    {
        "phrase": "take into account",
        "category": "verb_prep_noun",
        "target_word": "account",
        "mask_type": "preposition_noun",
        "distractors": ["mind", "consideration", "view"],
        "explanation": "Cụm cố định: 'take sth into account' = cân nhắc, tính đến điều gì."
    },
    {
        "phrase": "make a decision",
        "category": "verb_noun",
        "target_word": "make",
        "mask_type": "verb",
        "distractors": ["do", "give", "bring"],
        "explanation": "Collocation: 'make a decision' (không dùng 'do a decision')."
    },
    {
        "phrase": "shed light on",
        "category": "verb_noun_prep",
        "target_word": "shed",
        "mask_type": "verb",
        "distractors": ["cast", "drop", "pour"],
        "explanation": "Collocation: 'shed light on' = làm sáng tỏ vấn đề gì."
    },
    {
        "phrase": "play a vital role",
        "category": "verb_adj_noun",
        "target_word": "vital",
        "mask_type": "adjective",
        "distractors": ["heavy", "deep", "sharp"],
        "explanation": "Collocation: 'play a vital/pivotal role in sth' = đóng vai trò sống còn."
    },
    {
        "phrase": "in terms of",
        "category": "preposition_phrase",
        "target_word": "terms",
        "mask_type": "noun",
        "distractors": ["means", "ways", "cases"],
        "explanation": "Cụm cố định: 'in terms of' = xét về khía cạnh, phương diện."
    },
    {
        "phrase": "reach a consensus",
        "category": "verb_noun",
        "target_word": "reach",
        "mask_type": "verb",
        "distractors": ["get", "gain", "arrive"],
        "explanation": "Collocation: 'reach a consensus' = đạt được sự đồng thuận chung."
    },
    {
        "phrase": "draw a conclusion",
        "category": "verb_noun",
        "target_word": "draw",
        "mask_type": "verb",
        "distractors": ["paint", "lead", "write"],
        "explanation": "Collocation: 'draw a conclusion' = rút ra kết luận."
    },
    {
        "phrase": "bear in mind",
        "category": "verb_prep_noun",
        "target_word": "bear",
        "mask_type": "verb",
        "distractors": ["keep", "hold", "carry"],
        "explanation": "Cụm cố định: 'bear in mind' = ghi nhớ trong lòng/tâm trí."
    },
    {
        "phrase": "pave the way for",
        "category": "verb_noun_prep",
        "target_word": "pave",
        "mask_type": "verb",
        "distractors": ["build", "make", "lead"],
        "explanation": "Collocation: 'pave the way for' = mở đường cho điều gì."
    },
    {
        "phrase": "pose a threat to",
        "category": "verb_noun_prep",
        "target_word": "pose",
        "mask_type": "verb",
        "distractors": ["make", "give", "set"],
        "explanation": "Collocation: 'pose a threat to' = đặt ra mối đe dọa đối với."
    },
    {
        "phrase": "pay attention to",
        "category": "verb_noun_prep",
        "target_word": "attention",
        "mask_type": "noun",
        "distractors": ["notice", "focus", "regard"],
        "explanation": "Collocation: 'pay attention to' = chú ý, để tâm đến."
    },
    {
        "phrase": "gain an insight into",
        "category": "verb_noun_prep",
        "target_word": "insight",
        "mask_type": "noun",
        "distractors": ["vision", "view", "thought"],
        "explanation": "Collocation: 'gain an insight into' = có được cái nhìn sâu sắc về."
    },
    {
        "phrase": "conduct an experiment",
        "category": "verb_noun",
        "target_word": "conduct",
        "mask_type": "verb",
        "distractors": ["operate", "handle", "control"],
        "explanation": "Collocation: 'conduct an experiment' = tiến hành thí nghiệm."
    },
    {
        "phrase": "fulfill a requirement",
        "category": "verb_noun",
        "target_word": "fulfill",
        "mask_type": "verb",
        "distractors": ["finish", "execute", "obtain"],
        "explanation": "Collocation: 'fulfill a requirement' = đáp ứng một yêu cầu."
    },
    {
        "phrase": "exert an influence on",
        "category": "verb_noun_prep",
        "target_word": "exert",
        "mask_type": "verb",
        "distractors": ["apply", "exercise", "push"],
        "explanation": "Collocation: 'exert an influence on' = tạo ảnh hưởng lên ai/cái gì."
    },
    {
        "phrase": "raise awareness of",
        "category": "verb_noun_prep",
        "target_word": "raise",
        "mask_type": "verb",
        "distractors": ["rise", "grow", "lift"],
        "explanation": "Collocation: 'raise awareness of' = nâng cao nhận thức về."
    },
    {
        "phrase": "take advantage of",
        "category": "verb_noun_prep",
        "target_word": "advantage",
        "mask_type": "noun",
        "distractors": ["profit", "benefit", "use"],
        "explanation": "Cụm cố định: 'take advantage of' = tận dụng cơ hội, lợi thế."
    },
    {
        "phrase": "keep track of",
        "category": "verb_noun_prep",
        "target_word": "track",
        "mask_type": "noun",
        "distractors": ["trace", "trail", "path"],
        "explanation": "Cụm cố định: 'keep track of' = theo dõi, nắm bắt diễn biến."
    },
    {
        "phrase": "at the expense of",
        "category": "preposition_phrase",
        "target_word": "expense",
        "mask_type": "noun",
        "distractors": ["cost", "charge", "price"],
        "explanation": "Cụm cố định: 'at the expense of' = gây phương hại tới, phải trả giá bằng."
    },
    {
        "phrase": "with respect to",
        "category": "preposition_phrase",
        "target_word": "respect",
        "mask_type": "noun",
        "distractors": ["regard", "reference", "relation"],
        "explanation": "Cụm cố định: 'with respect to' = liên quan tới, đối với."
    },
    {
        "phrase": "take precedence over",
        "category": "verb_noun_prep",
        "target_word": "precedence",
        "mask_type": "noun",
        "distractors": ["priority", "preference", "importance"],
        "explanation": "Collocation: 'take precedence over' = được ưu tiên trước cái gì."
    },
    {
        "phrase": "have a profound impact on",
        "category": "verb_adj_noun",
        "target_word": "profound",
        "mask_type": "adjective",
        "distractors": ["deep", "steep", "heavy"],
        "explanation": "Collocation: 'have a profound impact on' = có tác động sâu sắc lên."
    },
    {
        "phrase": "come to a halt",
        "category": "verb_prep_noun",
        "target_word": "halt",
        "mask_type": "noun",
        "distractors": ["stop", "pause", "break"],
        "explanation": "Cụm cố định: 'come to a halt' = dừng lại hoàn toàn."
    },
    {
        "phrase": "run the risk of",
        "category": "verb_noun_prep",
        "target_word": "risk",
        "mask_type": "noun",
        "distractors": ["danger", "threat", "hazard"],
        "explanation": "Collocation: 'run the risk of' = chịu rủi ro về việc gì."
    },
    {
        "phrase": "fall short of",
        "category": "verb_adj_prep",
        "target_word": "short",
        "mask_type": "adjective",
        "distractors": ["low", "brief", "little"],
        "explanation": "Cụm cố định: 'fall short of' = không đạt tới tiêu chuẩn/kỳ vọng."
    },
    {
        "phrase": "put an end to",
        "category": "verb_noun_prep",
        "target_word": "end",
        "mask_type": "noun",
        "distractors": ["stop", "finish", "conclusion"],
        "explanation": "Cụm cố định: 'put an end to' = chấm dứt hoàn toàn điều gì."
    },
    {
        "phrase": "bridge the gap",
        "category": "verb_noun",
        "target_word": "bridge",
        "mask_type": "verb",
        "distractors": ["cross", "connect", "link"],
        "explanation": "Collocation: 'bridge the gap' = thu hẹp khoảng cách."
    },
    {
        "phrase": "lay the foundation for",
        "category": "verb_noun_prep",
        "target_word": "foundation",
        "mask_type": "noun",
        "distractors": ["base", "ground", "basis"],
        "explanation": "Collocation: 'lay the foundation for' = đặt nền móng cho."
    },
    {
        "phrase": "take steps to",
        "category": "verb_noun_prep",
        "target_word": "steps",
        "mask_type": "noun",
        "distractors": ["moves", "actions", "measures"],
        "explanation": "Collocation: 'take steps to' = tiến hành các biện pháp để."
    },
    {
        "phrase": "play a key role in",
        "category": "verb_adj_noun",
        "target_word": "key",
        "mask_type": "adjective",
        "distractors": ["main", "major", "chief"],
        "explanation": "Collocation: 'play a key role in' = đóng vai trò then chốt trong."
    },
    {
        "phrase": "draw attention to",
        "category": "verb_noun_prep",
        "target_word": "draw",
        "mask_type": "verb",
        "distractors": ["pull", "bring", "lead"],
        "explanation": "Collocation: 'draw attention to' = thu hút sự chú ý vào."
    },
    {
        "phrase": "make progress in",
        "category": "verb_noun_prep",
        "target_word": "make",
        "mask_type": "verb",
        "distractors": ["do", "have", "create"],
        "explanation": "Collocation: 'make progress in' = đạt được tiến bộ trong."
    },
    {
        "phrase": "give rise to",
        "category": "verb_noun_prep",
        "target_word": "rise",
        "mask_type": "noun",
        "distractors": ["birth", "start", "growth"],
        "explanation": "Cụm cố định: 'give rise to' = gây ra, làm nảy sinh."
    },
    {
        "phrase": "bring about",
        "category": "phrasal_verb",
        "target_word": "about",
        "mask_type": "preposition",
        "distractors": ["around", "along", "over"],
        "explanation": "Phrasal verb: 'bring about' = đem lại, dẫn tới (kết quả/thay đổi)."
    },
    {
        "phrase": "make sense of",
        "category": "verb_noun_prep",
        "target_word": "sense",
        "mask_type": "noun",
        "distractors": ["meaning", "logic", "point"],
        "explanation": "Cụm cố định: 'make sense of' = hiểu được ý nghĩa của cái gì."
    },
    {
        "phrase": "a wide range of",
        "category": "quantifier_phrase",
        "target_word": "range",
        "mask_type": "noun",
        "distractors": ["scope", "scale", "span"],
        "explanation": "Cụm cố định: 'a wide range of' = đa dạng các loại."
    }
]

# 2. CEFR LEXICON MAPPINGS (with POS-awareness)
# Priority dual POS words where noun vs verb levels differ significantly:
DUAL_POS_WORDS = {
    "address|NOUN": "A1",
    "address|VERB": "B2",
    "record|NOUN": "A2",
    "record|VERB": "B2",
    "present|ADJ": "A2",
    "present|NOUN": "A2",
    "present|VERB": "B2",
    "object|NOUN": "A1",
    "object|VERB": "B2",
    "produce|VERB": "A2",
    "produce|NOUN": "B2",
    "project|NOUN": "A2",
    "project|VERB": "B2",
    "contract|NOUN": "B1",
    "contract|VERB": "B2",
    "conduct|NOUN": "B2",
    "conduct|VERB": "B2",
    "conflict|NOUN": "B2",
    "conflict|VERB": "C1",
    "attribute|NOUN": "B2",
    "attribute|VERB": "C1",
    "content|NOUN": "A2",
    "content|ADJ": "B2",
    "minute|NOUN": "A1",
    "minute|ADJ": "C1",
    "fine|ADJ": "A1",
    "fine|NOUN": "B1",
    "fine|VERB": "B2",
    "wound|NOUN": "B1",
    "wound|VERB": "B2",
    "desert|NOUN": "A2",
    "desert|VERB": "B2",
}

# Core Academic / DGNL High Frequency Words (B2, C1, C2)
LEVEL_MAP = {
    # B2 Vocabulary
    "deteriorate": "B2", "comprehend": "B2", "feasible": "B2", "substantially": "B2",
    "inevitable": "B2", "resilient": "B2", "consensus": "B2", "hypothesis": "B2",
    "correlate": "B2", "facilitate": "B2", "advocate": "B2", "vulnerable": "B2",
    "preliminary": "B2", "rigorous": "B2", "accommodate": "B2", "accumulate": "B2",
    "adequate": "B2", "adjacent": "B2", "advocate": "B2", "allocate": "B2",
    "ambiguous": "B2", "anticipate": "B2", "apparent": "B2", "arbitrary": "B2",
    "coherent": "B2", "coincide": "B2", "collaborate": "B2", "commence": "B2",
    "compatible": "B2", "compensate": "B2", "compile": "B2", "complement": "B2",
    "comprehensive": "B2", "comprise": "B2", "conceive": "B2", "confer": "B2",
    "confine": "B2", "conform": "B2", "consequent": "B2", "considerable": "B2",
    "consistent": "B2", "constitute": "B2", "constrain": "B2", "constructive": "B2",
    "contemporary": "B2", "contradict": "B2", "controversial": "B2", "convene": "B2",
    "crucial": "B2", "cumulative": "B2", "deficiency": "B2", "demonstrate": "B2",
    "denote": "B2", "depict": "B2", "derive": "B2", "differentiate": "B2",
    "dimension": "B2", "diminish": "B2", "discrete": "B2", "displace": "B2",
    "dispose": "B2", "distinct": "B2", "distort": "B2", "diverse": "B2",
    "eliminate": "B2", "empirical": "B2", "encounter": "B2", "enhance": "B2",
    "envisage": "B2", "equate": "B2", "equivalent": "B2", "erode": "B2",
    "escalate": "B2", "evaluate": "B2", "evolve": "B2", "exceed": "B2",
    "exclude": "B2", "exhibit": "B2", "explicit": "B2", "exploit": "B2",
    "fluctuate": "B2", "formulate": "B2", "generate": "B2", "hierarchy": "B2",
    "highlight": "B2", "hinder": "B2", "illuminate": "B2", "illustrate": "B2",
    "implement": "B2", "implicate": "B2", "implicit": "B2", "incorporate": "B2",
    "induce": "B2", "inevitable": "B2", "infer": "B2", "infrastructure": "B2",
    "inherent": "B2", "inhibit": "B2", "initial": "B2", "initiate": "B2",
    "innovate": "B2", "insight": "B2", "integrate": "B2", "integrity": "B2",
    "intense": "B2", "interact": "B2", "interfere": "B2", "intermediate": "B2",
    "intervene": "B2", "intrinsic": "B2", "invariable": "B2", "isolate": "B2",
    "justify": "B2", "legislation": "B2", "liberal": "B2", "likewise": "B2",
    "manifest": "B2", "manipulate": "B2", "marginal": "B2", "maximize": "B2",
    "mediate": "B2", "minimize": "B2", "modify": "B2", "monitor": "B2",
    "mutual": "B2", "neutral": "B2", "nevertheless": "B2", "notion": "B2",
    "notwithstanding": "B2", "nuclear": "B2", "objective": "B2", "obtain": "B2",
    "obvious": "B2", "occupy": "B2", "occur": "B2", "offset": "B2",
    "ongoing": "B2", "orient": "B2", "outcome": "B2", "output": "B2",
    "overlap": "B2", "overseas": "B2", "paradigm": "B2", "parallel": "B2",
    "parameter": "B2", "participate": "B2", "perceive": "B2", "period": "B2",
    "persist": "B2", "perspective": "B2", "phase": "B2", "phenomenon": "B2",
    "philosophy": "B2", "portion": "B2", "potential": "B2", "practitioner": "B2",
    "precede": "B2", "precise": "B2", "predict": "B2", "predominant": "B2",
    "preliminary": "B2", "presume": "B2", "previous": "B2", "primary": "B2",
    "prime": "B2", "principal": "B2", "principle": "B2", "prior": "B2",
    "priority": "B2", "proceed": "B2", "process": "B2", "prohibit": "B2",
    "proportion": "B2", "prospect": "B2", "protocol": "B2", "psychology": "B2",
    "publish": "B2", "pursue": "B2", "qualitative": "B2", "quote": "B2",
    "radical": "B2", "random": "B2", "range": "B2", "ratio": "B2",
    "rational": "B2", "react": "B2", "recover": "B2", "refine": "B2",
    "regime": "B2", "region": "B2", "register": "B2", "regulate": "B2",
    "reinforce": "B2", "reject": "B2", "relax": "B2", "release": "B2",
    "relevant": "B2", "reluctance": "B2", "rely": "B2", "require": "B2",
    "research": "B2", "reside": "B2", "resolve": "B2", "resource": "B2",
    "respond": "B2", "restore": "B2", "restrain": "B2", "restrict": "B2",
    "retain": "B2", "reveal": "B2", "revenue": "B2", "reverse": "B2",
    "revise": "B2", "revolution": "B2", "rigid": "B2", "role": "B2",
    "route": "B2", "scenario": "B2", "schedule": "B2", "scheme": "B2",
    "scope": "B2", "section": "B2", "sector": "B2", "secure": "B2",
    "seek": "B2", "select": "B2", "sequence": "B2", "series": "B2",
    "shift": "B2", "significant": "B2", "similar": "B2", "simulate": "B2",
    "site": "B2", "so-called": "B2", "sole": "B2", "somewhat": "B2",
    "source": "B2", "specific": "B2", "specify": "B2", "sphere": "B2",
    "stable": "B2", "statistic": "B2", "status": "B2", "straightforward": "B2",
    "strategy": "B2", "stress": "B2", "structure": "B2", "style": "B2",
    "submit": "B2", "subordinate": "B2", "subsequent": "B2", "subsidy": "B2",
    "substitute": "B2", "successor": "B2", "sufficient": "B2", "sum": "B2",
    "summary": "B2", "supplement": "B2", "survey": "B2", "survive": "B2",
    "suspend": "B2", "sustain": "B2", "symbol": "B2", "tape": "B2",
    "target": "B2", "task": "B2", "team": "B2", "technical": "B2",
    "technique": "B2", "technology": "B2", "temporary": "B2", "tense": "B2",
    "terminate": "B2", "text": "B2", "theme": "B2", "theory": "B2",
    "thereby": "B2", "thesis": "B2", "topic": "B2", "trace": "B2",
    "tradition": "B2", "transfer": "B2", "transform": "B2", "transit": "B2",
    "transmit": "B2", "transport": "B2", "trend": "B2", "trigger": "B2",
    "ultimate": "B2", "undergo": "B2", "underlie": "B2", "undertake": "B2",
    "uniform": "B2", "unify": "B2", "unique": "B2", "utilize": "B2",
    "valid": "B2", "vary": "B2", "vehicle": "B2", "version": "B2",
    "via": "B2", "violate": "B2", "virtual": "B2", "visible": "B2",
    "vision": "B2", "visual": "B2", "volume": "B2", "voluntary": "B2",
    "welfare": "B2", "whereas": "B2", "whereby": "B2", "widespread": "B2",

    # C1 Vocabulary (High-discriminator for DGNL / HSA / V-SAT)
    "ubiquitous": "C1", "unprecedented": "C1", "scrutinize": "C1", "ambiguity": "C1",
    "pervasive": "C1", "meticulous": "C1", "arbitrary": "C1", "disproportionate": "C1",
    "imperative": "C1", "prevalent": "C1", "indispensable": "C1", "lucrative": "C1",
    "detrimental": "C1", "exponential": "C1", "conducive": "C1", "inadvertently": "C1",
    "paramount": "C1", "pragmatic": "C1", "succinct": "C1", "tentative": "C1",
    "viable": "C1", "ubiquity": "C1", "unravel": "C1", "vindicate": "C1",
    "warrant": "C1", "aberration": "C1", "abstain": "C1", "acclaim": "C1",
    "adversary": "C1", "aesthetic": "C1", "alleviate": "C1", "altruistic": "C1",
    "anomaly": "C1", "antipathy": "C1", "apathy": "C1", "appease": "C1",
    "apprehensive": "C1", "arduous": "C1", "articulate": "C1", "ascendancy": "C1",
    "assiduous": "C1", "astute": "C1", "audacious": "C1", "augment": "C1",
    "austere": "C1", "autonomous": "C1", "aversion": "C1", "baffle": "C1",
    "belligerent": "C1", "benevolent": "C1", "bolster": "C1", "brevity": "C1",
    "candor": "C1", "capricious": "C1", "catalyst": "C1", "censure": "C1",
    "circumvent": "C1", "clandestine": "C1", "coalesce": "C1", "coercion": "C1",
    "cognizant": "C1", "collusion": "C1", "complacent": "C1", "conciliatory": "C1",
    "condone": "C1", "conjecture": "C1", "conspicuous": "C1", "consummate": "C1",
    "contentious": "C1", "contingent": "C1", "copious": "C1", "corroborate": "C1",
    "credulous": "C1", "culpable": "C1", "cursory": "C1", "daunting": "C1",
    "dearth": "C1", "debilitate": "C1", "decorum": "C1", "deference": "C1",
    "delineate": "C1", "deliberate": "C1", "demur": "C1", "denounce": "C1",
    "deplete": "C1", "deride": "C1", "despondent": "C1", "destitute": "C1",
    "deterrent": "C1", "devoid": "C1", "diatribe": "C1", "didactic": "C1",
    "diffident": "C1", "diligent": "C1", "discordant": "C1", "disparate": "C1",
    "disseminate": "C1", "dissent": "C1", "dissident": "C1", "divergent": "C1",
    "divisive": "C1", "dogmatic": "C1", "dubious": "C1", "ebullient": "C1",
    "eccentric": "C1", "eclectic": "C1", "efficacy": "C1", "effusive": "C1",
    "egregious": "C1", "elated": "C1", "elusive": "C1", "embellish": "C1",
    "eminent": "C1", "emulate": "C1", "enervate": "C1", "engender": "C1",
    "enigma": "C1", "ephemeral": "C1", "equivocal": "C1", "erratic": "C1",
    "erudite": "C1", "esoteric": "C1", "euphemism": "C1", "exacerbate": "C1",
    "exacting": "C1", "exalt": "C1", "exemplary": "C1", "exhaustive": "C1",
    "exonerate": "C1", "expedient": "C1", "expedite": "C1", "explicit": "C1",
    "extol": "C1", "extraneous": "C1", "extricate": "C1", "facetious": "C1",
    "fallacious": "C1", "fastidious": "C1", "fathom": "C1", "fervent": "C1",
    "flagrant": "C1", "flippant": "C1", "foster": "C1", "fractious": "C1",
    "frugal": "C1", "futile": "C1", "garrulous": "C1", "germane": "C1",
    "gratuitous": "C1", "gregarious": "C1", "hackneyed": "C1", "haphazard": "C1",
    "haughty": "C1", "hegemony": "C1", "heterogeneous": "C1", "homogeneous": "C1",
    "hubris": "C1", "hyperbole": "C1", "hypocritical": "C1", "iconoclast": "C1",
    "idiosyncratic": "C1", "ignominious": "C1", "imminent": "C1", "impartial": "C1",
    "impeccable": "C1", "impede": "C1", "impervious": "C1", "impetuous": "C1",
    "implacable": "C1", "implicit": "C1", "impoverished": "C1", "impudent": "C1",
    "inadvertent": "C1", "inchoate": "C1", "incisive": "C1", "incongruous": "C1",
    "indigenous": "C1", "indolent": "C1", "inept": "C1", "inert": "C1",
    "infamous": "C1", "ingenuous": "C1", "inimical": "C1", "innocuous": "C1",
    "scrutiny": "C1", "crisis": "B2", "committee": "B1"
}

# 3. Build Full Database
db = {}

# Insert dual POS words first
for k, v in DUAL_POS_WORDS.items():
    db[k] = v

# Insert lemma level maps
for word, lvl in LEVEL_MAP.items():
    db[word] = lvl
    # Also index common POS variants
    db[f"{word}|ADJ"] = lvl
    db[f"{word}|VERB"] = lvl
    db[f"{word}|NOUN"] = lvl
    db[f"{word}|ADV"] = lvl

collocations_path = os.path.join(DATA_DIR, "academic_collocations.json")
with open(collocations_path, "w", encoding="utf-8") as f:
    json.dump(COLLOCATIONS, f, ensure_ascii=False, indent=2)

cefr_path = os.path.join(DATA_DIR, "cefr_lexicon.json")
with open(cefr_path, "w", encoding="utf-8") as f:
    json.dump(db, f, ensure_ascii=False, indent=2)

print(f"Generated {len(COLLOCATIONS)} collocations -> {collocations_path}")
print(f"Generated {len(db)} CEFR lookup keys -> {cefr_path}")
