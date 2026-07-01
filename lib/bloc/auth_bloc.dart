import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/chat_repository.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

class _AuthUserChanged extends AuthEvent {
  final User? user;
  const _AuthUserChanged(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthLoginRequested extends AuthEvent {
  final String email, password;
  const AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthSignupRequested extends AuthEvent {
  final String email, password;
  const AuthSignupRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}


enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final bool submitting;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.submitting = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool clearUser = false,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, user, submitting, error];
}


class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ChatRepository repo;
  StreamSubscription<User?>? _authSub;

  AuthBloc({required this.repo}) : super(const AuthState()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<_AuthUserChanged>(_onUserChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignupRequested>(_onSignupRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onSubscriptionRequested(
      AuthSubscriptionRequested event, Emitter<AuthState> emit) async {
    await _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      add(_AuthUserChanged(user));
    });
  }

  void _onUserChanged(_AuthUserChanged event, Emitter<AuthState> emit) {
    emit(state.copyWith(
      status: event.user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: event.user,
      clearUser: event.user == null,
      submitting: false,
    ));
  }

  Future<void> _onLoginRequested(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: event.email.trim(), password: event.password.trim());
      await repo.saveUser(c.user!);
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  Future<void> _onSignupRequested(
      AuthSignupRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: event.email.trim(), password: event.password.trim());
      await repo.saveUser(c.user!);
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(
      AuthGoogleSignInRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final c = await FirebaseAuth.instance.signInWithPopup(provider);
      await repo.saveUser(c.user!);
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await repo.setPresence(online: false);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}