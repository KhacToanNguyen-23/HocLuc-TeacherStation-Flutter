import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/google_connection_flow.dart';
import 'package:teaching_companion/services/google_workspace_api.dart';

class _LoginApi extends GoogleWorkspaceApi {
  _LoginApi(this.failures) : super(email: 'remembered@example.com');
  final List<String> failures;
  final requests = <Map<String, dynamic>>[];
  int polls = 0;

  @override
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
    bool post = false,
    bool retryLocalSession = true,
  }) async {
    requests.add({'path': path, ...?body});
    if (path == 'status') {
      return {'connected': true, 'email': email};
    }
    if (path == 'connect') {
      return {
        'authorizationUrl': 'https://accounts.google.com/test',
        'state': 'state',
        'pollToken': 'proof',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      };
    }
    if (polls < failures.length) {
      throw GoogleWorkspaceFailure(failures[polls++], 'test failure');
    }
    return {'status': 'COMPLETE', 'email': 'selected@example.com'};
  }
}

void main() {
  test(
    'login verifies selected account even when a saved grant exists',
    () async {
      final api = _LoginApi([]);
      addTearDown(api.close);
      final opened = <String>[];
      final email = await GoogleConnectionFlow.connect(
        api,
        isActive: () => true,
        openBrowser: (url) async {
          opened.add(url);
        },
      );
      expect(email, 'selected@example.com');
      expect(opened, hasLength(1));
      expect(api.requests.map((r) => r['path']), ['connect', 'poll']);
      expect(api.requests.first['forceConsent'], isFalse);
    },
  );

  test('missing saved refresh token requests consent once', () async {
    final api = _LoginApi(['REFRESH_MISSING']);
    addTearDown(api.close);
    final email = await GoogleConnectionFlow.connect(
      api,
      isActive: () => true,
      openBrowser: (_) async {},
    );
    expect(email, 'selected@example.com');
    expect(
      api.requests
          .where((r) => r['path'] == 'connect')
          .map((r) => r['forceConsent']),
      [false, true],
    );
  });

  for (final code in ['OAUTH_CANCELLED', 'GOOGLE_NETWORK']) {
    test('$code does not reopen consent', () async {
      final api = _LoginApi([code]);
      addTearDown(api.close);
      await expectLater(
        GoogleConnectionFlow.connect(
          api,
          isActive: () => true,
          openBrowser: (_) async {},
        ),
        throwsA(isA<GoogleWorkspaceFailure>()),
      );
      expect(api.requests.where((r) => r['path'] == 'connect'), hasLength(1));
    });
  }

  test('failed consent repair does not loop', () async {
    final api = _LoginApi(['REFRESH_MISSING', 'REFRESH_MISSING']);
    addTearDown(api.close);
    await expectLater(
      GoogleConnectionFlow.connect(
        api,
        isActive: () => true,
        openBrowser: (_) async {},
      ),
      throwsA(isA<GoogleWorkspaceFailure>()),
    );
    expect(api.requests.where((r) => r['path'] == 'connect'), hasLength(2));
  });
}
