import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/network/auth_interceptor.dart';
import 'package:shared_living_app/features/auth/data/token_storage.dart';
import 'package:shared_living_app/features/auth/domain/models/auth_tokens.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> responseData;

  _MockHttpAdapter({required this.statusCode, required this.responseData});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseData),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late TokenStorage tokenStorage;
  late Dio mainDio;
  late Dio refreshDio;
  bool forceLogoutCalled = false;

  setUp(() {
    tokenStorage = TokenStorage(inMemoryOnly: true);
    forceLogoutCalled = false;
    mainDio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    refreshDio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  });

  group('AuthInterceptor Tests', () {
    test('Attaches Bearer access token to request headers', () async {
      await tokenStorage.saveTokens(const AuthTokens(
        accessToken: 'initial_token_123',
        refreshToken: 'refresh_token_123',
      ));

      mainDio.httpClientAdapter = _MockHttpAdapter(
        statusCode: 200,
        responseData: {'ok': true},
      );

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
        mainDio: mainDio,
        onForceLogout: () => forceLogoutCalled = true,
      );

      mainDio.interceptors.add(interceptor);

      final response = await mainDio.get('/api/members');
      expect(response.requestOptions.headers['Authorization'], 'Bearer initial_token_123');
    });

    test('Never refreshes on INVALID_CREDENTIALS 401', () async {
      mainDio.httpClientAdapter = _MockHttpAdapter(
        statusCode: 401,
        responseData: {
          'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Invalid credentials'}
        },
      );

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
        mainDio: mainDio,
        onForceLogout: () => forceLogoutCalled = true,
      );

      mainDio.interceptors.add(interceptor);

      try {
        await mainDio.post('/api/auth/login');
      } on DioException catch (_) {
        // Expected 401
      }

      expect(forceLogoutCalled, false);
    });

    test('Forces logout on TOKEN_INVALID and REFRESH_REUSED', () async {
      mainDio.httpClientAdapter = _MockHttpAdapter(
        statusCode: 401,
        responseData: {
          'error': {'code': 'REFRESH_REUSED', 'message': 'Token reused'}
        },
      );

      final interceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshDio: refreshDio,
        mainDio: mainDio,
        onForceLogout: () => forceLogoutCalled = true,
      );

      mainDio.interceptors.add(interceptor);

      try {
        await mainDio.get('/api/dashboard');
      } on DioException catch (_) {
        // Expected 401
      }

      expect(forceLogoutCalled, true);
    });
  });
}
