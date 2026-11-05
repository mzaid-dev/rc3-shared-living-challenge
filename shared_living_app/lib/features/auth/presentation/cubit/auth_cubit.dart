import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit({required this.authRepository}) : super(const AuthInitial());

  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.me();
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(const Unauthenticated());
      }
    } catch (_) {
      emit(const Unauthenticated());
    }
  }

  Future<void> login(String email, String password) async {
    emit(const AuthLoading());
    try {
      await authRepository.login(email, password);
      final user = await authRepository.me();
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(const AuthError(
          code: 'AUTH_FAILED',
          message: 'Unable to retrieve profile after login.',
        ));
      }
    } on AppFailure catch (f) {
      emit(AuthError(code: f.code, message: f.message));
    } catch (e) {
      emit(AuthError(code: 'LOGIN_ERROR', message: e.toString()));
    }
  }

  Future<void> logout() async {
    emit(const AuthLoading());
    try {
      await authRepository.logout();
    } finally {
      emit(const Unauthenticated(message: 'Signed out successfully.'));
    }
  }
}
