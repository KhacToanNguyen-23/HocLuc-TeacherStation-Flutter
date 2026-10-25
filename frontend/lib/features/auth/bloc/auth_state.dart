import 'package:flutter/foundation.dart';

/// Base class for all authentication states.
@immutable
sealed class AuthState {
  const AuthState();
}

/// Initial state when the authentication subsystem hasn't initialized yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Emitted during ongoing async auth actions (logging in, refreshing session).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Emitted when a teacher is securely authenticated.
class Authenticated extends AuthState {
  const Authenticated({
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.authMethod,
    this.accessToken,
  });

  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? authMethod;
  final String? accessToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Authenticated &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          avatar == other.avatar &&
          authMethod == other.authMethod &&
          accessToken == other.accessToken;

  @override
  int get hashCode =>
      Object.hash(name, email, phone, avatar, authMethod, accessToken);

  @override
  String toString() => 'Authenticated(email: $email, name: $name)';
}

/// Emitted when the session is unauthenticated or signed out.
class Unauthenticated extends AuthState {
  const Unauthenticated({this.lastEmail});

  final String? lastEmail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unauthenticated &&
          runtimeType == other.runtimeType &&
          lastEmail == other.lastEmail;

  @override
  int get hashCode => lastEmail.hashCode;

  @override
  String toString() => 'Unauthenticated(lastEmail: $lastEmail)';
}

/// Emitted when authentication fails with a user-facing error message.
class AuthFailure extends AuthState {
  const AuthFailure({required this.message});

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'AuthFailure(message: $message)';
}
