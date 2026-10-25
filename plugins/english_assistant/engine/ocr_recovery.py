"""Offline OCR benchmark helpers and adapter for the legacy RapidOCR result."""

from __future__ import annotations

from dataclasses import dataclass
import math
import re
import statistics
import textwrap
from functools import lru_cache
from typing import Any, Callable, Sequence

from PIL import Image, ImageDraw, ImageFilter, ImageFont


@dataclass(frozen=True)
class RapidOcrDetection:
    """One legacy RapidOCR detection with its original box and optional score."""

    text: str
    box: tuple[tuple[float, float], ...]
    confidence: float | None


@dataclass(frozen=True)
class OcrCandidate:
    """Recognized text and evidence associated with one image variant."""

    variant: str
    text: str
    confidence: float | None
    detections: tuple[RapidOcrDetection, ...] = ()


@dataclass(frozen=True)
class BenchmarkSample:
    """A reproducible generated image and its ground-truth passage."""

    sample_id: str
    condition: str
    source_text: str
    image: Image.Image


@lru_cache(maxsize=16)
def _vocabulary_by_length(vocabulary: frozenset[str]) -> dict[int, tuple[str, ...]]:
    grouped: dict[int, list[str]] = {}
    for word in vocabulary:
        grouped.setdefault(len(word), []).append(word)
    return {length: tuple(sorted(words)) for length, words in grouped.items()}


def _has_known_inflection(word: str, vocabulary: frozenset[str]) -> bool:
    stems: set[str] = set()
    if word.endswith("ies") and len(word) > 4:
        stems.add(word[:-3] + "y")
    if word.endswith("ves") and len(word) > 4:
        stems.update((word[:-3] + "f", word[:-3] + "fe"))
    if word.endswith("es") and len(word) > 4:
        stems.update((word[:-2], word[:-1]))
    if word.endswith("s") and len(word) > 3:
        stems.add(word[:-1])
    if word.endswith("ed") and len(word) > 4:
        stems.update((word[:-2], word[:-1], word[:-2] + "e"))
        if word.endswith("ied"):
            stems.add(word[:-3] + "y")
        if len(word) > 4 and word[-3] == word[-4]:
            stems.add(word[:-3])
    if word.endswith("ing") and len(word) > 5:
        stems.update((word[:-3], word[:-3] + "e"))
        if word[-4] == word[-5]:
            stems.add(word[:-4])
    if word.endswith("ly") and len(word) > 4:
        stems.update((word[:-2], word[:-2] + "e"))
    return bool(stems & vocabulary)


def _is_one_edit_away(source: str, target: str) -> bool:
    if abs(len(source) - len(target)) > 1:
        return False
    if len(source) == len(target):
        mismatches = [index for index, (left, right) in enumerate(zip(source, target)) if left != right]
        if not mismatches:
            return False
        if len(mismatches) == 1:
            return True
        return (
            len(mismatches) == 2
            and mismatches[1] == mismatches[0] + 1
            and source[mismatches[0]] == target[mismatches[1]]
            and source[mismatches[1]] == target[mismatches[0]]
        )

    shorter, longer = (source, target) if len(source) < len(target) else (target, source)
    short_index = long_index = edits = 0
    while short_index < len(shorter) and long_index < len(longer):
        if shorter[short_index] == longer[long_index]:
            short_index += 1
            long_index += 1
        else:
            edits += 1
            long_index += 1
            if edits > 1:
                return False
    return True


def _correct_with_index(
    text: str,
    confidence: float | None,
    vocabulary: frozenset[str],
    by_length: dict[int, tuple[str, ...]],
    confidence_threshold: float,
    minimum_similarity: float,
    ambiguity_margin: float,
) -> str:
    if (
        not text
        or confidence is None
        or not math.isfinite(confidence)
        or not 0.0 <= confidence <= 1.0
        or confidence < confidence_threshold
    ):
        return text

    import difflib

    def replace(match: re.Match[str]) -> str:
        token = match.group(0)
        lower = token.lower()
        if (
            lower in vocabulary
            or _has_known_inflection(lower, vocabulary)
            or token[0].isupper()
            or token.isupper()
            or len(token) < 5
        ):
            return token
        candidates = []
        for length in range(max(1, len(lower) - 1), len(lower) + 2):
            for word in by_length.get(length, ()):
                score = difflib.SequenceMatcher(None, lower, word).ratio()
                candidates.append((score, word))
        if not candidates:
            return token
        candidates.sort(key=lambda item: (-item[0], item[1]))
        best_score, best_word = candidates[0]
        second_score = candidates[1][0] if len(candidates) > 1 else 0.0
        if (
            best_score < minimum_similarity
            or best_score - second_score <= ambiguity_margin
            or not _is_one_edit_away(lower, best_word)
        ):
            return token
        return best_word

    return re.sub(r"[A-Za-z]+", replace, text)


