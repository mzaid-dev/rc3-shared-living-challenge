import '../../../../core/errors/app_failure.dart';
import '../domain/models/auth_tokens.dart';
import '../domain/models/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'token_storage.dart';

class MockAuthRepository implements AuthRepository {
  final TokenStorage tokenStorage;

  MockAuthRepository({TokenStorage? tokenStorage})
      : tokenStorage = tokenStorage ?? TokenStorage();

  // Demo accounts
  static final Map<String, AuthUser> _demoUsers = {
    'ali@demo.pk': const AuthUser(id: 'M01', name: 'Ali', email: 'ali@demo.pk'),
    'ayesha@demo.pk': const AuthUser(id: 'M02', name: 'Ayesha', email: 'ayesha@demo.pk'),
    'bilal@demo.pk': const AuthUser(id: 'M03', name: 'Bilal', email: 'bilal@demo.pk'),
  };

  static const String validPassword = 'demo12345';

  // Tracking issued vs revoked/used refresh tokens for REFRESH_REUSED detection
  final Map<String, String> _activeRefreshTokensToUser = {};
  final Set<String> _consumedRefreshTokens = {};

  int _tokenCounter = 1;

  @override
  Future<AuthTokens> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = _demoUsers[cleanEmail];

    if (user == null || password != validPassword) {
      throw const AppFailure(
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid email or password. Use demo12345.',
      );
    }

    final tokens = _generateTokens(user.id);
    await tokenStorage.saveTokens(tokens);
    await tokenStorage.saveUser(user);
    return tokens;
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    // Check if refresh token was already consumed -> REFRESH_REUSED
    if (_consumedRefreshTokens.contains(refreshToken)) {
      await tokenStorage.clear();
      throw const AppFailure(
        code: 'REFRESH_REUSED',
        message: 'Refresh token has already been used. Session terminated.',
      );
    }

    final userId = _activeRefreshTokensToUser[refreshToken];
    if (userId == null) {
      await tokenStorage.clear();
      throw const AppFailure(
        code: 'TOKEN_INVALID',
        message: 'Refresh token is invalid or expired.',
      );
    }

    // Mark current token consumed
    _consumedRefreshTokens.add(refreshToken);
    _activeRefreshTokensToUser.remove(refreshToken);

    final newTokens = _generateTokens(userId);
    await tokenStorage.saveTokens(newTokens);
    return newTokens;
  }

  @override
  Future<void> logout() async {
    final currentRefresh = await tokenStorage.getRefreshToken();
    if (currentRefresh != null) {
      _activeRefreshTokensToUser.remove(currentRefresh);
      _consumedRefreshTokens.add(currentRefresh);
    }
    await tokenStorage.clear();
  }

  @override
  Future<AuthUser?> me() async {
    return await tokenStorage.getUser();
  }

  AuthTokens _generateTokens(String userId) {
    final id = _tokenCounter++;
    final access = 'access_jwt_${userId}_$id';
    final refresh = 'refresh_jwt_${userId}_$id';
    _activeRefreshTokensToUser[refresh] = userId;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
