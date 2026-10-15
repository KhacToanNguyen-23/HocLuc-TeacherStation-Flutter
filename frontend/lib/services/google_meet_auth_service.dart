import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleMeetAuthService extends ChangeNotifier {
  static final GoogleMeetAuthService _instance = GoogleMeetAuthService._internal();
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

  bool get isSignedIn => _isSignedIn;
  String? get teacherName => _teacherName;
  String? get teacherEmail => _teacherEmail;
  String? get teacherPhone => _teacherPhone;
  String? get teacherAvatar => _teacherAvatar;
  String? get accessToken => _accessToken;
  String? get authMethod => _authMethod;

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
      if (_teacherAvatar != null) await prefs.setString(_kAvatar, _teacherAvatar!);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_connection_email', email);
    await prefs.remove(_kToken);
    await prefs.remove(_kAvatar);
    await prefs.remove(_kPhone);
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
      _isSignedIn && (_authMethod == 'google' || _authMethod == 'google_oauth' || _authMethod == 'demo');

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
  void signOut() {
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
