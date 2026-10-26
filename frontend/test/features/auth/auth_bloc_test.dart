import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/auth/bloc/auth_cubit.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';

void main() {
  late GoogleMeetAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    authService = GoogleMeetAuthService();
    authService.signOut();
  });

  group('AuthCubit & AuthState Unit Tests', () {
    test('initial state is AuthInitial when not signed in', () {
      final cubit = AuthCubit(authService: authService);
      expect(cubit.state, isA<AuthInitial>());
      cubit.close();
    });

    test(
      'initial state is Authenticated when authService is already signed in',
      () {
        authService.signInWithDemoTeacher(
          name: 'Thầy Tuấn',
          email: 'tuan@edu.vn',
        );
        final cubit = AuthCubit(authService: authService);

        expect(cubit.state, isA<Authenticated>());
        final authState = cubit.state as Authenticated;
        expect(authState.name, 'Thầy Tuấn');
        expect(authState.email, 'tuan@edu.vn');
        cubit.close();
      },
    );

    test('checkAuthStatus emits Unauthenticated when signed out', () async {
      final cubit = AuthCubit(authService: authService);
      await cubit.checkAuthStatus();

      expect(cubit.state, isA<Unauthenticated>());
      cubit.close();
    });

    test('signInWithGoogle updates state to Authenticated', () async {
      final cubit = AuthCubit(authService: authService);
      await cubit.signInWithGoogle('giaovien.toan@gmail.com');

      expect(cubit.state, isA<Authenticated>());
      final authState = cubit.state as Authenticated;
      expect(authState.email, 'giaovien.toan@gmail.com');
      expect(authService.isSignedIn, isTrue);
      cubit.close();
    });

    test(
      'signInWithOtp updates state to Authenticated with phone credentials',
      () async {
        final cubit = AuthCubit(authService: authService);
        cubit.signInWithOtp(
          token: 'otp-jwt-sample',
          name: 'Cô Mai',
          phone: '+84909123456',
        );

        expect(cubit.state, isA<Authenticated>());
        final authState = cubit.state as Authenticated;
        expect(authState.name, 'Cô Mai');
        expect(authState.phone, '+84909123456');
        expect(authState.accessToken, 'otp-jwt-sample');
        cubit.close();
      },
    );

    test('signInDemo authenticates default teacher credentials', () async {
      final cubit = AuthCubit(authService: authService);
      cubit.signInDemo();

      expect(cubit.state, isA<Authenticated>());
      final authState = cubit.state as Authenticated;
      expect(authState.name, 'Thầy Khắc Toàn');
      expect(authState.email, 'toan.nguyen@fpt.edu.vn');
      cubit.close();
    });

    test(
      'signOut transitions state from Authenticated to Unauthenticated',
      () async {
        final cubit = AuthCubit(authService: authService);
        cubit.signInDemo();
        expect(cubit.state, isA<Authenticated>());

        await cubit.signOut();
        expect(cubit.state, isA<Unauthenticated>());
        expect(authService.isSignedIn, isFalse);
        cubit.close();
      },
    );

    test(
      'automatically syncs with external changes to GoogleMeetAuthService',
      () async {
        final cubit = AuthCubit(authService: authService);
        expect(cubit.state, isA<AuthInitial>());

        // External service triggered change
        authService.signInWithDemoTeacher(
          name: 'Thầy Hùng',
          email: 'hung@hocluc.vn',
        );
        expect(cubit.state, isA<Authenticated>());
        expect((cubit.state as Authenticated).name, 'Thầy Hùng');

        authService.signOut();
        expect(cubit.state, isA<Unauthenticated>());
        cubit.close();
      },
    );

    test(
      'does not throw or emit after cubit is closed during async operation',
      () async {
        final cubit = AuthCubit(authService: authService);
        final future = cubit.checkAuthStatus();
        await cubit.close();
        await future;
        // Verification that no unhandled StateError is thrown after close
        expect(cubit.isClosed, isTrue);
      },
    );

    test('captures service exceptions as AuthFailure', () async {
      final cubit = AuthCubit(authService: _ThrowingAuthService());
      await cubit.checkAuthStatus();
      expect(cubit.state, isA<AuthFailure>());
      expect(
        (cubit.state as AuthFailure).message,
        contains('Không thể kiểm tra'),
      );
      cubit.close();
    });
  });

  group('BlocBuilder Integration in Widget Tree', () {
    testWidgets('renders Authenticated and Unauthenticated views dynamically', (
      tester,
    ) async {
      final cubit = AuthCubit(authService: authService);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: Scaffold(
              body: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  return switch (state) {
                    Authenticated(:final name) => Text('Welcome $name'),
                    Unauthenticated() => const Text('Please Login'),
                    _ => const CircularProgressIndicator(),
                  };
                },
              ),
            ),
          ),
        ),
      );

      // Initially unauthenticated / initial
      await cubit.checkAuthStatus();
      await tester.pumpAndSettle();
      expect(find.text('Please Login'), findsOneWidget);

      // Trigger sign in
      cubit.signInDemo(name: 'Thầy Nam');
      await tester.pumpAndSettle();
      expect(find.text('Welcome Thầy Nam'), findsOneWidget);

      // Trigger sign out
      await cubit.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Please Login'), findsOneWidget);

      cubit.close();
    });
  });
}

class _ThrowingAuthService extends ChangeNotifier
    implements GoogleMeetAuthService {
  @override
  bool get isSignedIn => false;

  @override
  Future<String> lastGoogleConnectionEmail() async {
    throw StateError('Simulated disk read error');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
