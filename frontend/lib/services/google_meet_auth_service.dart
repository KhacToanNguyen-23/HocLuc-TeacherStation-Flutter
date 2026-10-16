import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _pendingPersistence = Future<void>.value();

  bool _isSignedIn = false;
  String? _teacherName;
  String? _teacherEmail;
  String? _teacherPhone;
  String? _teacherAvatar;
  String? _accessToken;
  String? _authMethod;

  bool get isSignedIn => _isSignedIn;
  String? get teacherName => _teacherName;
  String? get teacherEmail => _teacherEmail;
  String? get teacherPhone => _teacherPhone;
  String? get teacherAvatar => _teacherAvatar;
  String? get accessToken => _accessToken;
  String? get authMethod => _authMethod;

  /// Restore the local HocLuc session without contacting Google. Provider
  /// token expiry is handled by the Workspace backend, not by this login gate.
  Future<void> init() async {
    await _pendingPersistence;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSignedIn = prefs.getBool(_kIsSignedIn) ?? false;
      _accessToken = _isSignedIn ? prefs.getString(_kToken) : null;
      _teacherName = _isSignedIn ? prefs.getString(_kName) : null;
      _teacherEmail = _isSignedIn ? prefs.getString(_kEmail) : null;
      _teacherPhone = _isSignedIn ? prefs.getString(_kPhone) : null;
      _teacherAvatar = _isSignedIn ? prefs.getString(_kAvatar) : null;
      _authMethod = _isSignedIn ? prefs.getString(_kMethod) : null;
      if (_isSignedIn &&
          _authMethod == 'google_oauth' &&
          (_teacherEmail == null || _teacherEmail!.trim().isEmpty)) {
        await signOut();
        return;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[GoogleMeetAuthService] init error: $e');
    }
  }

  Future<void> _queuePersistence(Future<void> Function() operation) {
    _pendingPersistence = _pendingPersistence
        .then((_) => operation())
        .catchError((Object e) {
          debugPrint('[GoogleMeetAuthService] persist error: $e');
        });
    return _pendingPersistence;
  }

  Future<void> _persistSession() {
    // Capture now: a later logout/account switch must not change this write.
    final signedIn = _isSignedIn;
    final values = <String, String?>{
      _kToken: _accessToken,
      _kName: _teacherName,
      _kEmail: _teacherEmail,
      _kPhone: _teacherPhone,
      _kAvatar: _teacherAvatar,
      _kMethod: _authMethod,
    };
    return _queuePersistence(() async {
      final prefs = await SharedPreferences.getInstance();
      // Commit the signed-in marker last so a partial write is not restored.
      await prefs.setBool(_kIsSignedIn, false);
      for (final entry in values.entries) {
        if (entry.value == null) {
          await prefs.remove(entry.key);
        } else {
          await prefs.setString(entry.key, entry.value!);
        }
      }
      if (values[_kMethod] == 'google_oauth') {
        await prefs.setString('google_connection_email', values[_kEmail]!);
      }
      await prefs.setBool(_kIsSignedIn, signedIn);
    });
  }

  Future<void> _clearPersistedSession() => _queuePersistence(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsSignedIn, false);
    for (final key in [_kToken, _kName, _kEmail, _kPhone, _kAvatar, _kMethod]) {
      await prefs.remove(key);
    }
    // Keep the account hint and API grant; logout is not Google revocation.
  });

  /// Đăng nhập tài khoản Google (lưu token và thông tin giáo viên)
  Future<String> lastGoogleConnectionEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_connection_email') ?? '';
  }

  Future<void> signInWithGoogleConnection(String email) async {
    _isSignedIn = true;
    _teacherEmail = email;
    _teacherName = email.split('@').first;
    _teacherPhone = null;
    _teacherAvatar = null;
    _accessToken = null;
    _authMethod = 'google_oauth';
    await _persistSession();
    notifyListeners();
  }

  void signInWithGoogleToken({
    required String accessToken,
    String? name,
    String? email,
    String? avatar,
  }) {
    _isSignedIn = true;
    _accessToken = accessToken;
    _teacherName = name ?? 'Giáo viên';
    _teacherEmail = email ?? 'teacher@gmail.com';
    _teacherAvatar = avatar;
    _teacherPhone = null;
    _authMethod = 'google';
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

  bool get isGoogleAuthenticated =>
      _isSignedIn &&
      (_authMethod == 'google' ||
          _authMethod == 'google_oauth' ||
          _authMethod == 'demo');

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

  /// Liên kết tài khoản Google cho phiên đang đăng nhập bằng phương thức khác
  void linkGoogleAccount({
    required String email,
    required String name,
    String? token,
  }) {
    _teacherEmail = email;
    _teacherName = name;
    if (token != null) _accessToken = token;
    _authMethod = 'google';
    _persistSession();
    notifyListeners();
  }

  /// Đăng xuất tài khoản
  Future<void> signOut() {
    _isSignedIn = false;
    _accessToken = null;
    _teacherName = null;
    _teacherEmail = null;
    _teacherPhone = null;
    _teacherAvatar = null;
    _authMethod = null;
    final cleared = _clearPersistedSession();
    notifyListeners();
    return cleared;
  }
}
