import 'package:dio/dio.dart';

class DioClientConfig {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';

  static String get baseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultBaseUrl,
    );
  }

  static BaseOptions createOptions({String? customBaseUrl}) {
    return BaseOptions(
      baseUrl: customBaseUrl ?? baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  /// Primary Dio instance configured with standard options
  static Dio createDio({String? customBaseUrl}) {
    return Dio(createOptions(customBaseUrl: customBaseUrl));
  }

  /// Dedicated Refresh Dio instance with ZERO interceptors per Rule 7
  static Dio createRefreshDio({String? customBaseUrl}) {
    return Dio(createOptions(customBaseUrl: customBaseUrl));
  }
}
