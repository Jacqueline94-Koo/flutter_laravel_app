// lib/core/storage/secure_token_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> save({required String access, String? refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) await _storage.write(key: _kRefresh, value: refresh);
  }

  @override
  Future<String?> readAccess() => _storage.read(key: _kAccess);
  @override
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);
  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