def correct_ocr_text(
    text: str,
    confidence: float | None,
    vocabulary: Sequence[str] | set[str],
    *,
    confidence_threshold: float = 0.90,
    minimum_similarity: float = 0.84,
    ambiguity_margin: float = 0.12,
) -> str:
    """Apply only strong, unambiguous dictionary corrections to lowercase words."""
    normalized = frozenset(word.lower() for word in vocabulary if word and word.isalpha())
    return _correct_with_index(
        text,
        confidence,
        normalized,
        _vocabulary_by_length(normalized),
        confidence_threshold,
        minimum_similarity,
        ambiguity_margin,
    )


def correct_ocr_detections(
    detections: Sequence[RapidOcrDetection],
    vocabulary: Sequence[str] | set[str],
    *,
    confidence_threshold: float = 0.90,
    minimum_similarity: float = 0.84,
    ambiguity_margin: float = 0.12,
) -> str:
    """Correct each recognized region using only that region's OCR confidence."""
    normalized_vocabulary = frozenset(word.lower() for word in vocabulary if word and word.isalpha())
    by_length = _vocabulary_by_length(normalized_vocabulary)
    corrected = tuple(
        RapidOcrDetection(
            text=_correct_with_index(
                item.text,
                item.confidence,
                normalized_vocabulary,
                by_length,
                confidence_threshold,
                minimum_similarity,
                ambiguity_margin,
            ),
            box=item.box,
            confidence=item.confidence,
        )
        for item in detections
    )
    return reconstruct_reading_order(corrected)


def parse_rapidocr_result(output: Any) -> tuple[RapidOcrDetection, ...]:
    """Adapt ``(detections, timings)`` from rapidocr_onnxruntime 1.x.

    Legacy detection rows are ``[quadrilateral, text, score?]``. Invalid rows
    are skipped and absent or out-of-range scores remain unavailable.
    """
    rows: Any = output[0] if isinstance(output, tuple) and output else output
    if not isinstance(rows, Sequence) or isinstance(rows, (str, bytes)):
        return ()

    detections: list[RapidOcrDetection] = []
    for row in rows:
        if not isinstance(row, Sequence) or isinstance(row, (str, bytes)) or len(row) < 2:
            continue
        raw_box, raw_text = row[0], row[1]
        if not isinstance(raw_text, str) or not raw_text.strip():
            continue
        try:
            box = tuple((float(point[0]), float(point[1])) for point in raw_box)
        except (TypeError, ValueError, IndexError, OverflowError):
            continue
        if len(box) < 4 or not all(math.isfinite(value) for point in box for value in point):
            continue

        confidence: float | None = None
        if len(row) > 2:
            try:
                score = float(row[2])
            except (TypeError, ValueError, OverflowError):
                score = math.nan
            if math.isfinite(score) and 0.0 <= score <= 1.0:
                confidence = score
        detections.append(RapidOcrDetection(raw_text.strip(), box, confidence))
    return tuple(detections)


def _bounds(detection: RapidOcrDetection) -> tuple[float, float, float, float]:
    xs = [point[0] for point in detection.box]
    ys = [point[1] for point in detection.box]
    return min(xs), min(ys), max(xs), max(ys)


def reconstruct_reading_order(detections: Sequence[RapidOcrDetection]) -> str:
    """Group nearby detections into lines, then sort each line from left to right."""
    measured = []
    heights = []
    for detection in detections:
        text = " ".join("".join(character if 0x20 <= ord(character) <= 0x7E else " " for character in detection.text).split())
        if not text:
            continue
        left, top, right, bottom = _bounds(detection)
        height = max(1.0, bottom - top)
        heights.append(height)
        measured.append({"text": text, "left": left, "center_y": (top + bottom) / 2, "height": height})
    if not measured:
        return ""

    typical_height = statistics.median(heights)
    line_tolerance = max(6.0, typical_height * 0.65)
    lines: list[dict[str, Any]] = []
    for item in sorted(measured, key=lambda part: (part["center_y"], part["left"])):
        matching = [line for line in lines if abs(line["center_y"] - item["center_y"]) <= line_tolerance]
        if matching:
            line = min(matching, key=lambda group: abs(group["center_y"] - item["center_y"]))
            line["items"].append(item)
            line["center_y"] = sum(part["center_y"] for part in line["items"]) / len(line["items"])
        else:
            lines.append({"center_y": item["center_y"], "items": [item]})

    ordered_lines = []
    for line in sorted(lines, key=lambda group: group["center_y"]):
        ordered_lines.append(" ".join(item["text"] for item in sorted(line["items"], key=lambda part: part["left"])))
    return " ".join(ordered_lines)


