# OCR Engine and Dependency Audit

> **Superseded product decision (2026-10-29):** OCR is out of scope for English Assistant. This document records historical dependency findings only. Do not select, package, restore, or benchmark an OCR engine for this feature without a new product decision. OCR source files and model assets have been removed.

**Audit baseline:** repository commit `116510b`, local Windows environment, 2026-10-28. This is a candidate audit, not approval to distribute an engine or remove existing assets.

## Historical Python OCR Baseline (Commit `116510b`)

- `service.py` loads Pillow and optionally `pytesseract`, then attempts `rapidocr_onnxruntime.RapidOCR`.
- RapidOCR selects plugin English PP-OCRv4 recognition weights first, then v3 and `en_dict.txt`; if those files are absent it falls back to its default configuration.
- Image requests enter OCR only when `image` is present and the request's text is blank. The image is decoded to RGB; dark images are inverted before `run_ocr_recovery`.
- `run_ocr_recovery` retains the original and permits at most one enhanced retry. It retries for median detected text height below 19.5 px or mean valid confidence below 0.82, except small text when all detection confidence is at least 0.995. It preserves geometry/read order and selects the original on unsupported/tied evidence.
- Correction occurs per recognition region only with finite confidence >=0.90, a one-edit candidate, similarity >=0.84 and margin >=0.12. Proper-name-like, known, inflected and ambiguous words are preserved.
- If RapidOCR is unavailable, the legacy route can use `pytesseract` with `--psm 7`; it applies no confidence-based lexical correction. OCR exceptions are caught and the S-V-O response continues with empty recovered text.

## Installed Runtime and Assets Observed

| Component | Local observation | Distribution/license status |
|---|---|---|
| Python | 3.12.10 | Temporary comparison only; final plugin must remove it. |
| `rapidocr_onnxruntime` | 1.4.4; installed from Python site-packages; package metadata says Apache-2.0. | Official docs now state the legacy `rapidocr_onnxruntime` package family is gradually being retired in favor of `rapidocr`. Do not carry its Python wrapper into the final plugin. |
| Pillow | 12.3.0 | Present in current environment; absent from `requirements.txt`; Python-only preprocessing dependency. |
| NumPy | 2.4.6 | Present; absent from `requirements.txt`; Python-only preprocessing dependency. |
| OpenCV | `opencv-python` 5.0.0.93 | Present; absent from `requirements.txt`; not established as required for the final adapter. |
| Tesseract | `pytesseract` package absent; `tesseract.exe` not on PATH. | Cannot run an actual local Tesseract spike in this environment without obtaining a Windows build. |
| Plugin recognition assets | v4 7,656,802 bytes, SHA-256 `5CA59A096CF493D5FD5044B9CCC1BDEA9229FBCF656BD76040FF80A00201EE16`; v3 8,967,018 bytes, SHA-256 `EF7ABD8BD3629AE57EA2C28B425C1BD258A871B93FD2FE7C433946ADE9B5D9EA`; `en_dict.txt` 190 bytes, SHA-256 `5662DF9D2D03F0E8CA0D3B0649D6ACBAB904B6A14B3D3521463C71C37C668CE3`. | Files are in the repo but no adjacent OCR-specific LICENSE/NOTICE file was found. Exact upstream model version/source must be tied to each hash before redistribution. |
| RapidOCR default detection/classification assets | The installed package has PP-OCRv4 detector 4,745,517 bytes, recognizer 10,857,958 bytes and classifier 585,532 bytes under its local `models/` folder. | These files are outside the plugin. A final offline package must explicitly include approved local model/runtime assets; implicit site-packages/cache and download-at-runtime behavior is not acceptable. |
| `english_vocab.txt` | 39,386 bytes; service log calls it Oxford 5000 and loads 5,016 rows. | Current plugin has no clear adjacent source/license manifest; confirm source/terms before using it for correction or replacing its use. |

At the audited baseline, `requirements.txt` contained FastAPI, Uvicorn and Pydantic only. The Python analysis sidecar and requirements file have since been removed from the working plugin source. Historical OCR dependency availability does not prove the Dart package is self-contained.

## Candidate Selection for the Dart Adapter

1. **Primary spike: Tesseract 5 + English `tessdata_fast`.** The upstream engine documents Apache-2.0 and Windows installation options; `tessdata_fast` documents Apache-2.0. hOCR provides recognized words with coordinates. Windows binaries are distributed through UB Mannheim according to upstream installation docs, so the exact executable, bundled DLLs, provenance, license notices and redistribution terms still require review. Neither the executable nor model is installed locally, so no accuracy/performance claim has been made.
2. **Alternative spike: existing RapidOCR C++/ONNX distribution or another local Windows engine.** RapidOCR source is Apache-2.0, its project describes Windows C++/ONNX use, and current model docs say model artifacts are derived from PaddleOCR; however the exact legacy English v3/v4 weights must be associated with their original URLs, license/attribution and hashes before inclusion. The Python wheel's presence does not count as a Dart-compatible runtime.

The user approved trying another existing local Windows engine if Tesseract fails license, quality or latency gates. Test one engine at a time, select one passing candidate, keep all model/DLL resources local, and do not download models at runtime. If no candidate can be distributed with clear terms and meet the fixed CER/latency and geometry tests, keep the OCR phase blocked and preserve the legacy assets until a reviewed engine choice exists.

## Primary References

- [RapidOCR project and license](https://github.com/RapidAI/RapidOCR)
- [RapidOCR install guide](https://github.com/RapidAI/RapidOCRDocs/blob/main/docs/install_usage/rapidocr/install.en.md) (documents migration away from the legacy `rapidocr_onnxruntime` package family and model bundling)
- [PaddleOCR upstream license](https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE)
- [Tesseract installation documentation](https://github.com/tesseract-ocr/tessdoc/blob/main/Installation.md) (Apache-2.0, Windows options and box-capable output)
- [Tesseract Windows installation section](https://github.com/tesseract-ocr/tessdoc/blob/main/Installation.md#L320-L326)
- [Tesseract `tessdata_fast` README/license](https://github.com/tesseract-ocr/tessdata_fast/blob/main/README.md)
- [Tesseract `tessdata_fast` license file](https://github.com/tesseract-ocr/tessdata_fast/blob/main/LICENSE)
