import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/errors/app_failure.dart';
import 'package:shared_living_app/features/auth/data/mock_auth_repository.dart';
import 'package:shared_living_app/features/auth/data/token_storage.dart';
import 'package:shared_living_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:shared_living_app/features/auth/presentation/cubit/auth_state.dart';

void main() {
  late TokenStorage tokenStorage;
  late MockAuthRepository authRepository;

  setUp(() {
    tokenStorage = TokenStorage();
    authRepository = MockAuthRepository(tokenStorage: tokenStorage);
  });

  group('MockAuthRepository Tests', () {
    test('Successful login with demo password demo12345', () async {
      final tokens = await authRepository.login('ali@demo.pk', 'demo12345');
      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.refreshToken, isNotEmpty);

      final user = await authRepository.me();
      expect(user?.id, 'M01');
      expect(user?.name, 'Ali');
    });

    test('Invalid credentials throw INVALID_CREDENTIALS', () async {
      expect(
        () => authRepository.login('ali@demo.pk', 'wrong_pass'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
      );
      expect(
        () => authRepository.login('unknown@demo.pk', 'demo12345'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
      );
    });

    test('Refresh token rotation succeeds and detects reused token', () async {
      final initialTokens = await authRepository.login('ayesha@demo.pk', 'demo12345');
      final firstRefresh = initialTokens.refreshToken;

      // Rotate token
      final rotatedTokens = await authRepository.refresh(firstRefresh);
      expect(rotatedTokens.refreshToken, isNot(equals(firstRefresh)));

      // Reusing firstRefresh MUST throw REFRESH_REUSED per Rule 5 & 7
      expect(
        () => authRepository.refresh(firstRefresh),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'REFRESH_REUSED')),
      );
    });

    test('Logout clears stored credentials', () async {
      await authRepository.login('bilal@demo.pk', 'demo12345');
      expect(await authRepository.me(), isNotNull);

      await authRepository.logout();
      expect(await authRepository.me(), isNull);
    });
  });

  group('AuthCubit State Transitions', () {
    test('Emits [AuthLoading, Authenticated] on successful login', () async {
      final cubit = AuthCubit(authRepository: authRepository);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthLoading(),
          isA<Authenticated>().having((s) => s.user.email, 'email', 'ali@demo.pk'),
        ]),
      );

      await cubit.login('ali@demo.pk', 'demo12345');
      cubit.close();
    });

    test('Emits [AuthLoading, AuthError] on failed login', () async {
      final cubit = AuthCubit(authRepository: authRepository);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthLoading(),
          isA<AuthError>().having((s) => s.code, 'code', 'INVALID_CREDENTIALS'),
        ]),
      );

      await cubit.login('ali@demo.pk', 'badpassword');
      cubit.close();
    });

    test('Emits [AuthLoading, Unauthenticated] on logout', () async {
      await authRepository.login('ali@demo.pk', 'demo12345');
      final cubit = AuthCubit(authRepository: authRepository);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthLoading(),
          const Unauthenticated(message: 'Signed out successfully.'),
        ]),
      );

      await cubit.logout();
      cubit.close();
    });
  });
}
