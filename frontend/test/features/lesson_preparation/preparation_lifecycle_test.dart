import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_controller.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_draft_store.dart';

class _Api extends PreparationApi {
  Completer<dynamic>? pendingLoad, pendingSave;
  Object? loadError, saveError;
  int reads = 0, revision = 1;
  @override
  Future<dynamic> get(String path) async {
    if (path == 'capabilities') return {};
    if (path.endsWith('/jobs') || path.endsWith('/recordings')) return [];
    reads++;
    if (pendingLoad != null) return pendingLoad!.future;
    if (loadError != null) throw loadError!;
    return {
      'title': 'Lesson',
      'revision': revision,
      'ownerId': 'teacher-A',
      'sections': [],
      'scenes': [],
    };
  }

  @override
  Future<dynamic> put(String path, Object body) async {
    if (pendingSave != null) return pendingSave!.future;
    if (saveError != null) throw saveError!;
    return {
      ...Map<String, dynamic>.from((body as Map)['document'] as Map),
      'revision': ++revision,
    };
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('recovery copies are isolated by backend, owner and plan', () async {
    final a = PreparationDraftStore('server-a', 'teacher-a', 'p');
    await a.write({'title': 'Private answer'});
    expect(
      await PreparationDraftStore('server-a', 'teacher-b', 'p').read(),
      isNull,
    );
    expect(
      await PreparationDraftStore('server-b', 'teacher-a', 'p').read(),
      isNull,
    );
    expect(
      await PreparationDraftStore('server-a', 'teacher-a', 'q').read(),
      isNull,
    );
    expect((await a.read())!['title'], 'Private answer');
  });
  PreparationController controller(_Api api) =>
      PreparationController(planId: 'p', api: api, title: 'Draft', subject: '');
  test('account switch during load rejects the old response', () async {
    final api = _Api()..pendingLoad = Completer<dynamic>();
    final c = controller(api);
    final load = c.load();
    api.session.auth.identity.linkGoogleAccount(
      email: 'new@example.test',
      name: 'New',
    );
    api.pendingLoad!.complete({'title': 'Old private lesson', 'revision': 1});
    await load;
    expect(c.loaded, isFalse);
    expect(c.document.title, 'Draft');
    expect(c.authRequired, isTrue);
    c.dispose();
    api.session.auth.identity.signOut();
  });
  test(
    'account switch hides the editor and preserves only the original owner draft',
    () async {
      final api = _Api();
      final c = controller(api);
      await c.load();
      c.change((d) => d.data['title'] = 'Private A notes');
      api.session.auth.identity.linkGoogleAccount(
        email: 'other@example.test',
        name: 'Other',
      );
      expect(c.loaded, isFalse);
      expect(c.authRequired, isTrue);
      expect(c.hasLocalDraft, isFalse);
      await c.discardLocalDraft();
      final old = await PreparationDraftStore(
        api.base,
        'teacher-A',
        'p',
      ).read();
      expect(old!['title'], 'Private A notes');
      c.dispose();
      api.session.auth.identity.signOut();
    },
  );
  test(
    'edits during save recover with the acknowledged base revision',
    () async {
      final api = _Api();
      final c = controller(api);
      await c.load();
      c.change((d) => d.data['title'] = 'First');
      api.pendingSave = Completer<dynamic>();
      final save = c.save();
      c.change((d) => d.data['title'] = 'New unsent edit');
      api.pendingSave!.complete({'revision': 2});
      await save;
      final draft = await PreparationDraftStore(
        api.base,
        'teacher-A',
        'p',
      ).read();
      expect(draft!['revision'], 2);
      expect(draft['title'], 'New unsent edit');
      expect(c.dirty, isTrue);
      c.dispose();
    },
  );
  test(
    'initial auth failure never looks saved and cannot open board',
    () async {
      final api = _Api()
        ..loadError = PreparationFailure('Sign in required', 401);
      final c = controller(api);
      await c.load();
      expect(c.loaded, isFalse);
      expect(c.statusLabel, isNot(contains('Đã lưu')));
      var opened = false;
      expect(
        await c.openBoard(() async {
          opened = true;
        }),
        isFalse,
      );
      expect(opened, isFalse);
      c.dispose();
    },
  );
  test(
    'twenty clean board return cycles reconcile without fake edits',
    () async {
      final api = _Api();
      final c = controller(api);
      await c.load();
      for (var i = 0; i < 20; i++) {
        expect(await c.openBoard(() async {}), isTrue);
        expect(c.dirty, isFalse);
        expect(c.loaded, isTrue);
      }
      expect(api.reads, 21);
      c.dispose();
    },
  );
  test(
    'failed save retains original actionable error and local recovery',
    () async {
      final api = _Api()
        ..saveError = PreparationFailure('Connection unavailable', 503);
      final c = controller(api);
      await c.load();
      c.change((d) => d.data['title'] = 'Unsent teaching notes');
      expect(
        await c.openBoard(() async {
          fail('must not open');
        }),
        isFalse,
      );
      expect(c.error, contains('Connection unavailable'));
      expect(c.dirty, isTrue);
      expect(c.hasLocalDraft, isTrue);
      final restored = controller(api);
      await restored.load();
      expect(restored.hasLocalDraft, isTrue);
      await restored.recoverLocalDraft();
      expect(restored.document.title, 'Unsent teaching notes');
      expect(restored.dirty, isTrue);
      c.dispose();
      restored.dispose();
    },
  );
}
