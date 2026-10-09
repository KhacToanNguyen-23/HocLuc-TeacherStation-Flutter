# Phase 03: High-Performance PDF Engine (pdfrx + Per-page Annotations)

**Objective:** Integrate `pdfrx` for PDF rendering, enable dual import (FilePicker + Drag & Drop), and map freehand annotation strokes per PDF page.

---

## Tasks

1. **Add Dependencies:**
   - Add `pdfrx: ^1.1.8`, `file_picker: ^8.1.7`, `desktop_drop: ^0.5.0` to `app/pubspec.yaml`.
   - Run `flutter pub get`.
2. **Build `PdfStage` Widget:**
   - Create `app/lib/widgets/pdf_stage.dart`.
   - Embed `PdfViewer` with smooth pan/zoom and page navigation controls.
   - Implement DropTarget via `desktop_drop` to accept dragged `.pdf` files.
   - Add "Mở tệp PDF" button with `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'])`.
3. **Per-Page Annotation Mapping:**
   - In `StudioState`, add `Map<int, List<BoardStroke>> pdfAnnotations = {}`.
   - Overlay a transparent `StrokeCanvas` directly on top of each PDF page.
   - When the teacher navigates to page $N$, the canvas binds to `pdfAnnotations[N] ??= []`.
   - Ensure strokes stay fixed relative to the page during zooming/panning.

---

## Files Affected
- `app/pubspec.yaml`
- `app/lib/models/studio_state.dart`
- `app/lib/widgets/pdf_stage.dart` (new)

---

## Acceptance Criteria
- [ ] User can pick or drop a PDF file and view it clearly.
- [ ] Annotating on page 1, switching to page 2 (clean slate), and returning to page 1 retains page 1's annotations.
- [ ] Zooming and scrolling PDF does not displace annotation coordinates.
