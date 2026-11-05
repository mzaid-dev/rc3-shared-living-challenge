import 'dart:async';
import 'package:dio/dio.dart';
import '../../features/auth/data/token_storage.dart';
import '../../features/auth/domain/models/auth_tokens.dart';

typedef OnForceLogout = void Function();

class AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final Dio refreshDio;
  final Dio mainDio;
  final OnForceLogout? onForceLogout;

  // Mutex for sharing one single refresh future across concurrent 401 responses
  Completer<AuthTokens?>? _refreshCompleter;

  AuthInterceptor({
    required this.tokenStorage,
    required this.refreshDio,
    required this.mainDio,
    this.onForceLogout,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response == null || response.statusCode != 401) {
      return handler.next(err);
    }

    final requestOptions = err.requestOptions;

    // Rule 7: Retry original request exactly once
    final isRetry = requestOptions.extra['is_retry'] == true;
    if (isRetry) {
      return handler.next(err);
    }

    // Inspect error payload if available
    String errorCode = '';
    if (response.data is Map) {
      final errorMap = (response.data as Map)['error'];
      if (errorMap is Map) {
        errorCode = errorMap['code']?.toString() ?? '';
      }
    }

    // Rule 7: Never refresh on INVALID_CREDENTIALS
    if (errorCode == 'INVALID_CREDENTIALS') {
      return handler.next(err);
    }

    // Rule 7: TOKEN_INVALID and REFRESH_REUSED force logout
    if (errorCode == 'TOKEN_INVALID' || errorCode == 'REFRESH_REUSED') {
      onForceLogout?.call();
      await tokenStorage.clear();
      return handler.next(err);
    }

    // Concurrent 401 handling: share ONE refresh future
    AuthTokens? newTokens;
    if (_refreshCompleter != null) {
      newTokens = await _refreshCompleter!.future;
    } else {
      _refreshCompleter = Completer<AuthTokens?>();
      try {
        final currentRefreshToken = await tokenStorage.getRefreshToken();
        if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
          await tokenStorage.clear();
          onForceLogout?.call();
          _refreshCompleter!.complete(null);
          return handler.next(err);
        }

        // Use dedicated refreshDio with NO interceptors
        final refreshResponse = await refreshDio.post(
          '/api/auth/refresh',
          data: {'refresh_token': currentRefreshToken},
        );

        if (refreshResponse.statusCode == 200 && refreshResponse.data is Map<String, dynamic>) {
          final data = refreshResponse.data as Map<String, dynamic>;
          final tokens = AuthTokens.fromJson(data);
          await tokenStorage.saveTokens(tokens);
          _refreshCompleter!.complete(tokens);
          newTokens = tokens;
        } else {
          await tokenStorage.clear();
          onForceLogout?.call();
          _refreshCompleter!.complete(null);
        }
      } catch (refreshErr) {
        if (refreshErr is DioException) {
          final refreshData = refreshErr.response?.data;
          if (refreshData is Map<String, dynamic>) {
            final errCode = refreshData['error']?['code'];
            if (errCode == 'REFRESH_REUSED' || errCode == 'TOKEN_INVALID') {
              await tokenStorage.clear();
              onForceLogout?.call();
            }
          }
        }
        _refreshCompleter!.complete(null);
      } finally {
        _refreshCompleter = null;
      }
    }

    if (newTokens != null) {
      // Mark as retry and repeat the original request
      requestOptions.extra['is_retry'] = true;
      requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';

      try {
        final retryResponse = await mainDio.fetch(requestOptions);
        return handler.resolve(retryResponse);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }

    return handler.next(err);
  }
}
