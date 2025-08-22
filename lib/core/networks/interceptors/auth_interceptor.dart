import 'package:dio/dio.dart';
import 'package:flutter_laravel_app/core/networks/services/auth_service.dart';

class AuthInterceptor extends Interceptor {
  final AuthService auth;
  AuthInterceptor(this.auth);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final t = auth.accessToken;
    if (t != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $t';
    }
    handler.next(options);
  }
}
