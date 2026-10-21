import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models/preparation_document.dart';
import 'preparation_api.dart';
import 'preparation_draft_store.dart';
import '../../exams/services/exam_api.dart';

class PreparationController extends ChangeNotifier {
  PreparationController({
    required this.planId,
    required this.api,
    required String title,
    required String subject,
  }) : document = PreparationDocument.empty(title, subject) {
    api.session.auth.addListener(_onIdentityChanged);
  }
  final String planId;
  final PreparationApi api;
  PreparationDocument document;
  PreparationMap capabilities = {};
  PreparationMap? activeRecording;
  List<PreparationMap> pendingRecordings = [];
  String? error;
  bool loading = true, dirty = false, saving = false, conflict = false;
  bool loaded = false, authRequired = false, hasLocalDraft = false;
  bool localOnly = false;
  String? recoveryError;
  PreparationDraftStore? _draftStore;
  int? _identityRevision;
  Future<void> _draftWork = Future.value();
  String get statusLabel {
    if (loading) return 'Đang mở bài…';
    if (localOnly) return 'Bản nháp trên máy — chưa đồng bộ';
    if (authRequired) return 'Cần xác thực phiên';
    if (!loaded) return 'Chưa mở được bài';
    if (conflict) return 'Có xung đột phiên bản';
    if (saving) return 'Đang lưu…';
    if (dirty) return hasLocalDraft ? 'Đã giữ nháp trên máy' : 'Chưa lưu';
    return 'Đã lưu trên máy chủ';
  }

