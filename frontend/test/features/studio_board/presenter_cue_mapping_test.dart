import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

void main() {
  test(
    'activity follows multiple pages and PDF notes do not follow hidden PDF',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.setPdfFile('range.pdf', Uint8List.fromList([6, 7]));
      state.setPdfTotalPages(8);
      state.viewportMode = StudioViewportMode.fullPdf;
      state.setPdfPage(3);
      final target3 = state.activeTeacherTarget;
      state.setPdfPage(4);
      final target4 = state.activeTeacherTarget;
      state.preparationDocument = {
        'sections': [
          {
            'id': 'range',
            'teacherNotes': 'Explain this topic',
            'presentationTarget': target3,
            'presentationTargets': [target3, target4],
          },
        ],
      };
      expect(state.presentActivity('range'), isTrue);
      expect(state.pdfPage, 3);
      state.setTeacherNote('Page three');
      state.setPdfPage(4);
      expect(state.teacherActivityNote, 'Explain this topic');
      expect(state.teacherNoteText, '');
      state.setPdfPage(5);
      expect(state.teacherActivityNote, '');
      state.viewportMode = StudioViewportMode.fullBoard;
      expect(state.activeTeacherTarget['kind'], 'board');
      expect(state.teacherNoteText, '');
    },
  );

  test(
    'activities sharing a page retain separate cues; pin survives navigation',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.ensurePageIds();
      final target = {'kind': 'board', 'pageId': state.pageIds[0]};
      state.preparationDocument = {
        'revision': 0,
        'sections': [
          {
            'id': 'a',
            'title': 'A',
            'teacherNotes': 'Activity A',
            'presentationTarget': target,
          },
          {
            'id': 'b',
            'title': 'B',
            'teacherNotes': 'Activity B',
            'presentationTarget': target,
          },
        ],
        'teacherCues': [
          {'id': 'global', 'text': 'Global', 'locator': target},
        ],
      };
      expect(state.teacherActivityNote, '');
      expect(state.teacherNoteText, 'Global');
      expect(state.presentActivity('a'), isTrue);
      state.setTeacherNote('Page A');
      state.pinTeacherNotes();
      expect(state.presentActivity('b'), isTrue);
      expect(state.teacherActivityNote, 'Activity A');
      expect(state.teacherNoteText, 'Page A');
      state.followTeacherNotes();
      expect(state.teacherActivityNote, 'Activity B');
      expect(state.teacherNoteText, 'Global');
      state.setTeacherNote('Page B');
      state.presentActivity('a');
      expect(state.teacherNoteText, 'Page A');
      expect(state.preparationDocument!['teacherCues'], hasLength(3));
    },
  );

  test(
    'live teacher context survives save/reopen without preparation envelope',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.restoreFromJson({
        'title': 'Renamed server lesson',
        'teacherPreparation': {
          'revision': 3,
          'teacherCues': [],
          'sections': [],
        },
        'pages': [[]],
      });
      expect(state.title, 'Renamed server lesson');
      expect(state.exportLessonJson()['teacherPreparation'], isNotNull);
      expect(state.exportLessonJson().containsKey('preparation'), isFalse);
    },
  );

  test(
    'save acknowledgement preserves edits during save and advances revisions',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.preparationDocument = {'revision': 7};
      state.setTeacherNote('before');
      final snapshot = state.exportLessonJson();
      final savedFingerprint = state.boardSaveFingerprint(snapshot);
      state.setTeacherNote('during');
      snapshot['boardRevision'] = 12;
      final unchanged =
          state.boardSaveFingerprint(state.exportLessonJson()) ==
          savedFingerprint;
      expect(unchanged, isFalse);
      state.acknowledgeBoardSave(snapshot, unchanged: unchanged);
      expect(state.teacherNoteText, 'during');
      expect(state.teacherCuesEdited, isTrue);
      expect(state.preparationDocument!['revision'], 8);
      expect(state.boardRevision, 12);
    },
  );

  test(
    'legacy page notes migrate and stay attached through reorder/delete',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.restoreFromJson({
        'pages': [[], [], []],
        'pageNotes': ['A', 'B', 'C'],
      });
      final ids = List.of(state.pageIds);
      state.setPage(1);
      state.pinTeacherNotes();
      state.movePage(1, 0);
      expect(state.pageIds, [ids[1], ids[0], ids[2]]);
      expect(state.teacherNoteText, 'B');
      state.deletePage(1);
      expect(state.teacherNoteText, 'B');
      final restored = StudioState();
      addTearDown(restored.dispose);
      restored.restoreFromJson(state.exportLessonJson());
      expect(restored.pageIds, state.pageIds);
      expect(restored.pageNotes, ['B', 'C']);
    },
  );

  test(
    'two PDF page threes never share cues; pin and follow use document identity',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.setPdfFile('a.pdf', Uint8List.fromList([1, 2]));
      state.viewportMode = StudioViewportMode.fullPdf;
      state.setPdfTotalPages(5);
      state.setPdfPage(3);
      state.setTeacherNote('Private A3');
      state.pinTeacherNotes();
      state.setPdfFile('b.pdf', Uint8List.fromList([3, 4]));
      state.setPdfTotalPages(5);
      state.setPdfPage(3);
      expect(state.teacherNoteText, 'Private A3');
      state.followTeacherNotes();
      expect(state.teacherNoteText, '');
      state.setTeacherNote('Private B3');
      state.setPdfFile('a.pdf', Uint8List.fromList([1, 2]));
      state.viewportMode = StudioViewportMode.fullPdf;
      state.setPdfPage(3);
      expect(state.teacherNoteText, 'Private A3');
      state.setPdfFile('a.pdf', Uint8List.fromList([9, 9]));
      state.setPdfTotalPages(5);
      state.setPdfPage(3);
      expect(state.teacherNoteText, '');
    },
  );

  test(
    'linked activity follows actual page and transport excludes preparation envelope',
    () {
      final state = StudioState();
      addTearDown(state.dispose);
      state.addPage();
      state.preparationDocument = {
        'revision': 4,
        'sections': [
          {
            'id': 'activity',
            'teacherNotes': 'Ask first',
            'presentationTarget': {'kind': 'board', 'pageId': state.pageIds[1]},
          },
        ],
      };
      state.setPage(0);
      expect(state.teacherNoteText, '');
      state.setPage(1);
      expect(state.teacherActivityNote, 'Ask first');
      expect(state.teacherNoteText, '');
      state.setTeacherNote('Private override');
      final json = state.exportLessonJson();
      expect(json.containsKey('preparation'), isFalse);
      expect(json['expectedPreparationRevision'], 4);
      expect(json['teacherCueUpdates'], hasLength(1));
    },
  );
}
