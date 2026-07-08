import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../data/repositories/auth_repository.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  StreamSubscription<User?>? _sub;

  AuthBloc({required AuthRepository repository})
      : _repo = repository,
        super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthSignupRequested>(_onSignup);
    on<AuthGoogleSignInRequested>(_onGoogle);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onStarted(
      AuthStarted _, Emitter<AuthState> emit) async {
    await _sub?.cancel();
    _sub = _repo.authStateChanges.listen((user) {
      emit(state.copyWith(
        status:     user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user:       user,
        clearUser:  user == null,
        submitting: false,
      ));
    });
  }

  Future<void> _onLogin(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await _repo.signInWithEmail(event.email, event.password);
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  Future<void> _onSignup(
      AuthSignupRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await _repo.signUpWithEmail(event.email, event.password);
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  Future<void> _onGoogle(
      AuthGoogleSignInRequested _, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await _repo.signInWithGoogle();
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  Future<void> _onLogout(
      AuthLogoutRequested _, Emitter<AuthState> emit) async {
    await _repo.signOut();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}