import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/services/google_connection_flow.dart';
import 'package:teaching_companion/services/google_workspace_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final state in [
    'CONNECTED',
    'TEMPORARY_ERROR',
    'CONFIG_ERROR',
    'NOT_CONFIGURED',
  ]) {
    test(
      'saved connection $state does not launch another OAuth flow',
      () async {
        final paths = <String>[];
        final api = GoogleWorkspaceApi(
          email: 'teacher@example.com',
          client: MockClient((request) async {
            paths.add(request.url.path);
            return http.Response(
              jsonEncode(
                request.url.path.endsWith('bootstrap')
                    ? {'token': 'local'}
                    : {
                        'state': state,
                        'connected': state == 'CONNECTED',
                        'email': 'teacher@example.com',
                      },
              ),
              200,
            );
          }),
        );
        addTearDown(api.close);
        final result = GoogleConnectionFlow.connect(
          api,
          isActive: () => true,
          reuseExisting: true,
        );
        if (state == 'CONNECTED') {
          expect(await result, 'teacher@example.com');
        } else {
          await expectLater(result, throwsStateError);
        }
        expect(paths.any((p) => p.endsWith('/connect')), isFalse);
        expect(paths.any((p) => p.endsWith('/status')), isTrue);
      },
    );
  }
}
