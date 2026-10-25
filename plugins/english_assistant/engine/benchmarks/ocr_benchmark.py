"""Generate and run the fixed English OCR benchmark through the current OCR pipeline."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.metadata
import io
import json
import os
import platform
import sys
import time
from collections import defaultdict
from pathlib import Path
from statistics import median
from typing import Any

ENGINE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ENGINE_DIR))

from ocr_recovery import (  # noqa: E402
    character_error_rate,
    generate_benchmark_samples,
    latency_p95_violations,
    summarize_rates,
    word_error_rate,
)


def _version(distribution: str) -> str | None:
    try:
        return importlib.metadata.version(distribution)
    except importlib.metadata.PackageNotFoundError:
        return None


def _start_host_cpu_measurement():
    """Return an optional psutil handle, primed for non-blocking CPU sampling."""
    try:
        import psutil
    except ImportError:
        return None
    psutil.cpu_percent(interval=None)
    return psutil


def run_current_pipeline(
    *,
    repeat_count: int = 5,
    max_p95_seconds: float = 3.0,
) -> dict[str, Any]:
    """Measure the current `/analyze-svo` image path and preserve each output."""
    if repeat_count < 1:
        raise ValueError("repeat_count must be at least 1")
    try:
        import service
    except Exception as error:
        raise RuntimeError(f"Could not import the English Assistant sidecar: {error}") from error
    if service.rapid_ocr is None or not service.has_pil:
        raise RuntimeError("The actual offline RapidOCR and Pillow runtime is unavailable")

    try:
        from fastapi.testclient import TestClient
    except ImportError as error:
        raise RuntimeError("FastAPI TestClient dependencies are required to measure the current endpoint") from error

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    all_rows: list[dict[str, Any]] = []
    samples = generate_benchmark_samples()
    with TestClient(service.app) as client:
        warmup = samples[0]
        warmup_stream = io.BytesIO()
        warmup.image.save(warmup_stream, format="PNG", optimize=False)
        warmup_response = client.post(
            "/analyze-svo",
            files={"image": (f"{warmup.sample_id}-warmup.png", warmup_stream.getvalue(), "image/png")},
        )
        warmup_response.raise_for_status()
        cpu_monitor = _start_host_cpu_measurement()

        for repeat_index in range(1, repeat_count + 1):
            for sample in samples:
                image_stream = io.BytesIO()
                sample.image.save(image_stream, format="PNG", optimize=False)
                filename = f"{sample.sample_id}-r{repeat_index}.png"
                start = time.perf_counter()
                response = client.post(
                    "/analyze-svo",
                    files={"image": (filename, image_stream.getvalue(), "image/png")},
                )
                latency_seconds = time.perf_counter() - start
                response.raise_for_status()
                response_data = response.json()
                recognized = response_data.get("original_text", "")
                row = {
                    "sample_id": sample.sample_id,
                    "repeat": repeat_index,
                    "condition": sample.condition,
                    "source_text": sample.source_text,
                    "recognized_text": recognized,
                    "cer": character_error_rate(sample.source_text, recognized),
                    "wer": word_error_rate(sample.source_text, recognized),
                    "scan_latency_seconds": latency_seconds,
                }
                grouped[sample.condition].append(row)
                all_rows.append(row)

    summary = {}
    for condition, rows in sorted(grouped.items()):
        summary[condition] = {
            "sample_count": len(rows),
            "cer": summarize_rates([row["cer"] for row in rows]),
            "wer": summarize_rates([row["wer"] for row in rows]),
            "scan_latency_seconds": summarize_rates([row["scan_latency_seconds"] for row in rows]),
        }
    summary["all"] = {
        "sample_count": len(all_rows),
        "cer": summarize_rates([row["cer"] for row in all_rows]),
        "wer": summarize_rates([row["wer"] for row in all_rows]),
        "scan_latency_seconds": summarize_rates([row["scan_latency_seconds"] for row in all_rows]),
        "mean_scan_latency_seconds": sum(row["scan_latency_seconds"] for row in all_rows) / len(all_rows),
    }

    violations = latency_p95_violations(summary, max_p95_seconds)
    return {
        "kind": "current_pipeline",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "measurement": "end-to-end /analyze-svo response time after one unmeasured OCR warm-up request, including OCR and S-V-O parsing",
        "warmup_requests": 1,
        "repeat_count": repeat_count,
        "latency_gate": {
            "maximum_p95_seconds": max_p95_seconds,
            "scope": "aggregate and every image condition",
            "passed": not violations,
            "violations": violations,
        },
        "host": {
            "logical_cpu_count": os.cpu_count(),
            "cpu_utilization_percent_during_measured_requests": (
                cpu_monitor.cpu_percent(interval=None) if cpu_monitor is not None else None
            ),
        },
        "runtime": {
            "python": platform.python_version(),
            "pillow": _version("Pillow"),
            "numpy": _version("numpy"),
            "opencv": _version("opencv-python") or _version("opencv-python-headless"),
            "rapidocr_onnxruntime": _version("rapidocr-onnxruntime"),
            "rapidocr_model": "en_PP-OCRv4_rec_infer.onnx",
            "pytesseract_available": service.has_pytesseract,
        },
        "conditions": summary,
        "samples": all_rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default=str(ENGINE_DIR / "benchmarks" / "final.json"),
        help="JSON report destination (default: engine/benchmarks/final.json)",
    )
    parser.add_argument(
        "--repeats",
        type=int,
        default=5,
        help="number of times to scan each fixed image (default: 5)",
    )
    parser.add_argument(
        "--max-p95-seconds",
        type=float,
        default=3.0,
        help="fail if aggregate or any image condition exceeds this p95 (default: 3)",
    )
    args = parser.parse_args()
    report = run_current_pipeline(repeat_count=args.repeats, max_p95_seconds=args.max_p95_seconds)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["conditions"], ensure_ascii=False, indent=2))
    print(f"Final benchmark report written to {output_path}")
    if not report["latency_gate"]["passed"]:
        print(
            f"Latency gate failed (maximum p95 {args.max_p95_seconds:.3f}s): "
            f"{report['latency_gate']['violations']}",
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
