// lib/core/storage/web_token_store.dart
import 'dart:html' as html; // ok for Flutter web

import 'token_store.dart';

class WebTokenStore implements TokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  @override
  Future<void> save({required String access, String? refresh}) async {
    html.window.localStorage[_kAccess] = access;
    if (refresh != null) html.window.localStorage[_kRefresh] = refresh;
  }

  @override
  Future<String?> readAccess() async => html.window.localStorage[_kAccess];
  @override
  Future<String?> readRefresh() async => html.window.localStorage[_kRefresh];
  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_kAccess);
    html.window.localStorage.remove(_kRefresh);
  }
}
