import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'auth_state.dart';

export 'auth_state.dart';

/// Cubit managing the authentication state of the application.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({GoogleMeetAuthService? authService})
    : _authService = authService ?? GoogleMeetAuthService(),
      super(_resolveInitialState(authService ?? GoogleMeetAuthService())) {
    _authListener = () {
      if (!isClosed) {
        _syncWithService();
      }
    };
    _authService.addListener(_authListener);
  }

  final GoogleMeetAuthService _authService;
  late final void Function() _authListener;

  static AuthState _resolveInitialState(GoogleMeetAuthService service) {
    if (service.isSignedIn) {
      return Authenticated(
        name: service.teacherName ?? 'Giáo viên',
        email: service.teacherEmail ?? '',
        phone: service.teacherPhone,
        avatar: service.teacherAvatar,
        authMethod: service.authMethod,
        accessToken: service.accessToken,
      );
    }
    return const AuthInitial();
  }

  void _syncWithService() {
    if (isClosed) return;
    if (_authService.isSignedIn) {
      emit(
        Authenticated(
          name: _authService.teacherName ?? 'Giáo viên',
          email: _authService.teacherEmail ?? '',
          phone: _authService.teacherPhone,
          avatar: _authService.teacherAvatar,
          authMethod: _authService.authMethod,
          accessToken: _authService.accessToken,
        ),
      );
    } else if (state is! AuthLoading) {
      emit(const Unauthenticated());
    }
  }

  /// Checks the current authentication status from persisted session storage.
  Future<void> checkAuthStatus() async {
    if (isClosed) return;
    if (_authService.isSignedIn) {
      _syncWithService();
      return;
    }

    emit(const AuthLoading());
    try {
      final lastEmail = await _authService.lastGoogleConnectionEmail();
      if (isClosed) return;
      emit(Unauthenticated(lastEmail: lastEmail.isNotEmpty ? lastEmail : null));
    } catch (e) {
      if (isClosed) return;
      emit(AuthFailure(message: 'Không thể kiểm tra trạng thái đăng nhập: $e'));
    }
  }

  /// Signs in using a connected Google email address.
  Future<void> signInWithGoogle(String email) async {
    if (isClosed) return;
    emit(const AuthLoading());
    try {
      await _authService.signInWithGoogleConnection(email);
    } catch (e) {
      if (isClosed) return;
      emit(AuthFailure(message: 'Lỗi đăng nhập Google: $e'));
    }
  }

  /// Signs in using OTP credentials.
  void signInWithOtp({
    required String token,
    required String name,
    String? email,
    String? phone,
  }) {
    if (isClosed) return;
    emit(const AuthLoading());
    try {
      _authService.signInWithOtpSession(
        token: token,
        name: name,
        email: email,
        phone: phone,
      );
    } catch (e) {
      if (isClosed) return;
      emit(AuthFailure(message: 'Lỗi xác thực OTP: $e'));
    }
  }

  /// Signs in using Demo Teacher profile.
  void signInDemo({String? email, String? name}) {
    if (isClosed) return;
    emit(const AuthLoading());
    _authService.signInWithDemoTeacher(
      email: email ?? 'toan.nguyen@fpt.edu.vn',
      name: name ?? 'Thầy Khắc Toàn',
    );
  }

  /// Signs out of the current session.
  Future<void> signOut() async {
    if (isClosed) return;
    emit(const AuthLoading());
    try {
      _authService.signOut();
      final lastEmail = await _authService.lastGoogleConnectionEmail();
      if (isClosed) return;
      emit(Unauthenticated(lastEmail: lastEmail.isNotEmpty ? lastEmail : null));
    } catch (e) {
      if (isClosed) return;
      emit(AuthFailure(message: 'Lỗi đăng xuất: $e'));
    }
  }

  @override
  Future<void> close() {
    _authService.removeListener(_authListener);
    return super.close();
  }
}
