// lib/core/storage/token_store.dart
abstract class TokenStore {
  Future<void> save({required String access, String? refresh});
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> clear();
}
