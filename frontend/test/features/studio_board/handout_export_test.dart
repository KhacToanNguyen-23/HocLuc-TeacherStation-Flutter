import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/save_classroom_dialog.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_speaker_notes_bar.dart';

void main() {
  group('Handout PDF Export (Slide kèm Ghi chú)', () {
    test(
      'generateHandoutPdfBytes creates a valid multi-page A4 Handout PDF document',
      () async {
        final studio = StudioState();
        studio.title = 'Bài giảng Vật lý 12 - Định luật Ohm';
        studio.subject = 'Vật lý';

        // Page 1: with strokes and notes
        studio.setPageNote(
          0,
          'Lưu ý: Nhấn mạnh công thức I = U / R. Hỏi học sinh đơn vị của điện trở.',
        );
        studio.addStroke(
          BoardStroke(const Color(0xFFEF4444), 3.0, [
            const Offset(0.1, 0.1),
            const Offset(0.5, 0.5),
          ]),
        );

        // Page 2: with rectangle and empty note (should generate student note lines)
        studio.addPage('Mạch điện nối tiếp và song song');
        studio.setPage(1);
        studio.setPageNote(1, '');
        studio.addStroke(
          BoardStroke(
            const Color(0xFF3B82F6),
            2.0,
            [],
            rect: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.4),
          ),
        );

        // Page 3: with single dot point and long multi-line notes
        studio.addPage('Bài tập áp dụng');
        studio.setPage(2);
        studio.setPageNote(
          2,
          '1. Đọc kỹ đề bài trước khi làm.\n'
          '2. Tính điện trở tương đương của toàn mạch.\n'
          '3. Áp dụng định luật Ohm cho từng nhánh để tìm cường độ dòng điện.',
        );
        studio.addStroke(
          BoardStroke(const Color(0xFF10B981), 4.0, [const Offset(0.5, 0.5)]),
        );

        final bytes = await PdfAnnotationExporter.generateHandoutPdfBytes(
          studio,
        );
        expect(bytes, isNotNull);
        expect(bytes.isNotEmpty, isTrue);

        // Verify the generated PDF can be read and inspected
        final doc = sf.PdfDocument(inputBytes: bytes);
        expect(doc.pages.count, 3);
        for (int i = 0; i < doc.pages.count; i++) {
          final p = doc.pages[i];
          expect(p.size.width, 595.0);
          expect(p.size.height, 842.0);
        }
        doc.dispose();
      },
    );

    testWidgets('SaveClassroomDialog renders Handout export option card', (
      tester,
    ) async {
      final studio = StudioState();
      studio.title = 'Tiết học thí nghiệm';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaveClassroomDialog(
              studio: studio,
              onSaveSlide: () async => true,
            ),
          ),
        ),
      );

      expect(find.text('Lưu bài giảng trong phòng học'), findsOneWidget);
      expect(find.text('Tài liệu Handout (Slide + Ghi chú)'), findsOneWidget);
      expect(find.text('Xuất Handout'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets(
      'StudioSpeakerNotesBar renders Handout export button when expanded',
      (tester) async {
        final studio = StudioState();
        studio.setPageNote(0, 'Nội dung nhắc bài');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StudioSpeakerNotesBar(studio: studio)),
          ),
        );

        // Expand the bar
        await tester.tap(find.textContaining('Ghi chú Trang 1/1'));
        await tester.pumpAndSettle();

        // Verify export button appears
        expect(
          find.byKey(const Key('btn_export_handout_notes')),
          findsOneWidget,
        );
        expect(find.text('Xuất Handout (Slide + Ghi chú)'), findsOneWidget);
      },
    );
  });
}

