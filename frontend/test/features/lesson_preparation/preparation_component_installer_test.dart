import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_component_installer.dart';

class ComponentApi extends PreparationApi {
  String status = 'verifying';
  final posts = <String>[];
  @override
  Future<dynamic> get(String path) async => path == 'components/installations'
      ? [
          {'id': 'existing-install', 'status': status, 'progress': .5},
        ]
      : {
          'id': 'existing-install',
          'status': status,
          'progress': .5,
          'stage': 'Kiểm SHA-256',
        };
  @override
  Future<dynamic> post(String path, [Object? body]) async {
    posts.add(path);
    status = 'cancelled';
    return {'status': status};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'reopening installer resumes existing installation without repost and can cancel it',
    (tester) async {
      final api = ComponentApi();
      var installed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparationComponentInstaller(
              api: api,
              onInstalled: () async {
                installed++;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Hủy'), findsOneWidget);
      expect(api.posts, isEmpty);
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump();
      expect(api.posts, ['components/installations/existing-install/cancel']);
      expect(installed, 0);
      expect(find.text('Hủy'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
