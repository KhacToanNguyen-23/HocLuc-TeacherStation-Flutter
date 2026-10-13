import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleMeetAuthService extends ChangeNotifier {
  static const webviewSessionMarker = 'webview2_authenticated_google_session';
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
  static const _kSession = 'auth_app_session';
  static const _kTeacherId = 'auth_teacher_id';
  static const _kRole = 'auth_role';

  bool _isSignedIn = false;
  String? _teacherName;
  String? _teacherEmail;
  String? _teacherPhone;
  String? _teacherAvatar;
  String? _accessToken;
  String? _authMethod;
  String? _appSessionToken;
  String? _teacherId;
  String _role = 'TEACHER';
  int _profileRevision = 0;

  bool get isSignedIn => _isSignedIn;
  String? get teacherName => _teacherName;
  String? get teacherEmail => _teacherEmail;
  String? get teacherPhone => _teacherPhone;
  String? get teacherAvatar => _teacherAvatar;
  String? get accessToken => _accessToken;
  String? get authMethod => _authMethod;
  String? get appSessionToken => _appSessionToken;
  String? get teacherId => _teacherId;
  String get role => _role;
  int get profileRevision => _profileRevision;

  bool get hasLocalGoogleProfile =>
      _isSignedIn &&
      _authMethod == 'google' &&
      _accessToken == webviewSessionMarker &&
      _teacherEmail != null &&
      _teacherEmail!.isNotEmpty;

  /// Attach exam storage to the current develop-style login without changing it.
  Future<void> attachLocalExamSession({
    required String token,
    required String teacherId,
  }) async {
    _appSessionToken = token;
    _teacherId = teacherId;
    _role = 'TEACHER';
    await _persistSession();
    notifyListeners();
  }

  /// Khởi tạo và nạp phiên đăng nhập đã lưu trong LocalStorage / SharedPreferences
  Future<void> init() async {
    _profileRevision++;
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
        _appSessionToken = prefs.getString(_kSession);
        _teacherId = prefs.getString(_kTeacherId);
        _role = prefs.getString(_kRole) ?? 'TEACHER';
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
      if (_accessToken != null) await prefs.setString(_kToken, _accessToken!);
      if (_teacherName != null) await prefs.setString(_kName, _teacherName!);
      if (_teacherEmail != null) await prefs.setString(_kEmail, _teacherEmail!);
      if (_teacherPhone != null) await prefs.setString(_kPhone, _teacherPhone!);
      if (_teacherAvatar != null) {
        await prefs.setString(_kAvatar, _teacherAvatar!);
      }
      if (_authMethod != null) await prefs.setString(_kMethod, _authMethod!);
      if (_appSessionToken != null) {
        await prefs.setString(_kSession, _appSessionToken!);
      } else {
        await prefs.remove(_kSession);
      }
      if (_teacherId != null) await prefs.setString(_kTeacherId, _teacherId!);
      await prefs.setString(_kRole, _role);
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
      await prefs.remove(_kSession);
      await prefs.remove(_kTeacherId);
      await prefs.remove(_kRole);
    } catch (e) {
      debugPrint('[GoogleMeetAuthService] clear error: $e');
    }
  }

  /// Đăng nhập tài khoản Google (lưu token và thông tin giáo viên)
  void signInWithGoogleToken({
    required String accessToken,
    String? name,
    String? email,
    String? avatar,
    String? sessionToken,
    String? teacherId,
    String role = 'TEACHER',
  }) {
    _profileRevision++;
    _isSignedIn = true;
    _accessToken = accessToken;
    _teacherName = name ?? 'Giáo viên';
    _teacherEmail = email ?? 'teacher@gmail.com';
    _teacherAvatar = avatar;
    _teacherPhone = null;
    _authMethod = 'google';
    _appSessionToken = sessionToken;
    _teacherId = teacherId;
    _role = role;
    _persistSession();
    notifyListeners();
  }

  /// Đăng nhập bằng phiên OTP (Số điện thoại / Email)
  void signInWithOtpSession({
    required String token,
    required String name,
    String? email,
    String? phone,
    String? teacherId,
    String role = 'TEACHER',
  }) {
    _profileRevision++;
    _isSignedIn = true;
    _accessToken = token;
    _teacherName = name;
    _teacherEmail = email;
    _teacherPhone = phone;
    _teacherAvatar = null;
    _authMethod = phone != null ? 'otp_phone' : 'otp_email';
    _appSessionToken = token;
    _teacherId = teacherId;
    _role = role;
    _persistSession();
    notifyListeners();
  }

  bool get isGoogleAuthenticated =>
      _isSignedIn && (_authMethod == 'google' || _authMethod == 'demo');

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
    _profileRevision++;
    _isSignedIn = true;
    _accessToken = 'demo_google_access_token_hocluc_station';
    _teacherName = name;
    _teacherEmail = email;
    _teacherAvatar = null;
    _teacherPhone = null;
    _authMethod = 'demo';
    _appSessionToken = null;
    _teacherId = null;
    _role = 'TEACHER';
    _persistSession();
    notifyListeners();
  }

  /// Liên kết tài khoản Google cho phiên đang đăng nhập bằng phương thức khác
  void linkGoogleAccount({
    required String email,
    required String name,
    String? token,
  }) {
    _profileRevision++;
    _teacherEmail = email;
    _teacherName = name;
    if (token != null) _accessToken = token;
    _authMethod = 'google';
    _persistSession();
    notifyListeners();
  }

  /// Đăng xuất tài khoản
  void signOut() {
    _profileRevision++;
    _isSignedIn = false;
    _accessToken = null;
    _teacherName = null;
    _teacherEmail = null;
    _teacherPhone = null;
    _teacherAvatar = null;
    _authMethod = null;
    _appSessionToken = null;
    _teacherId = null;
    _role = 'TEACHER';
    _clearPersistedSession();
    notifyListeners();
  }
}
