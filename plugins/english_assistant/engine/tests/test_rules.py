"""
Unit tests for Phase 01: Grammar rules and data sets.
"""

import os
import sys
import json

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import spacy
from grammar_rules import setup_grammar_matcher, GRAMMAR_METADATA

def test_datasets_load():
    base_dir = os.path.dirname(os.path.dirname(__file__))
    data_dir = os.path.join(base_dir, "data")
    
    colloc_path = os.path.join(data_dir, "academic_collocations.json")
    cefr_path = os.path.join(data_dir, "cefr_lexicon.json")
    
    assert os.path.exists(colloc_path), "academic_collocations.json missing"
    assert os.path.exists(cefr_path), "cefr_lexicon.json missing"
    
    with open(colloc_path, "r", encoding="utf-8") as f:
        collocations = json.load(f)
        assert len(collocations) > 0, "Collocations list is empty"
        assert "phrase" in collocations[0]
        assert "distractors" in collocations[0]
        
    with open(cefr_path, "r", encoding="utf-8") as f:
        cefr = json.load(f)
        assert "address|NOUN" in cefr and cefr["address|NOUN"] == "A1"
        assert "address|VERB" in cefr and cefr["address|VERB"] == "B2"
        assert "unprecedented" in cefr and cefr["unprecedented"] == "C1"
    print("PASS: Datasets load & POS distinction verified.")

def test_grammar_patterns():
    nlp = spacy.load("en_core_web_sm")
    matcher = setup_grammar_matcher(nlp)

    # 1. Inversion Negative
    doc1 = nlp("Hardly had the committee made a decision when an unprecedented crisis occurred.")
    matches1 = matcher(doc1)
    match_names1 = [nlp.vocab.strings[m[0]] for m in matches1]
    assert "INVERSION_NEG" in match_names1, f"Expected INVERSION_NEG in {match_names1}"

    # 2. Participle Perfect
    doc2 = nlp("Having completed the experiment, the researchers analyzed the data.")
    matches2 = matcher(doc2)
    match_names2 = [nlp.vocab.strings[m[0]] for m in matches2]
    assert "PARTICIPLE_PERFECT" in match_names2, f"Expected PARTICIPLE_PERFECT in {match_names2}"

    # 3. Conditional Inversion (Had)
    doc3 = nlp("Had we known about the environmental impact, we would have acted sooner.")
    matches3 = matcher(doc3)
    match_names3 = [nlp.vocab.strings[m[0]] for m in matches3]
    assert "INVERSION_COND_HAD" in match_names3, f"Expected INVERSION_COND_HAD in {match_names3}"

    print("PASS: Grammar matchers successfully matched all sample structures.")

def test_dependency_grammar_patterns():
    from grammar_rules import setup_dependency_grammar_matcher
    nlp = spacy.load("en_core_web_sm")
    dep_matcher = setup_dependency_grammar_matcher(nlp)

    # 1. Passive Voice: "Smoking is going to be banned in public spaces."
    doc1 = nlp("Smoking is going to be banned in public spaces.")
    matches1 = dep_matcher(doc1)
    rule_names1 = [nlp.vocab.strings[m[0]] for m in matches1]
    assert "PASSIVE_VOICE" in rule_names1, f"Expected PASSIVE_VOICE in {rule_names1}"

    # 2. Relative Clause: "The smokers who spend a long time in smoky environments."
    doc2 = nlp("The smokers who spend a long time in smoky environments have an increased risk.")
    matches2 = dep_matcher(doc2)
    rule_names2 = [nlp.vocab.strings[m[0]] for m in matches2]
    assert "RELATIVE_CLAUSE" in rule_names2, f"Expected RELATIVE_CLAUSE in {rule_names2}"

    print("PASS: Dependency grammar matchers (Passive Voice & Relative Clause) verified.")

if __name__ == "__main__":
    test_datasets_load()
    test_grammar_patterns()
    test_dependency_grammar_patterns()
