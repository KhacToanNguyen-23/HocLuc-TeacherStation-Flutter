"""
Integration tests for Phase 02: DGNL API Endpoints (/api/dgnl/analyze and /api/dgnl/generate-cloze).
"""

import os
import sys
import time
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from fastapi.testclient import TestClient
from service import app

client = TestClient(app)

SAMPLE_PASSAGE = (
    "Hardly had the committee made a decision when an unprecedented crisis occurred. "
    "The government needs to take these environmental factors into account. "
    "Having completed the preliminary investigation, researchers proposed a feasible alternative."
)

def test_dgnl_analyze_endpoint():
    start_time = time.time()
    response = client.post("/api/dgnl/analyze", json={"text": SAMPLE_PASSAGE})
    duration = time.time() - start_time
    
    assert response.status_code == 200, f"Error: {response.text}"
    data = response.json()
    
    assert "metrics" in data, "Missing metrics key"
    assert "highlights" in data, "Missing highlights key"
    
    metrics = data["metrics"]
    assert metrics["total_words"] > 0
    assert metrics["lexical_density"] > 0
    assert "cefr_profile" in metrics
    assert "B2_C1_total" in metrics["cefr_profile"]
    assert "evaluation" in metrics
    
    highlights = data["highlights"]
    assert len(highlights) > 0, "No highlights detected"
    
    # Check that Grammar, Collocation, and CEFR items are present
    categories = {h["category"] for h in highlights}
    assert "grammar" in categories, "No grammar highlights found"
    assert "collocation" in categories, "No collocation highlights found"
    assert "vocabulary" in categories, "No vocabulary highlights found"
    
    # Check execution latency
    print(f"PASS: /api/dgnl/analyze completed in {duration*1000:.1f}ms (<150ms target)")
    assert duration < 0.5, f"Response too slow: {duration}s"

def test_dgnl_generate_cloze_endpoint():
    response = client.post("/api/dgnl/generate-cloze", json={"text": SAMPLE_PASSAGE})
    assert response.status_code == 200, f"Error: {response.text}"
    data = response.json()
    
    assert "cloze_tests" in data
    tests = data["cloze_tests"]
    assert len(tests) >= 2, f"Expected at least 2 cloze questions, got {len(tests)}"
    
    for q in tests:
        assert "masked_sentence" in q
        assert "[ _______ ]" in q["masked_sentence"]
        assert "options" in q
        assert len(q["options"]) == 4, f"Expected 4 options, got {len(q['options'])}"
        assert "correct_answer" in q
        assert q["correct_answer"] in q["options"]
        assert "explanation" in q
        
    print(f"PASS: /api/dgnl/generate-cloze generated {len(tests)} valid questions with 4 options each.")

if __name__ == "__main__":
    test_dgnl_analyze_endpoint()
    test_dgnl_generate_cloze_endpoint()
