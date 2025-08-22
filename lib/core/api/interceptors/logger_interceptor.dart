// lib/core/api/interceptors/logger_interceptor.dart
import 'package:dio/dio.dart';

class PrettyLoggerInterceptor extends Interceptor {
  final bool enabled;
  PrettyLoggerInterceptor({required this.enabled});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      // Keep logs short to avoid leaking secrets
      // ignore: avoid_print
      print('➡️ ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      // ignore: avoid_print
      print('✅ ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      // ignore: avoid_print
      print('❌ ${err.response?.statusCode} ${err.requestOptions.uri} :: ${err.message}');
    }
    handler.next(err);
  }
}