  bool _disposed = false;
  int _editVersion = 0;
  Timer? _autosave, _poll;
  List<PreparationMap> jobs = [];
  Future<void>? _pendingSave;
  String get path => 'plannings/$planId';
  void emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (dirty) {
      error =
          'Bài đang có thay đổi. Hãy lưu hoặc giữ bản phục hồi trước khi tải lại.';
      emit();
      return;
    }
    loading = true;
    final identityAtLoad = api.session.auth.profileRevision;
    error = null;
    emit();
    try {
      final value = Map<String, dynamic>.from(await api.get(path) as Map);
      if (identityAtLoad != api.session.auth.profileRevision) {
        throw PreparationFailure(
          'Phiên giáo viên đã đổi trong khi mở bài. Hãy mở lại bài với tài khoản hiện tại.',
          401,
        );
      }
      document = PreparationDocument.fromJson(
        value['document'] is Map
            ? Map<String, dynamic>.from(value['document'] as Map)
            : value,
      );
      loaded = true;
      localOnly = false;
      authRequired = false;
      _identityRevision = api.session.auth.profileRevision;
      final owner =
          document.data['ownerId']?.toString() ?? api.session.auth.teacherId;
      if (owner != null && owner.isNotEmpty) {
        _draftStore = PreparationDraftStore(api.base, owner, planId);
        hasLocalDraft = await _draftStore!.read() != null;
      }
      dirty = false;
      conflict = false;
      try {
        capabilities = Map<String, dynamic>.from(
          await api.get('capabilities') as Map,
        );
      } catch (e) {
        capabilities = {'message': e.toString()};
      }
      await refreshJobs();
      await refreshRecordings();
      _poll ??= Timer.periodic(
        const Duration(seconds: 3),
        (_) => refreshJobs(),
      );
    } catch (e) {
      loaded = false;
      authRequired = _isAuthError(e);
      error = _message(e);
      // A previously verified identity may recover only its own local copy.
      await api.session.auth.restore();
      final owner = api.session.auth.teacherId;
      if (owner != null && api.session.auth.appSessionToken != null) {
        _identityRevision = api.session.auth.profileRevision;
        _draftStore = PreparationDraftStore(api.base, owner, planId);
        hasLocalDraft = await _draftStore!.read() != null;
      }
    }
    loading = false;
    emit();
  }

  void change(void Function(PreparationDocument) update) {
    if (!loaded || loading || _identityChanged) {
      error = 'Chưa mở được bài với phiên hiện tại. Hãy kết nối và tải lại.';
      emit();
      return;
    }
    update(document);
    _editVersion++;
    dirty = true;
    error = null;
    _keepRecovery();
    _autosave?.cancel();
    if (!conflict) {
      _autosave = Timer(const Duration(milliseconds: 900), () => save());
    }
    emit();
  }

  Future<void> save() async {
    _autosave?.cancel();
    if (_pendingSave != null) {
      await _pendingSave;
      if (dirty && !conflict) return save();
      return;
    }
    if (!loaded || _identityChanged) {
      if (_identityChanged) {
        authRequired = true;
        error =
            'Phiên giáo viên đã thay đổi. Bản đang sửa được giữ cho tài khoản ban đầu.';
      }
      emit();
      return;
    }
    if (!dirty || conflict || loading) return;
    final task = _save();
    _pendingSave = task;
    try {
      await task;
    } finally {
      _pendingSave = null;
    }
  }

  Future<void> _save() async {
    saving = true;
    emit();
    final edit = _editVersion;
    try {
      final result = Map<String, dynamic>.from(
        await api.put(path, {
              'expectedRevision': document.revision,
              'document': document.copy().data,
            })
            as Map,
      );
      final saved = result['document'] is Map
          ? Map<String, dynamic>.from(result['document'] as Map)
          : result;
      if (_identityChanged) {
        throw PreparationFailure(
          'Phiên giáo viên đã thay đổi khi lưu bài.',
          401,
        );
      }
      document.data['revision'] = saved['revision'] ?? document.revision + 1;
      if (_editVersion == edit) dirty = false;
      if (!dirty) {
        final recoveryStore = _draftStore;
        _draftWork = _draftWork
            .then((_) async {
              if (_editVersion != edit || dirty) return;
              await recoveryStore?.clear();
              if (identical(recoveryStore, _draftStore) &&
                  _editVersion == edit &&
                  !dirty) {
                hasLocalDraft = false;
              }
            })
            .catchError((Object e) {
              recoveryError = '$e';
            });
        await _draftWork;
      } else {
        // ACK advanced the base revision even if newer edits remain unsent.
        _keepRecovery();
        await _draftWork;
      }
      error = null;
      authRequired = false;
      localOnly = false;
    } catch (e) {
      authRequired = _isAuthError(e);
      conflict = e is PreparationFailure && e.status == 409;
      error = conflict
          ? 'Bài đã đổi ở nơi khác. Bản đang sửa vẫn giữ tại đây; sao chép trước khi tải bản máy chủ.'
          : _message(e);
      _keepRecovery();
      await _draftWork;
    }
    saving = false;
    emit();
  }

  Future<void> refreshJobs() async {
    if (_disposed) return;
    try {
      final value = await api.get('$path/jobs');
      jobs = preparationRows(value is Map ? value['jobs'] : value);
      emit();
    } catch (_) {
      /* Poll failures do not discard the editor. */
    }
  }

  Future<void> refreshRecordings() async {
    if (_disposed) return;
    try {
      final value = await api.get('$path/recordings');
      pendingRecordings = preparationRows(value);
      final currentId = activeRecording?['id'];
      activeRecording =
          pendingRecordings.where((r) => r['id'] == currentId).firstOrNull ??
          pendingRecordings.firstOrNull;
      emit();
    } catch (_) {
      // A failed discovery never discards a recording still held in this session.
    }
  }

  Future<void> run(String kind, {PreparationMap options = const {}}) async {
    await save();
    if (!loaded || dirty || conflict || authRequired) {
      throw PreparationFailure(
        error ?? 'Cần lưu bài trước khi xử lý.',
        authRequired ? 401 : 409,
      );
    }
    await api.post('$path/jobs', {
      'kind': kind,
      'revision': document.revision,
      ...options,
    });
    await refreshJobs();
  }

  Future<void> jobAction(String id, String action) async {
    await api.post('jobs/$id/$action');
    await refreshJobs();
  }

  bool get _identityChanged =>
      _identityRevision != null &&
      _identityRevision != api.session.auth.profileRevision;
  bool _isAuthError(Object e) =>
      (e is PreparationFailure && e.status == 401) ||
      (e is ExamApiException && e.status == 401);

  String _message(Object e) => e is StateError ? e.message : '$e';

  void _onIdentityChanged() {
    if (!_identityChanged) return;
    if (dirty) _keepRecovery();
    _autosave?.cancel();
    _poll?.cancel();
    _poll = null;
    loaded = false;
    dirty = false;
    localOnly = false;
    authRequired = true;
    hasLocalDraft = false;
    _draftStore = null;
    error =
        'Phiên giáo viên đã thay đổi. Hãy mở lại bài bằng tài khoản sở hữu.';
    emit();
  }

  void _keepRecovery() {
    final store = _draftStore;
    if (store == null) return;
    final snapshot = document.copy().data;
    _draftWork = _draftWork
        .then((_) async {
          await store.write(snapshot);
          if (identical(store, _draftStore)) {
            hasLocalDraft = true;
            recoveryError = null;
            emit();
          }
        })
        .catchError((Object e) {
          recoveryError = '$e';
          emit();
        });
  }

  Future<void> recoverLocalDraft() async {
    if (_identityChanged || _draftStore == null) return;
    final recoveryStore = _draftStore!;
    final identityAtRecovery = api.session.auth.profileRevision;
    final edit = _editVersion;
    bool stillCurrent() =>
        !_disposed &&
        identityAtRecovery == api.session.auth.profileRevision &&
        identical(recoveryStore, _draftStore) &&
        edit == _editVersion;
    await _draftWork;
    if (!stillCurrent()) return;
    final draft = await recoveryStore.read();
    if (draft == null || !stillCurrent()) return;
    final remoteRevision = document.revision;
    final hadRemote = loaded && !localOnly;
    document = PreparationDocument.fromJson(draft);
    conflict = hadRemote && document.revision != remoteRevision;
    localOnly = !hadRemote;
    loaded = true;
    dirty = true;
    _editVersion++;
    error = conflict
        ? 'Nháp dùng phiên bản cũ. Sao chép nội dung cần giữ hoặc so sánh trước khi tải lại.'
        : null;
    emit();
  }

  Future<void> discardLocalDraft() async {
    final edit = _editVersion;
    final recoveryStore = _draftStore;
    _draftWork = _draftWork
        .then((_) async {
          if (edit != _editVersion) return;
          await recoveryStore?.clear();
          if (edit == _editVersion && identical(recoveryStore, _draftStore)) {
            hasLocalDraft = false;
          }
        })
        .catchError((Object e) {
          recoveryError = '$e';
        });
    await _draftWork;
    emit();
  }

  Future<PreparationDocument?> remoteCopy() async {
    if (_identityChanged) return null;
    final identityAtLoad = api.session.auth.profileRevision;
    try {
      final value = Map<String, dynamic>.from(await api.get(path) as Map);
      if (_identityChanged ||
          identityAtLoad != api.session.auth.profileRevision) {
        return null;
      }
      return PreparationDocument.fromJson(
        value['document'] is Map
            ? Map<String, dynamic>.from(value['document'] as Map)
            : value,
      );
    } catch (e) {
      error = _message(e);
      emit();
      return null;
    }
  }

  /// Call only after an explicit discard/compare choice in the UI.
  Future<bool> reloadDiscardingChanges() async {
    final remote = await remoteCopy();
    if (remote == null) return false;
    document = remote;
    dirty = false;
    conflict = false;
    loaded = true;
    authRequired = false;
    localOnly = false;
    error = null;
    // Recovery remains available until the user explicitly discards it.
    emit();
    return true;
  }

  /// Studio owns its save/discard/cancel dialog. Refresh only after returning.
  Future<bool> openBoard(Future<void> Function() open) async {
    if (!loaded || loading || _identityChanged) {
      error ??= 'Chưa mở được bài. Hãy tải lại hoặc khôi phục phiên đăng nhập.';
      emit();
      return false;
    }
    await save();
    if (dirty || conflict || authRequired) return false;
    try {
      await open();
      if (_disposed) return true;
      if (!dirty) await load();
      return loaded;
    } catch (e) {
      error = _message(e);
      emit();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    api.session.auth.removeListener(_onIdentityChanged);
    _autosave?.cancel();
    _poll?.cancel();
    api.dispose();
    super.dispose();
  }
}
