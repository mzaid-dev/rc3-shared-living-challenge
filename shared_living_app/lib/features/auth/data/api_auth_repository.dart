import 'package:dio/dio.dart';

import '../../../../core/errors/app_failure.dart';
import '../domain/models/auth_tokens.dart';
import '../domain/models/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'token_storage.dart';

class ApiAuthRepository implements AuthRepository {
  final Dio dio;
  final Dio refreshDio;
  final TokenStorage tokenStorage;

  ApiAuthRepository({
    required this.dio,
    required this.refreshDio,
    required this.tokenStorage,
  });

  @override
  Future<AuthTokens> login(String email, String password) async {
    try {
      final response = await dio.post(
        '/api/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final tokens = AuthTokens.fromJson(data);
      await tokenStorage.saveTokens(tokens);

      // Attempt to load and cache profile
      try {
        final profile = await me();
        if (profile != null) {
          await tokenStorage.saveUser(profile);
        }
      } catch (_) {}

      return tokens;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'LOGIN_FAILED', message: e.toString());
    }
  }

  @override
  Future<AuthTokens> register(String name, String email, String password) async {
    try {
      await dio.post(
        '/api/auth/register',
        data: {
          'display_name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      // Immediately login after successful registration
      final tokens = await login(email, password);

      // Automatically link newly registered user to the apartment household (LAHORE2026)
      try {
        await dio.post(
          '/api/households/join',
          data: {'invite_code': 'LAHORE2026'},
        );
      } catch (_) {
        try {
          await dio.post(
            '/api/households',
            data: {'name': 'Gulberg 4B Apartment'},
          );
        } catch (_) {}
      }

      // Re-hydrate profile with linked household and member details
      try {
        final profile = await me();
        if (profile != null) {
          await tokenStorage.saveUser(profile);
        }
      } catch (_) {}

      return tokens;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'REGISTER_FAILED', message: e.toString());
    }
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final response = await refreshDio.post(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final tokens = AuthTokens.fromJson(data);
      await tokenStorage.saveTokens(tokens);
      return tokens;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'REFRESH_FAILED', message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await dio.post(
          '/api/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Best-effort remote revocation
    } finally {
      await tokenStorage.clear();
    }
  }

  @override
  Future<AuthUser?> me() async {
    try {
      final response = await dio.get('/api/auth/me');
      if (response.data is Map<String, dynamic>) {
        final user = AuthUser.fromJson(response.data as Map<String, dynamic>);
        await tokenStorage.saveUser(user);
        return user;
      }
    } catch (_) {
      // Fallback to local storage if offline
      return await tokenStorage.getUser();
    }
    return await tokenStorage.getUser();
  }

  Never _handleDioError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      throw AppFailure.fromJson(e.response!.data as Map<String, dynamic>);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const AppFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Connection timed out. Please check your internet connection.',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      throw const AppFailure(
        code: 'NETWORK_UNREACHABLE',
        message: 'Unable to connect to the Hisab server. Please verify the server is running.',
      );
    }

    throw AppFailure(
      code: 'HTTP_ERROR_${e.response?.statusCode ?? 500}',
      message: e.message ?? 'An unexpected network error occurred.',
    );
  }
}

