// lib/core/api/interceptors/retry_interceptor.dart
import 'dart:async';

import 'package:dio/dio.dart';

class SimpleRetryInterceptor extends Interceptor {
  final int retries;
  final Duration baseDelay;

  const SimpleRetryInterceptor({
    this.retries = 2,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;

    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    // Count attempts on the original request
    final attempt = (req.extra['retry_count'] as int? ?? 0) + 1;
    if (attempt > retries) {
      handler.next(err);
      return;
    }
    req.extra['retry_count'] = attempt;

    // Backoff (linear by default; make it exponential if you like)
    await Future.delayed(baseDelay * attempt);

    // If caller cancelled in the meantime, stop.
    if (req.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }

    // We stored the Dio instance in options.extra['dio'] from the DioClient.
    final dio = req.extra['dio'] as Dio?;
    if (dio == null) {
      handler.next(err);
      return;
    }

    // Avoid retrying non-replayable streams (e.g., file uploads with a single-use stream).
    final isStreamBody = req.data is Stream<dynamic>;
    if (isStreamBody) {
      handler.next(err);
      return;
    }

    try {
      final cloned = _cloneRequestOptions(req);
      final response = await dio.fetch(cloned);
      handler.resolve(response);
    } catch (_) {
      // If the retry attempt itself throws, propagate the original error.
      handler.next(err);
    }
  }

  bool _shouldRetry(DioException e) {
    // Retry on transient network issues & server errors (>=500)
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        ((e.response?.statusCode ?? 0) >= 500);
  }

  RequestOptions _cloneRequestOptions(RequestOptions req) {
    // Note: We keep the same CancelToken so the caller can still cancel.
    return RequestOptions(
      path: req.path,
      method: req.method,
      baseUrl: req.baseUrl,
      headers: Map<String, dynamic>.from(req.headers),
      queryParameters: Map<String, dynamic>.from(req.queryParameters),
      data: req.data,
      extra: Map<String, dynamic>.from(req.extra),
      contentType: req.contentType,
      responseType: req.responseType,
      followRedirects: req.followRedirects,
      maxRedirects: req.maxRedirects,
      receiveDataWhenStatusError: req.receiveDataWhenStatusError,
      validateStatus: req.validateStatus,
      listFormat: req.listFormat,
      connectTimeout: req.connectTimeout,
      receiveTimeout: req.receiveTimeout,
      sendTimeout: req.sendTimeout,
      onReceiveProgress: req.onReceiveProgress,
      onSendProgress: req.onSendProgress,
      cancelToken: req.cancelToken,
    );
  }
}
