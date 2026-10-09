import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';

void main() {
  test('StudioState per-page PDF annotations isolation', () {
    final state = StudioState();
    state.setPdfFile('test.pdf', Uint8List(0));
    state.setPdfTotalPages(5);

    expect(state.pdfPage, equals(1));
    expect(state.currentPdfStrokes.isEmpty, isTrue);

    // Annotate on page 1
    state.startStroke(const Offset(0.2, 0.2), target: state.currentPdfStrokes);
    state.extendStroke(const Offset(0.3, 0.3), target: state.currentPdfStrokes);
    expect(state.currentPdfStrokes.length, equals(1));
    expect(state.currentPdfStrokes.first.points.length, equals(2));

    // Switch to page 2 (clean slate)
    state.setPdfPage(2);
    expect(state.pdfPage, equals(2));
    expect(state.currentPdfStrokes.isEmpty, isTrue);

    // Annotate on page 2
    state.startStroke(const Offset(0.5, 0.5), target: state.currentPdfStrokes);
    expect(state.currentPdfStrokes.length, equals(1));

    // Return to page 1 (retains annotations)
    state.setPdfPage(1);
    expect(state.currentPdfStrokes.length, equals(1));
    expect(
      state.currentPdfStrokes.first.points.first,
      equals(const Offset(0.2, 0.2)),
    );

    // Clear annotations for page 1
    state.clearPdfPage();
    expect(state.currentPdfStrokes.isEmpty, isTrue);

    // Page 2 still has its annotation
    state.setPdfPage(2);
    expect(state.currentPdfStrokes.length, equals(1));
  });
}
