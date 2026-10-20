import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';

/// Exam ownership follows the shared login without replacing Meet's OAuth state.
class ExamSessionService extends ChangeNotifier {
  static final _instance = ExamSessionService._();
  factory ExamSessionService() => _instance;
  ExamSessionService._() {
    identity.addListener(_syncIdentity);
    _syncIdentity();
  }
  final identity = GoogleMeetAuthService();
  static const webviewSessionMarker = 'webview2_authenticated_google_session';
  String? _fingerprint;
  String? _token, _teacherId;
  String _role = 'TEACHER';
  int _revision = 0;
  bool _restored = false;
  String? providerAccessToken;

  String get _currentFingerprint =>
      '${identity.isSignedIn}|${identity.authMethod}|${identity.teacherEmail}|${identity.accessToken}';
  void _syncIdentity() {
    if (_fingerprint == _currentFingerprint) return;
    _fingerprint = _currentFingerprint;
    _revision++;
    _token = null;
    _teacherId = null;
    _role = 'TEACHER';
    providerAccessToken = null;
    _restored = false;
    if (!identity.isSignedIn) unawaited(_clearPersistedSession(_revision));
    notifyListeners();
  }

  Future<void> _clearPersistedSession(int revision) async {
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    await prefs.remove('auth_exam_profile');
    await prefs.remove('auth_app_session');
    await prefs.remove('auth_teacher_id');
    await prefs.remove('auth_role');
  }

  bool get isSignedIn => identity.isSignedIn;
  String? get teacherEmail => identity.teacherEmail;
  String? get teacherName => identity.teacherName;
  int get profileRevision => _revision;
  String? get teacherId => _teacherId;
  String get role => _role;
  bool get hasLocalGoogleProfile =>
      identity.isSignedIn &&
      identity.authMethod == 'google' &&
      (identity.teacherEmail?.isNotEmpty ?? false);
  String? get appSessionToken =>
      _token ??
      (identity.isSignedIn && (identity.authMethod?.startsWith('otp_') ?? false)
          ? identity.accessToken
          : null);

  Future<void> restore() async {
    if (_restored) return;
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    if (isSignedIn && prefs.getString('auth_exam_profile') == _fingerprint) {
      _token ??= prefs.getString('auth_app_session');
      _teacherId ??= prefs.getString('auth_teacher_id');
      _role = prefs.getString('auth_role') ?? 'TEACHER';
    }
    _restored = true;
  }

  Future<void> attachLocalExamSession({
    required String token,
    required String teacherId,
    String role = 'TEACHER',
  }) async {
    _token = token;
    _teacherId = teacherId;
    _role = role;
    _restored = true;
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    await prefs.setString('auth_exam_profile', _fingerprint!);
    await prefs.setString('auth_app_session', token);
    await prefs.setString('auth_teacher_id', teacherId);
    await prefs.setString('auth_role', role);
    notifyListeners();
  }
}

