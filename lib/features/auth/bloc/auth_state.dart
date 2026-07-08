import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final User?      user;
  final bool       submitting;
  final String?    error;

  const AuthState({
    this.status     = AuthStatus.unknown,
    this.user,
    this.submitting = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User?       user,
    bool        clearUser  = false,
    bool?       submitting,
    String?     error,
    bool        clearError = false,
  }) => AuthState(
    status:     status     ?? this.status,
    user:       clearUser  ? null : (user ?? this.user),
    submitting: submitting ?? this.submitting,
    error:      clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [status, user, submitting, error];
}