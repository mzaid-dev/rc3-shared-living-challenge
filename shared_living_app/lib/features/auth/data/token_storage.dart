import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/models/auth_tokens.dart';
import '../domain/models/auth_user.dart';

class TokenStorage {
  final FlutterSecureStorage? _secureStorage;
  final Map<String, String> _memoryFallback = {};
  bool _useMemoryFallback;

  TokenStorage({FlutterSecureStorage? secureStorage, bool inMemoryOnly = false})
      : _secureStorage = inMemoryOnly ? null : (secureStorage ?? const FlutterSecureStorage()),
        _useMemoryFallback = inMemoryOnly;

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUser = 'auth_current_user';

  Future<void> saveTokens(AuthTokens tokens) async {
    if (_useMemoryFallback || _secureStorage == null) {
      _memoryFallback[_keyAccessToken] = tokens.accessToken;
      _memoryFallback[_keyRefreshToken] = tokens.refreshToken;
      return;
    }
    try {
      await _secureStorage.write(key: _keyAccessToken, value: tokens.accessToken);
      await _secureStorage.write(key: _keyRefreshToken, value: tokens.refreshToken);
    } catch (_) {
      _useMemoryFallback = true;
      _memoryFallback[_keyAccessToken] = tokens.accessToken;
      _memoryFallback[_keyRefreshToken] = tokens.refreshToken;
    }
  }

  Future<String?> getAccessToken() async {
    if (_useMemoryFallback || _secureStorage == null) {
      return _memoryFallback[_keyAccessToken];
    }
    try {
      return await _secureStorage.read(key: _keyAccessToken);
    } catch (_) {
      _useMemoryFallback = true;
      return _memoryFallback[_keyAccessToken];
    }
  }

  Future<String?> getRefreshToken() async {
    if (_useMemoryFallback || _secureStorage == null) {
      return _memoryFallback[_keyRefreshToken];
    }
    try {
      return await _secureStorage.read(key: _keyRefreshToken);
    } catch (_) {
      _useMemoryFallback = true;
      return _memoryFallback[_keyRefreshToken];
    }
  }

  Future<void> saveUser(AuthUser user) async {
    final str = jsonEncode(user.toJson());
    if (_useMemoryFallback || _secureStorage == null) {
      _memoryFallback[_keyUser] = str;
      return;
    }
    try {
      await _secureStorage.write(key: _keyUser, value: str);
    } catch (_) {
      _useMemoryFallback = true;
      _memoryFallback[_keyUser] = str;
    }
  }

  Future<AuthUser?> getUser() async {
    String? raw;
    if (_useMemoryFallback || _secureStorage == null) {
      raw = _memoryFallback[_keyUser];
    } else {
      try {
        raw = await _secureStorage.read(key: _keyUser);
      } catch (_) {
        _useMemoryFallback = true;
        raw = _memoryFallback[_keyUser];
      }
    }
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _memoryFallback.clear();
    if (!_useMemoryFallback && _secureStorage != null) {
      try {
        await _secureStorage.deleteAll();
      } catch (_) {
        _useMemoryFallback = true;
      }
    }
  }
}
