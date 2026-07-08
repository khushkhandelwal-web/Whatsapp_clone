import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  final String email, password;
  const AuthLoginRequested({required this.email, required this.password});
  @override List<Object?> get props => [email, password];
}

class AuthSignupRequested extends AuthEvent {
  final String email, password;
  const AuthSignupRequested({required this.email, required this.password});
  @override List<Object?> get props => [email, password];
}

class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}