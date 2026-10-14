import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_service.dart';

class GoogleMeetAuthService extends ChangeNotifier {
  static final GoogleMeetAuthService _instance =
      GoogleMeetAuthService._internal();
  factory GoogleMeetAuthService() => _instance;
  GoogleMeetAuthService._internal();

  static const _kIsSignedIn = 'auth_is_signed_in';
  static const _kToken = 'auth_token';
  static const _kName = 'auth_name';
  static const _kEmail = 'auth_email';
  static const _kPhone = 'auth_phone';
  static const _kAvatar = 'auth_avatar';
  static const _kMethod = 'auth_method';

  bool _isSignedIn = false;
  String? _teacherName;
  String? _teacherEmail;
  String? _teacherPhone;
  String? _teacherAvatar;
  String? _accessToken;
  String? _authMethod;
  String? _googleSessionId;
  String? _googleEmail;

  bool get isSignedIn => _isSignedIn;
  String? get teacherName => _teacherName;
  String? get teacherEmail => _teacherEmail;
  String? get teacherPhone => _teacherPhone;
  String? get teacherAvatar => _teacherAvatar;
  String? get accessToken => _accessToken;
  String? get authMethod => _authMethod;
  String? get googleSessionId => _googleSessionId;
  String? get googleEmail => _googleEmail;

  /// Khởi tạo và nạp phiên đăng nhập đã lưu trong LocalStorage / SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSignedIn = prefs.getBool(_kIsSignedIn) ?? false;
      if (_isSignedIn) {
        _accessToken = prefs.getString(_kToken);
        _teacherName = prefs.getString(_kName);
        _teacherEmail = prefs.getString(_kEmail);
        _teacherPhone = prefs.getString(_kPhone);
        _teacherAvatar = prefs.getString(_kAvatar);
        _authMethod = prefs.getString(_kMethod);
        // Older builds persisted a WebView marker as if it were an OAuth token.
        if (_authMethod == 'google') {
          _accessToken = null;
          await prefs.remove(_kToken);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GoogleMeetAuthService] init error: $e');
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsSignedIn, _isSignedIn);
      if (_accessToken != null) {
        await prefs.setString(_kToken, _accessToken!);
      } else {
        await prefs.remove(_kToken);
      }
      if (_teacherName != null) await prefs.setString(_kName, _teacherName!);
      if (_teacherEmail != null) await prefs.setString(_kEmail, _teacherEmail!);
      if (_teacherPhone != null) await prefs.setString(_kPhone, _teacherPhone!);
      if (_teacherAvatar != null) {
        await prefs.setString(_kAvatar, _teacherAvatar!);
      }
      if (_authMethod != null) await prefs.setString(_kMethod, _authMethod!);
    } catch (e) {
      debugPrint('[GoogleMeetAuthService] persist error: $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kIsSignedIn);
      await prefs.remove(_kToken);
      await prefs.remove(_kName);
      await prefs.remove(_kEmail);
      await prefs.remove(_kPhone);
      await prefs.remove(_kAvatar);
      await prefs.remove(_kMethod);
    } catch (e) {
      debugPrint('[GoogleMeetAuthService] clear error: $e');
    }
  }

  /// Receives only an opaque local grant handle, never a Google token.
  void connectGoogleSession({
    required String sessionId,
    String? name,
    String? email,
    String? avatar,
  }) {
    disconnectGoogle();
    _googleSessionId = sessionId;
    _googleEmail = email;
    // Linking Meet does not overwrite a password/OTP account's identity/token.
    if (!_isSignedIn || _authMethod == 'google' || _authMethod == 'demo') {
      _isSignedIn = true;
      _accessToken = null;
      _teacherName = name ?? 'Giáo viên';
      _teacherEmail = email;
      _teacherAvatar = avatar;
      _teacherPhone = null;
      _authMethod = 'google';
    }
    _persistSession();
    notifyListeners();
  }

  /// Đăng nhập bằng phiên OTP (Số điện thoại / Email)
  void signInWithOtpSession({
    required String token,
    required String name,
    String? email,
    String? phone,
  }) {
    disconnectGoogle();
    _isSignedIn = true;
    _accessToken = token;
    _teacherName = name;
    _teacherEmail = email;
    _teacherPhone = phone;
    _teacherAvatar = null;
    _authMethod = phone != null ? 'otp_phone' : 'otp_email';
    _persistSession();
    notifyListeners();
  }

  bool get isGoogleAuthenticated => _googleSessionId != null;

  /// Mô phỏng đăng nhập nhanh cho giáo viên (Quick Sign-in)
  void quickSignIn({String? email, String? name}) {
    signInWithDemoTeacher(
      email: email ?? 'giaovien.hocluc@edu.vn',
      name: name ?? 'Thầy Giáo (Giáo viên giảng dạy)',
    );
  }

  /// Đăng nhập tài khoản demo / chấm thi một chạm
  void signInWithDemoTeacher({
    String email = 'toan.nguyen@fpt.edu.vn',
    String name = 'Thầy Khắc Toàn',
  }) {
    disconnectGoogle();
    _isSignedIn = true;
    _accessToken = 'demo_google_access_token_hocluc_station';
    _teacherName = name;
    _teacherEmail = email;
    _teacherAvatar = null;
    _teacherPhone = null;
    _authMethod = 'demo';
    _persistSession();
    notifyListeners();
  }

  void disconnectGoogle() {
    final sessionId = _googleSessionId;
    _googleSessionId = null;
    _googleEmail = null;
    if (sessionId != null) _releaseGoogleSession(sessionId);
    notifyListeners();
  }

  Future<void> _releaseGoogleSession(String sessionId) async {
    final local = LocalService();
    try {
      await local.post(
        'google/oauth/disconnect',
        data: {'sessionId': sessionId},
      );
    } catch (_) {
    } finally {
      local.client.close();
    }
  }

  /// Đăng xuất tài khoản
  void signOut() {
    disconnectGoogle();
    _isSignedIn = false;
    _accessToken = null;
    _teacherName = null;
    _teacherEmail = null;
    _teacherPhone = null;
    _teacherAvatar = null;
    _authMethod = null;
    _clearPersistedSession();
    notifyListeners();
  }
}
