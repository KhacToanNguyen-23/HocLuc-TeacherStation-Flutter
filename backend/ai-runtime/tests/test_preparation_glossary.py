import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preparation_worker import apply_pronunciation_glossary
import pytest


def test_replaces_whole_reviewed_terms_without_matching_other_words():
    assert apply_pronunciation_glossary('Read API and APIs.', [
        {'term': 'API', 'replacement': 'A P I', 'teacherNotes': 'PRIVATE'}
    ]) == 'Read A P I and APIs.'


def test_literal_replacement_does_not_interpret_regex_groups():
    assert apply_pronunciation_glossary('C++ example', [
        {'term': 'C++', 'replacement': r'\1 pronounced'}
    ]) == r'\1 pronounced example'


def test_glossary_bounds_and_empty_terms_are_rejected():
    with pytest.raises(ValueError):
        apply_pronunciation_glossary('x', [{'term': '', 'replacement': 'x'}])
    with pytest.raises(ValueError):
        apply_pronunciation_glossary('x', [{}] * 201)
