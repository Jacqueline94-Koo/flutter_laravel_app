abstract class AuthService {
  String? get accessToken;
  Future<bool> refreshToken();
  Future<void> saveToken(String access, {String? refresh});
  Future<void> logout();
}