def should_retry(
    image_size: tuple[int, int],
    detections: Sequence[RapidOcrDetection],
    *,
    small_text_height: float = 19.5,
    weak_confidence: float = 0.82,
    strong_confidence: float = 0.995,
) -> bool:
    """Retry weak/small text, except when every detected region is very certain."""
    if not detections:
        return True
    confidences = [item.confidence for item in detections]
    available = [score for score in confidences if score is not None]
    if len(available) == len(detections) and all(score >= strong_confidence for score in available):
        return False

    heights = [_bounds(item)[3] - _bounds(item)[1] for item in detections]
    if heights and statistics.median(heights) < small_text_height:
        return True
    if available and sum(available) / len(available) < weak_confidence:
        return True
    width, height = image_size
    return min(width, height) < 480


def _candidate_confidence(detections: Sequence[RapidOcrDetection]) -> float | None:
    if not detections or any(item.confidence is None for item in detections):
        return None
    weights = [max(1, len(item.text)) for item in detections]
    return sum(item.confidence * weight for item, weight in zip(detections, weights)) / sum(weights)


def _structural_improvement(candidate: OcrCandidate, selected: OcrCandidate) -> bool:
    candidate_text = candidate.text.strip()
    selected_text = selected.text.strip()
    if candidate_text and not selected_text:
        return True
    candidate_alnum = sum(character.isalnum() for character in candidate_text)
    selected_alnum = sum(character.isalnum() for character in selected_text)
    candidate_total = max(1, sum(not character.isspace() for character in candidate_text))
    selected_total = max(1, sum(not character.isspace() for character in selected_text))
    candidate_ratio = candidate_alnum / candidate_total
    selected_ratio = selected_alnum / selected_total
    clear_gain = max(5, math.ceil(selected_alnum * 0.30))
    return candidate_alnum >= selected_alnum + clear_gain and candidate_ratio >= selected_ratio


def select_candidate(candidates: Sequence[OcrCandidate]) -> OcrCandidate:
    """Select by available confidence; without it, require a clear structural gain."""
    if not candidates:
        return OcrCandidate("original", "", None)
    selected = candidates[0]
    for candidate in candidates[1:]:
        if not candidate.text.strip():
            continue
        if not selected.text.strip():
            selected = candidate
            continue
        if candidate.confidence is not None and selected.confidence is None:
            selected = candidate
        elif candidate.confidence is not None and selected.confidence is not None:
            if candidate.confidence > selected.confidence + 0.02:
                selected = candidate
        elif candidate.confidence is None and selected.confidence is None:
            if _structural_improvement(candidate, selected):
                selected = candidate
    return selected


def _enhanced_variants(image: Image.Image) -> tuple[tuple[str, Image.Image], ...]:
    """Build one bounded retry that upscales and conservatively sharpens the image."""
    import cv2
    import numpy as np

    width, height = image.size
    scale = min(1.25, 1920 / max(width, height))
    scale = max(1.0, scale)
    target_size = (max(width, round(width * scale)), max(height, round(height * scale)))
    rgb = np.asarray(image.convert("RGB"))
    upscaled = cv2.resize(rgb, target_size, interpolation=cv2.INTER_CUBIC) if target_size != (width, height) else rgb.copy()
    gray = cv2.cvtColor(upscaled, cv2.COLOR_RGB2GRAY)
    softened = cv2.GaussianBlur(gray, (0, 0), 1.0)
    sharpened = cv2.addWeighted(gray, 1.35, softened, -0.35, 0)
    sharpened_rgb = cv2.cvtColor(sharpened, cv2.COLOR_GRAY2RGB)
    return (("upscale_sharpen", Image.fromarray(sharpened_rgb)),)


def run_ocr_recovery(
    image: Image.Image,
    ocr_callable: Callable[[Any], Any],
) -> tuple[OcrCandidate, tuple[OcrCandidate, ...]]:
    """Run the original OCR and up to two gated retries, preserving the best evidence."""
    import numpy as np

    def run_variant(variant: str, candidate_image: Image.Image) -> OcrCandidate:
        try:
            output = ocr_callable(np.asarray(candidate_image.convert("RGB")))
            detections = parse_rapidocr_result(output)
        except Exception:
            detections = ()
        return OcrCandidate(
            variant=variant,
            text=reconstruct_reading_order(detections),
            confidence=_candidate_confidence(detections),
            detections=detections,
        )

    original = run_variant("original", image)
    candidates = [original]
    if should_retry(image.size, original.detections):
        for variant, enhanced in _enhanced_variants(image)[:2]:
            candidates.append(run_variant(variant, enhanced))
    pool = tuple(candidates)
    return select_candidate(pool), pool


