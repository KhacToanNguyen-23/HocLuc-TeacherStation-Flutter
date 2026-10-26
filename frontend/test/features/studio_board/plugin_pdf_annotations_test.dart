import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BoardStroke path(String group, String item) => BoardStroke(
    Colors.blue,
    3,
    const [Offset(.1, .2), Offset(.3, .2), Offset(.2, .4)],
    isHollow: true,
    annotationOwnerId: 'test.plugin',
    annotationGroupId: group,
    annotationItemId: item,
  );

  test(
    'plugin paths replace their group across pages and preserve other groups',
    () {
      final studio = StudioState()..pdfTotalPages = 2;
      void toggle(int page, String group, String item) =>
          studio.togglePluginPdfAnnotation(
            pageNumber: page,
            annotation: path(group, item),
            persist: true,
            affectedPages: [1, 2],
          );
      toggle(1, 'first-owner/question', 'A');
      toggle(1, 'other-owner/question', 'A');
      toggle(2, 'first-owner/question', 'B');
      expect(
        studio.pdfAnnotationsForPage(1).single.annotationGroupId,
        'other-owner/question',
      );
      expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'B');
      studio.undo();
      expect(studio.pdfAnnotationsForPage(2), isEmpty);
      expect(
        studio.pdfAnnotationsForPage(1).map((s) => s.annotationGroupId).toSet(),
        {'first-owner/question', 'other-owner/question'},
      );
      studio.redo();
      expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'B');
    },
  );

  test('merging progressive groups rekeys paths and undo history', () {
    final studio = StudioState()..pdfTotalPages = 2;
    studio.togglePluginPdfAnnotation(
      pageNumber: 1,
      annotation: path('canonical', 'A'),
      persist: true,
      affectedPages: [1],
    );
    studio.togglePluginPdfAnnotation(
      pageNumber: 2,
      annotation: path('provisional', 'C'),
      persist: true,
      affectedPages: [2],
    );
    studio.migratePdfAnnotationGroup(
      'provisional',
      'canonical',
      affectedPages: [1, 2],
    );
    expect(studio.pdfAnnotationsForPage(1), isEmpty);
    expect(
      studio.pdfAnnotationsForPage(2).single.annotationGroupId,
      'canonical',
    );
    studio.undo();
    expect(studio.pdfAnnotationsForPage(2), isEmpty);
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'A');
    studio.redo();
    expect(studio.pdfAnnotationsForPage(1), isEmpty);
    expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'C');
  });

  test('temporary plugin paths leave saved data intact and support undo', () {
    final studio = StudioState();
    studio.togglePluginPdfAnnotation(
      pageNumber: 1,
      annotation: path('group', 'A'),
      persist: true,
      affectedPages: [1],
    );
    final saved = studio.pdfAnnotations[1]!.single.toJson();
    studio.dirty = false;
    studio.togglePluginPdfAnnotation(
      pageNumber: 1,
      annotation: path('group', 'B'),
      persist: false,
      affectedPages: [1],
    );
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'B');
    expect(studio.pdfAnnotations[1]!.single.toJson(), saved);
    expect(studio.dirty, isFalse);
    studio.undo();
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'A');
    studio.redo();
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'B');
    studio.togglePluginPdfAnnotation(
      pageNumber: 1,
      annotation: path('group', 'B'),
      persist: false,
      affectedPages: [1],
    );
    expect(studio.pdfAnnotationsForPage(1), isEmpty);
    expect(studio.pdfAnnotations[1]!.single.toJson(), saved);
  });

  test('canonical newer choice restores the provisional choice on undo', () {
    final studio = StudioState()..pdfTotalPages = 2;
    studio.togglePluginPdfAnnotation(
      pageNumber: 2,
      annotation: path('provisional', 'C'),
      persist: true,
      affectedPages: [2],
    );
    studio.togglePluginPdfAnnotation(
      pageNumber: 1,
      annotation: path('canonical', 'A'),
      persist: true,
      affectedPages: [1],
    );
    studio.migratePdfAnnotationGroup(
      'provisional',
      'canonical',
      affectedPages: [1, 2],
    );
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'A');
    expect(studio.pdfAnnotationsForPage(2), isEmpty);
    studio.undo();
    expect(studio.pdfAnnotationsForPage(1), isEmpty);
    expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'C');
    studio.redo();
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'A');
    expect(studio.pdfAnnotationsForPage(2), isEmpty);
  });

  test(
    'merged interleaved temporary and saved choices retain their history',
    () {
      final studio = StudioState()..pdfTotalPages = 2;
      studio.togglePluginPdfAnnotation(
        pageNumber: 1,
        annotation: path('canonical', 'A'),
        persist: true,
        affectedPages: [1],
      );
      studio.togglePluginPdfAnnotation(
        pageNumber: 2,
        annotation: path('provisional', 'C'),
        persist: false,
        affectedPages: [2],
      );
      studio.togglePluginPdfAnnotation(
        pageNumber: 1,
        annotation: path('canonical', 'B'),
        persist: true,
        affectedPages: [1],
      );
      studio.migratePdfAnnotationGroup(
        'provisional',
        'canonical',
        affectedPages: [1, 2],
      );
      studio.undo();
      expect(studio.pdfAnnotationsForPage(1), isEmpty);
      expect(studio.pdfAnnotations[1]!.single.annotationItemId, 'A');
      expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'C');
      studio.undo();
      expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'A');
      expect(studio.pdfAnnotationsForPage(2), isEmpty);
    },
  );

  test('merging while a choice is undone preserves redo order', () {
    final studio = StudioState()..pdfTotalPages = 2;
    studio.togglePluginPdfAnnotation(
      pageNumber: 2,
      annotation: path('provisional', 'C'),
      persist: true,
      affectedPages: [2],
    );
    studio.togglePluginPdfAnnotation(
      pageNumber: 1,
      annotation: path('canonical', 'A'),
      persist: true,
      affectedPages: [1],
    );
    studio.undo();
    studio.migratePdfAnnotationGroup(
      'provisional',
      'canonical',
      affectedPages: [1, 2],
    );
    expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'C');
    studio.redo();
    expect(studio.pdfAnnotationsForPage(1).single.annotationItemId, 'A');
    expect(studio.pdfAnnotationsForPage(2), isEmpty);
    studio.undo();
    expect(studio.pdfAnnotationsForPage(2).single.annotationItemId, 'C');
  });
}
