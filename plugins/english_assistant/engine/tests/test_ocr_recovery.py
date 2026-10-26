"""TDD coverage for OCR output adaptation and deterministic baseline fixtures."""

import os
import sys
import unittest

ENGINE_DIR = os.path.dirname(os.path.dirname(__file__))
sys.path.insert(0, ENGINE_DIR)

from ocr_recovery import (  # noqa: E402
    OcrCandidate,
    character_error_rate,
    correct_ocr_detections,
    correct_ocr_text,
    reconstruct_reading_order,
    generate_benchmark_samples,
    latency_p95_violations,
    parse_rapidocr_result,
    percentile,
    run_ocr_recovery,
    select_candidate,
    should_retry,
    summarize_rates,
    word_error_rate,
)
from PIL import Image


class OcrRecoveryTests(unittest.TestCase):
    def test_confident_unambiguous_dictionary_match_corrects_and_keeps_punctuation(self):
        self.assertEqual(
            correct_ocr_text("languge,", 0.97, {"language", "landscape"}),
            "language,",
        )

    def test_low_or_missing_confidence_disables_dictionary_correction(self):
        vocabulary = {"language"}
        self.assertEqual(correct_ocr_text("languge", 0.89, vocabulary), "languge")
        self.assertEqual(correct_ocr_text("languge", None, vocabulary), "languge")
        self.assertEqual(correct_ocr_text("languge", 1.2, vocabulary), "languge")

    def test_confidence_is_applied_to_each_detected_region_independently(self):
        detections = (
            self._detection("languge,", 0, 0, confidence=0.98, height=20),
            self._detection("watre", 0, 40, confidence=0.70, height=20),
            self._detection("landscpe", 0, 80, confidence=None, height=20),
        )
        corrected = correct_ocr_detections(detections, {"language", "landscape", "water"})
        self.assertEqual(corrected, "language, watre landscpe")

    def test_valid_rare_and_proper_name_like_words_are_preserved(self):
        vocabulary = {"color", "language"}
        text = "color Languge Quoc"
        self.assertEqual(correct_ocr_text(text, 0.99, vocabulary), text)

    def test_valid_inflected_words_remain_unchanged_when_only_lemma_is_listed(self):
        vocabulary = {"tree", "flower", "leaf", "support"}
        text = "trees flowers leaves supports"
        self.assertEqual(correct_ocr_text(text, 0.99, vocabulary), text)

    def test_ambiguous_lexical_match_is_preserved(self):
        self.assertEqual(
            correct_ocr_text("plaxe", 0.99, {"plane", "place"}, minimum_similarity=0.7, ambiguity_margin=0.0),
            "plaxe",
        )

    @staticmethod
    def _detection(text, x, y, confidence=0.9, width=40, height=16):
        box = ((x, y), (x + width, y), (x + width, y + height), (x, y + height))
        from ocr_recovery import RapidOcrDetection
        return RapidOcrDetection(text, box, confidence)

    def test_geometry_groups_lines_then_orders_tokens_left_to_right(self):
        detections = (
            self._detection("world", 100, 50),
            self._detection("Hello", 10, 48),
            self._detection("second", 10, 90),
            self._detection("line", 80, 90),
        )
        self.assertEqual(reconstruct_reading_order(detections), "Hello world second line")

    def test_retry_trigger_uses_small_text_or_low_available_confidence(self):
        clear = (self._detection("Readable", 0, 0, 0.96, height=30),)
        small = (self._detection("small", 0, 0, 0.96, height=14),)
        very_confident_small = (self._detection("high confidence", 0, 0, 0.999, height=14),)
        mixed_confidence_small = tuple(
            self._detection("certain", index * 10, 0, 0.9999, height=14) for index in range(20)
        ) + (self._detection("uncertain", 240, 0, 0.90, height=14),)
        weak = (self._detection("weak", 0, 0, 0.55, height=30),)
        self.assertFalse(should_retry((1280, 720), clear))
        self.assertTrue(should_retry((1280, 720), small))
        self.assertFalse(should_retry((1280, 720), very_confident_small))
        self.assertTrue(should_retry((1280, 720), mixed_confidence_small))
        self.assertTrue(should_retry((1280, 720), weak))

    def test_candidate_selection_is_deterministic_and_keeps_original_on_tie(self):
        original = OcrCandidate("original", "same text", 0.90)
        retry = OcrCandidate("upscale", "better text", 0.90)
        self.assertIs(select_candidate((original, retry)), original)

    def test_missing_confidence_requires_clear_structural_improvement(self):
        original = OcrCandidate("original", "", None)
        retry = OcrCandidate("upscale", "Recovered passage", None)
        self.assertIs(select_candidate((original, retry)), retry)
        weak_retry = OcrCandidate("sharpen", "noise", None)
        readable = OcrCandidate("original", "Some readable text", None)
        self.assertIs(select_candidate((readable, weak_retry)), readable)

    def test_retry_pipeline_runs_at_most_two_variants_and_preserves_original(self):
        calls = []
        image = Image.new("RGB", (320, 180), "white")

        def fake_ocr(pixels):
            calls.append(pixels.shape[:2])
            if len(calls) == 1:
                return ([[[[10, 10], [100, 10], [100, 22], [10, 22]], "small text", 0.55]], [])
            return ([[[[10, 10], [100, 10], [100, 22], [10, 22]], "small text", 0.55]], [])

        selected, candidates = run_ocr_recovery(image, fake_ocr)
        self.assertLessEqual(len(calls), 2)
        self.assertEqual(len(candidates), len(calls))
        self.assertEqual(selected.text, "small text")
        self.assertEqual(calls[0], (180, 320))

    def test_recovery_skips_retry_for_small_text_with_very_high_confidence(self):
        image = Image.new("RGB", (1280, 720), "white")
        calls = []

        def confident_ocr(_pixels):
            calls.append(True)
            box = [[10, 10], [90, 10], [90, 24], [10, 24]]
            return ([[box, "Small but readable", 0.999]], [])

        selected, candidates = run_ocr_recovery(image, confident_ocr)

        self.assertEqual(len(calls), 1)
        self.assertEqual(len(candidates), 1)
        self.assertEqual(selected.text, "Small but readable")

    def test_empty_or_malformed_ocr_output_falls_back_without_raising(self):
        image = Image.new("RGB", (320, 180), "white")
        selected, candidates = run_ocr_recovery(image, lambda _: (None, []))
        self.assertEqual(selected.text, "")
        self.assertEqual(len(candidates), 2)

        selected, candidates = run_ocr_recovery(image, lambda _: (_ for _ in ()).throw(RuntimeError("offline")))
        self.assertEqual(selected.text, "")
        self.assertEqual(len(candidates), 2)

    def test_character_error_rate_uses_character_edits(self):
        self.assertEqual(character_error_rate("kitten", "sitting"), 0.5)
        self.assertEqual(character_error_rate("same text", "same text"), 0.0)

    def test_word_error_rate_uses_whitespace_tokens(self):
        self.assertEqual(word_error_rate("this is a test", "this is test"), 0.25)
        self.assertEqual(word_error_rate("  two   words ", "two words"), 0.0)

    def test_nearest_rank_latency_summary_is_deterministic(self):
        self.assertEqual(percentile([4.0, 1.0, 3.0, 2.0], 0.5), 2.0)
        self.assertEqual(summarize_rates([4.0, 1.0, 3.0, 2.0]), {"median": 2.5, "p95": 4.0})
        self.assertIsNone(percentile([], 0.95))

    def test_latency_gate_checks_aggregate_and_each_image_condition(self):
        summary = {
            "clean": {"scan_latency_seconds": {"p95": 2.7}},
            "small": {"scan_latency_seconds": {"p95": 3.2}},
            "blurred": {"scan_latency_seconds": {"p95": 2.8}},
            "all": {"scan_latency_seconds": {"p95": 2.9}},
        }

        self.assertEqual(latency_p95_violations(summary, 3.0), {"small": 3.2})

    def test_latency_gate_reports_aggregate_and_condition_violations(self):
        summary = {
            "clean": {"scan_latency_seconds": {"p95": 2.7}},
            "small": {"scan_latency_seconds": {"p95": 3.2}},
            "blurred": {"scan_latency_seconds": {"p95": 3.4}},
            "all": {"scan_latency_seconds": {"p95": 3.1}},
        }

        self.assertEqual(
            latency_p95_violations(summary, 3.0),
            {"small": 3.2, "blurred": 3.4, "all": 3.1},
        )

    def test_error_rates_define_empty_reference_behavior(self):
        self.assertEqual(character_error_rate("", ""), 0.0)
        self.assertEqual(word_error_rate("", ""), 0.0)
        self.assertEqual(character_error_rate("", "x"), 1.0)
        self.assertEqual(word_error_rate("", "x"), 1.0)

    def test_legacy_rapidocr_result_retains_boxes_and_confidence(self):
        box = [[1, 2], [30, 2], [30, 18], [1, 18]]
        parsed = parse_rapidocr_result(([[box, "Hello", 0.97]], [0.012]))

        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0].text, "Hello")
        self.assertEqual(parsed[0].box, ((1.0, 2.0), (30.0, 2.0), (30.0, 18.0), (1.0, 18.0)))
        self.assertEqual(parsed[0].confidence, 0.97)

    def test_missing_or_invalid_legacy_confidence_stays_unavailable(self):
        box = [[0, 0], [10, 0], [10, 10], [0, 10]]
        parsed = parse_rapidocr_result(([[box, "Word"], [box, "Other", "not-a-score"]], []))

        self.assertEqual([item.text for item in parsed], ["Word", "Other"])
        self.assertEqual([item.confidence for item in parsed], [None, None])

    def test_malformed_rapidocr_rows_are_skipped_without_inventing_data(self):
        parsed = parse_rapidocr_result(([
            [[], "No geometry", 0.9],
            ["not-a-box", "Bad geometry", 0.8],
            [[(0, 0), (5, 0), (5, 5), (0, 5)], "Valid", 1.2],
        ], []))

        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0].text, "Valid")
        self.assertIsNone(parsed[0].confidence)

    def test_benchmark_fixture_has_24_fixed_samples_across_three_classes(self):
        first = generate_benchmark_samples()
        second = generate_benchmark_samples()

        self.assertEqual(len(first), 24)
        self.assertEqual({sample.condition for sample in first}, {"clean", "small", "blurred"})
        self.assertEqual({condition: sum(sample.condition == condition for sample in first)
                          for condition in ("clean", "small", "blurred")}, {
                "clean": 8,
                "small": 8,
                "blurred": 8,
            })
        self.assertTrue(all(sample.image.size == (1280, 720) for sample in first))
        self.assertEqual(
            [(sample.sample_id, sample.source_text, sample.image.tobytes()) for sample in first],
            [(sample.sample_id, sample.source_text, sample.image.tobytes()) for sample in second],
        )
