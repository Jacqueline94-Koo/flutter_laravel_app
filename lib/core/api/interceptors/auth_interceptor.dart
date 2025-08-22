// lib/core/api/interceptors/auth_interceptor.dart
import 'dart:async';

import 'package:dio/dio.dart';

import '../../storage/token_store.dart';

typedef RefreshCallback = Future<String?> Function();

class AuthInterceptor extends Interceptor {
  final TokenStore tokenStore;
  final RefreshCallback refreshToken;
  final List<String> excludedPaths;

  bool _isRefreshing = false;
  final _waiters = <Completer<void>>[];

  AuthInterceptor({
    required this.tokenStore,
    required this.refreshToken,
    this.excludedPaths = const ['/auth/login', '/auth/register'],
  });

  @override
  Future onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isExcluded(options.path)) {
      final token = await tokenStore.readAccess();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode ?? 0;
    final path = err.requestOptions.path;

    final isAuthEndpoint = _isExcluded(path);
    if (status == 401 && !isAuthEndpoint) {
      try {
        await _queueRefresh();
        // Retry original request with new token attached by onRequest
        final dio = err.requestOptions.extra['dio'] as Dio;
        final newResponse = await dio.fetch(err.requestOptions);
        return handler.resolve(newResponse);
      } catch (_) {
        // refresh failed: force logout
        await tokenStore.clear();
      }
    }
    handler.next(err);
  }

  bool _isExcluded(String path) => excludedPaths.any((p) => path.contains(p));

  Future<void> _queueRefresh() async {
    if (_isRefreshing) {
      final c = Completer<void>();
      _waiters.add(c);
      return c.future;
    }
    _isRefreshing = true;
    try {
      final newToken = await refreshToken();
      if (newToken == null) {
        for (final w in _waiters) {
          w.completeError('refresh_failed');
        }
        _waiters.clear();
        throw 'refresh_failed';
      }
      for (final w in _waiters) {
        w.complete();
      }
      _waiters.clear();
    } finally {
      _isRefreshing = false;
    }
  }
}
