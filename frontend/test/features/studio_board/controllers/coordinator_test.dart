import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/services/controllers/studio_workspace_coordinator.dart';

void main() {
  group('StudioWorkspaceCoordinator Tests', () {
    late StudioWorkspaceCoordinator coordinator;

    setUp(() {
      coordinator = StudioWorkspaceCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('Initializes with default sub-controllers and metadata', () {
      expect(coordinator.canvas, isNotNull);
      expect(coordinator.pdf, isNotNull);
      expect(coordinator.audio, isNotNull);
      expect(coordinator.plugins, isNotNull);
      expect(coordinator.title, 'Không gian giảng dạy');
      expect(coordinator.subject, 'Chung');
      expect(coordinator.dirty, isFalse);
    });

    test('Mediator routes plugin sticker insert to canvas', () {
      final cardData = {
        'id': 'stk-plugin-1',
        'type': 'vocab_sticker',
        'rect': [0.1, 0.1, 0.3, 0.3],
        'rawText': 'Vocabulary word',
        'tokens': [
          {'text': 'Vocabulary'}
        ],
        'issues': <String>[],
      };
      coordinator.insertPluginCard(cardData);
      expect(coordinator.canvas.currentStickers.length, 1);
      expect(coordinator.canvas.currentStickers.first.id, 'stk-plugin-1');
      expect(coordinator.dirty, isTrue);
    });

    test('Export and restore lesson JSON works through coordinator', () {
      coordinator.title = 'Bài giảng Vật lý 10';
      coordinator.subject = 'Vật lý';
      final stroke = BoardStroke(
        const Color(0xffffffff),
        3.0,
        const [Offset(0.1, 0.1), Offset(0.2, 0.2)],
      );
      coordinator.canvas.addStroke(stroke);

      final exported = coordinator.exportLessonJson();
      expect(exported['title'], 'Bài giảng Vật lý 10');
      expect(exported['subject'], 'Vật lý');
      expect((exported['pages'] as List).isNotEmpty, isTrue);

      // Create a fresh coordinator and restore
      final newCoordinator = StudioWorkspaceCoordinator();
      newCoordinator.restoreFromJson(exported);
      expect(newCoordinator.title, 'Bài giảng Vật lý 10');
      expect(newCoordinator.subject, 'Vật lý');
      expect(newCoordinator.canvas.pages.first.length, 1);
      newCoordinator.dispose();
    });

    test('Safe disposal cascades to sub-controllers without errors', () {
      final testCoord = StudioWorkspaceCoordinator();
      expect(() => testCoord.dispose(), returnsNormally);
    });
  });
}

