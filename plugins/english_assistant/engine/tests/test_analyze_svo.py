"""API regression coverage for text and image OCR inputs."""

import io
import os
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi.testclient import TestClient
from PIL import Image

ENGINE_DIR = os.path.dirname(os.path.dirname(__file__))
sys.path.insert(0, ENGINE_DIR)

import service  # noqa: E402


class AnalyzeSvoApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(service.app)
        self.nlp_patch = patch.object(service, "nlp", None)
        self.nlp_patch.start()
        self.addCleanup(self.nlp_patch.stop)

    @staticmethod
    def _image_upload():
        image = Image.new("RGB", (320, 180), "white")
        stream = io.BytesIO()
        image.save(stream, format="PNG")
        return {"image": ("passage.png", stream.getvalue(), "image/png")}

    @staticmethod
    def _rapid_result(text="languge,", confidence=0.99):
        box = [[10, 10], [200, 10], [200, 40], [10, 40]]
        return ([[box, text, confidence]], [])

    def _assert_response_shape(self, response):
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(set(data), {"original_text", "tokens", "grammar_issue"})
        self.assertIsInstance(data["tokens"], list)
        return data

    def test_text_only_request_keeps_response_shape_and_input_text(self):
        response = self.client.post("/analyze-svo", data={"text": "Teachers teach English."})
        data = self._assert_response_shape(response)
        self.assertEqual(data["original_text"], "teachers teach English.")

    def test_rapidocr_image_uses_confidence_gated_dictionary_correction(self):
        with (
            patch.object(service, "rapid_ocr", side_effect=lambda _: self._rapid_result()),
            patch.object(service, "OXFORD_FULL_VOCAB", {"language", "landscape"}),
        ):
            response = self.client.post("/analyze-svo", files=self._image_upload())
        data = self._assert_response_shape(response)
        self.assertEqual(data["original_text"], "language,")

    def test_weak_or_missing_rapidocr_confidence_preserves_the_recognized_word(self):
        for confidence in (0.89, None):
            with self.subTest(confidence=confidence):
                with (
                    patch.object(service, "rapid_ocr", side_effect=lambda _, score=confidence: self._rapid_result(confidence=score)),
                    patch.object(service, "OXFORD_FULL_VOCAB", {"language"}),
                ):
                    response = self.client.post("/analyze-svo", files=self._image_upload())
                data = self._assert_response_shape(response)
                self.assertEqual(data["original_text"], "languge,")

    def test_tesseract_without_confidence_does_not_guess_dictionary_words(self):
        with (
            patch.object(service, "rapid_ocr", None),
            patch.object(service, "has_pytesseract", True),
            patch.object(service, "pytesseract", SimpleNamespace(image_to_string=lambda *_args, **_kwargs: "languge"), create=True),
            patch.object(service, "OXFORD_FULL_VOCAB", {"language"}),
        ):
            response = self.client.post("/analyze-svo", files=self._image_upload())
        data = self._assert_response_shape(response)
        self.assertEqual(data["original_text"], "languge")

    def test_empty_unavailable_and_throwing_ocr_keep_graceful_response(self):
        cases = ("empty", "unavailable", "throws")
        for label in cases:
            with self.subTest(label=label):
                with (
                    patch.object(
                        service,
                        "rapid_ocr",
                        side_effect=RuntimeError("offline") if label == "throws" else (lambda _: (None, [])),
                    ) if label != "unavailable" else patch.object(service, "rapid_ocr", None),
                    patch.object(service, "has_pytesseract", False),
                    patch.object(service, "nlp", None),
                ):
                    response = self.client.post("/analyze-svo", files=self._image_upload())
                data = self._assert_response_shape(response)
                self.assertEqual(data["original_text"], "")


if __name__ == "__main__":
    unittest.main()