def _edit_distance(reference: Sequence[Any], hypothesis: Sequence[Any]) -> int:
    if len(reference) < len(hypothesis):
        reference, hypothesis = hypothesis, reference
    previous = list(range(len(hypothesis) + 1))
    for ref_index, ref_item in enumerate(reference, start=1):
        current = [ref_index]
        for hyp_index, hyp_item in enumerate(hypothesis, start=1):
            current.append(min(
                current[-1] + 1,
                previous[hyp_index] + 1,
                previous[hyp_index - 1] + (ref_item != hyp_item),
            ))
        previous = current
    return previous[-1]


def _normalized_text(text: str) -> str:
    return " ".join(text.split())


def _error_rate(reference: Sequence[Any], hypothesis: Sequence[Any]) -> float:
    if not reference:
        return 0.0 if not hypothesis else 1.0
    return _edit_distance(reference, hypothesis) / len(reference)


def character_error_rate(reference: str, hypothesis: str) -> float:
    """Return case-sensitive CER after collapsing whitespace runs."""
    return _error_rate(tuple(_normalized_text(reference)), tuple(_normalized_text(hypothesis)))


def word_error_rate(reference: str, hypothesis: str) -> float:
    """Return case-sensitive whitespace-token WER."""
    ref_text = _normalized_text(reference)
    hyp_text = _normalized_text(hypothesis)
    return _error_rate(tuple(ref_text.split()), tuple(hyp_text.split()))


def percentile(values: Sequence[float], fraction: float) -> float | None:
    """Return the nearest-rank percentile for a fraction in the range [0, 1]."""
    if not values:
        return None
    if not 0.0 <= fraction <= 1.0:
        raise ValueError("fraction must be between 0 and 1")
    ordered = sorted(values)
    rank = max(1, math.ceil(fraction * len(ordered)))
    return ordered[rank - 1]


def summarize_rates(values: Sequence[float]) -> dict[str, float | None]:
    if not values:
        return {"median": None, "p95": None}
    return {
        "median": statistics.median(values),
        "p95": percentile(values, 0.95),
    }


def latency_p95_violations(
    conditions: dict[str, Any],
    maximum_seconds: float,
) -> dict[str, float | None]:
    """Return aggregate or per-condition p95 values that miss the latency limit."""
    if not math.isfinite(maximum_seconds) or maximum_seconds <= 0:
        raise ValueError("maximum_seconds must be a finite positive value")

    violations: dict[str, float | None] = {}
    for condition, summary in conditions.items():
        latency = summary.get("scan_latency_seconds", {})
        p95 = latency.get("p95") if isinstance(latency, dict) else None
        if p95 is None:
            violations[condition] = None
            continue
        try:
            measured = float(p95)
        except (TypeError, ValueError, OverflowError):
            violations[condition] = None
            continue
        if not math.isfinite(measured) or measured > maximum_seconds:
            violations[condition] = measured if math.isfinite(measured) else None
    return violations


_BENCHMARK_PASSAGES = (
    "Water conservation begins with small daily choices. Families can save clean water by fixing leaks and turning off taps.",
    "A balanced breakfast gives students energy for learning. Whole grains, fruit, and water make a healthy morning meal.",
    "Urban trees provide shade and reduce heat. Their roots absorb rainwater, while their leaves offer shelter to birds.",
    "Recycling works best when materials are sorted carefully. Paper, glass, and metal can become useful products again.",
    "The science club planted native flowers near the library. These plants attract pollinators and need less watering.",
    "Public transport can reduce traffic in busy towns. Frequent buses also help people reach school and work affordably.",
    "Reading aloud helps learners notice rhythm and pronunciation. Partners can take turns and discuss unfamiliar words.",
    "A clear experiment changes one factor at a time. Students record each result and explain what the evidence supports.",
)


def generate_benchmark_samples() -> tuple[BenchmarkSample, ...]:
    """Generate 24 fixed 1280x720 English text images in three quality bands."""
    samples: list[BenchmarkSample] = []
    for condition, font_size, blur_radius in (
        ("clean", 30, 0.0),
        ("small", 14, 0.0),
        ("blurred", 26, 1.2),
    ):
        font = ImageFont.load_default(size=font_size)
        for index, passage in enumerate(_BENCHMARK_PASSAGES, start=1):
            image = Image.new("RGB", (1280, 720), "white")
            draw = ImageDraw.Draw(image)
            lines = textwrap.wrap(passage, width=74, break_long_words=False)
            draw.multiline_text((56, 64), "\n".join(lines), fill=(15, 15, 15), font=font, spacing=18)
            if blur_radius:
                image = image.filter(ImageFilter.GaussianBlur(radius=blur_radius))
            samples.append(BenchmarkSample(
                sample_id=f"{condition}-{index:02d}",
                condition=condition,
                source_text=passage,
                image=image,
            ))
    return tuple(samples)
