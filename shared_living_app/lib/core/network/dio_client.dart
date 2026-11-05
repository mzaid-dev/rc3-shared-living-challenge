import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

class DioClientConfig {
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return defaultBaseUrl;
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
