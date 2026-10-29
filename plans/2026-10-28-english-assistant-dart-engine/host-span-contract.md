# Generic Plugin Text and PDF Span Contract (Draft v1)

This is an architecture contract for analysis plugins. Core transports selected text and generic spans; it does not know English labels, CEFR or grammar rules. OCR and image sources are out of scope. The `selectionToken` ties every request and result to one document generation, page and selected region.

## Request

One `POST /api/analyze` accepts text only:

```json
{
  "schemaVersion": 1,
  "requestId": "opaque-request-id",
  "selectionToken": "opaque-current-selection-token",
  "source": {
    "kind": "text",
    "text": "A smart student reads.",
    "offsetUnit": "unicodeCodePoint"
  }
}
```

Reject image, crop and unknown source kinds. The host retains page identity and the character boxes produced by ordinary PDF text extraction. If a selected region has no usable text, the host tells the teacher that scanned/image-only regions are unsupported and points to “Nhập văn bản”. It does not rasterize the page or send image data to the plugin.

## Response

The response echoes `requestId`, `selectionToken`, source kind and a typed analysis status. It carries supported analysis results and generic spans:

```json
{
  "schemaVersion": 1,
  "requestId": "opaque-request-id",
  "selectionToken": "opaque-current-selection-token",
  "sourceKind": "text",
  "status": "complete",
  "analysis": {},
  "spans": [
    {
      "start": 2,
      "end": 7,
      "offsetUnit": "unicodeCodePoint",
      "style": {"id": "plugin-defined-style", "metadata": {}}
    }
  ],
  "diagnostics": []
}
```

Annotation styles are opaque plugin metadata passed through the generic renderer. The host maps text spans to the character boxes returned by the PDF text layer.

## Validation and Errors

- Plugin spans use Unicode code-point offsets. Dart `String` indexes are UTF-16 code units; the plugin converts at one defined boundary and tests supplementary characters and combining sequences.
- Host rejects stale `selectionToken`, wrong document/page generation, negative/reversed/out-of-range spans and malformed results. Invalid results cannot mutate PDF annotations.
- The request schema accepts text only; image and crop payloads are rejected before analysis.
- Bridge permission names/capabilities and payload schema stay subject-agnostic. No plugin ID, language category or analyzer logic is added to Core.

## Frozen Offset Fixtures

Fixture metadata is stored in `host-span-fixtures.json`. Cases cover ASCII words, a supplementary character before the selected span, a combining sequence and repeated word occurrences.
