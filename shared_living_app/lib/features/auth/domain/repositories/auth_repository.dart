import '../models/auth_tokens.dart';
import '../models/auth_user.dart';

abstract class AuthRepository {
  Future<AuthTokens> login(String email, String password);

  Future<AuthTokens> refresh(String refreshToken);

  Future<void> logout();

  Future<AuthUser?> me();
}
