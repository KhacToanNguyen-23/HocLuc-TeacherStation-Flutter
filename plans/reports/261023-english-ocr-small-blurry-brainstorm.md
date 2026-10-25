# Brainstorm: Improve paragraph OCR for small or blurry text

**Date:** 2026-10-23

## Ideas Explored

- **Single upscale pass:** Enlarge small captures before the current RapidOCR call. It is simple and fast, but one scale and one filter may not suit both clean and blurry text.
- **Adaptive multi-pass OCR:** Keep the original image and try a small number of enlarged, contrast-adjusted variants. Compare recognized candidates using OCR confidence and conservative text checks. This best matches the user's preference for automatic recovery.
- **OCR confidence plus lexical correction:** Preserve token confidence through reconstruction, then use the existing English word list only for clear, high-confidence corrections. Keep uncertain tokens unchanged.
- **Manual review and correction UI:** Let teachers inspect or edit recognized text. This is a useful later fallback, but was not the requested first improvement.
- **Replace the OCR engine:** Evaluate a different OCR package or model. It could help specific fonts, but increases model, package, and offline deployment risk before the current pipeline is measured.
- **Image preview and tuning controls:** Expose processed images or enhancement settings. This adds interaction and complexity where the user prefers automatic processing.

## User's Direction

The user wants to improve OCR for small or blurry text. They prefer automatic image enlargement/enhancement followed by another OCR attempt. They want dictionary-based correction only when confidence is sufficient; uncertain text should not be guessed. There are no real failing images yet, so evaluate using a generated benchmark from known text.

## Existing Capabilities

- `plugins/english_assistant/manifest.json` already declares a paragraph region snip action.
- `plugins/english_assistant/engine/service.py` accepts a captured image at `/analyze-svo`, inverts dark images, applies a 2x2 erosion, and invokes the bundled English RapidOCR model. It also reconstructs words from image projections and applies `_correct_ocr_tokens` using an English vocabulary and fuzzy matching.
- OCR confidence is not carried through the custom word reconstruction. Some current correction rules can guess short or fuzzy matches, so confidence-aware candidate selection and conservative correction are central to the proposal.
- Existing tests cover grammar and DGNL APIs, but not image preprocessing or OCR accuracy.

## Narrowed Direction

Preserve the current OCR engine and API. Add a bounded automatic retry path for small or low-confidence captures: evaluate the original plus a limited number of enlarged/contrast-adjusted variants, retain OCR confidence during reconstruction, and select a candidate using confidence with conservative lexical checks. Apply dictionary correction only when the match is unambiguous and confidence passes a documented threshold; otherwise preserve the recognized token. Keep paragraph reading order and current downstream analysis behavior.

## Open Questions

- There are no real classroom captures initially; use generated low-resolution and blur variants for reproducible measurement, then add anonymized real samples when available.
- The user confirmed the benchmark target during planning: at least 10% relative median CER reduction on degraded samples, with no more than a 2 percentage-point median CER regression on clean samples. The exact pass count and confidence threshold should be selected after measuring the baseline.

## Risks

- Upscaling cannot recover detail absent from the source and may increase latency without improving recognition.
- Aggressive thresholding or morphology can merge small letters, erase punctuation, or distort character spacing.
- OCR confidence is not a calibrated probability; combining it with dictionary matches must avoid changing valid uncommon words.
