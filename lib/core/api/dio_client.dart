// lib/core/api/dio_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

import '../../app/env/env.dart';
import '../storage/token_store.dart';
import 'exceptions.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logger_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// A thin, reusable wrapper around Dio with:
/// - sensible timeouts & JSON defaults
/// - auth / retry / logging interceptors
/// - typed helpers for JSON, form-data upload, and file download
class DioClient {
  final Dio dio;

  DioClient._(this.dio);

  /// Factory that wires up interceptors.
  factory DioClient({
    required Env env,
    required TokenStore tokenStore,
    required RefreshCallback refreshToken,
  }) {
    final base = BaseOptions(
      baseUrl: env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    );

    final d = Dio(base);

    // Make this Dio instance available to other interceptors via RequestOptions.extra['dio']
    d.interceptors.add(_LinkSelfInterceptor(d));

    // Attach your reusable interceptors
    d.interceptors.addAll([
      PrettyLoggerInterceptor(enabled: env.enableLogging || kDebugMode),
      SimpleRetryInterceptor(),
      AuthInterceptor(
        tokenStore: tokenStore,
        refreshToken: refreshToken,
      ),
    ]);

    return DioClient._(d);
  }

  /// ---- JSON helpers --------------------------------------------------------

  Future<T> getJson<T>(
    String path,
    T Function(dynamic data) parse, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) =>
      _wrap(() async {
        final res = await dio.get(
          path,
          queryParameters: query,
          options: Options(headers: headers),
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
        return parse(res.data);
      });

  Future<T> postJson<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _wrap(() async {
        final res = await dio.post(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        );
        return parse(res.data);
      });

  Future<T> putJson<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _wrap(() async {
        final res = await dio.put(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        );
        return parse(res.data);
      });

  Future<T> patchJson<T>(
    String path,
    Object? body,
    T Function(dynamic data) parse, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _wrap(() async {
        final res = await dio.patch(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        );
        return parse(res.data);
      });

  /// Some APIs require a request body with DELETE; supported here via [body].
  Future<T> deleteJson<T>(
    String path,
    T Function(dynamic data) parse, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) =>
      _wrap(() async {
        final res = await dio.delete(
          path,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
          cancelToken: cancelToken,
        );
        return parse(res.data);
      });

  /// Convenience for list endpoints: parses `List` payloads.
  Future<List<T>> getList<T>(
    String path,
    T Function(Map<String, dynamic> item) fromJson, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) =>
      getJson<List<T>>(
        path,
        (data) {
          final list = (data as List).cast<dynamic>();
          return list.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
        },
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      );

  /// ---- Multipart helpers ---------------------------------------------------

  /// Upload form-data (fields + files).
  ///
  /// - [fields] are regular form fields.
  /// - [files] is a map of `fieldName -> MultipartFile` (create via [makeMultipartFile]).
  Future<T> uploadForm<T>(
    String path, {
    Map<String, dynamic>? fields,
    Map<String, MultipartFile>? files,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required T Function(dynamic data) parse,
  }) =>
      _wrap(() async {
        final map = <String, dynamic>{};
        if (fields != null) map.addAll(fields);
        if (files != null) map.addAll(files);
        final form = FormData.fromMap(map);

        final res = await dio.post(
          path,
          data: form,
          queryParameters: query,
          options: Options(
            headers: {
              ...?headers,
              'Content-Type': 'multipart/form-data',
            },
          ),
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        );
        return parse(res.data);
      });

  /// Utility to create a MultipartFile from bytes (cross-platform).
  ///
  /// Example:
  /// ```dart
  /// final file = DioClient.makeMultipartFile(bytes: bytes, filename: 'photo.jpg');
  /// await client.uploadForm('/upload', files: {'photo': file}, parse: (_) => null);
  /// ```
  static MultipartFile makeMultipartFile({
    required Uint8List bytes,
    required String filename,
    String? contentType, // e.g. 'image/jpeg'
  }) {
    return MultipartFile.fromBytes(
      bytes,
      filename: filename,
      contentType: contentType != null ? MediaType.parse(contentType) : null,
    );
  }

  /// ---- Download helper -----------------------------------------------------

  /// Download a file to [savePath]. Note: on Flutter Web, writing to an
  /// arbitrary filesystem path is not supported (use a different approach).
  Future<void> download(
    String url,
    String savePath, {
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? query,
  }) =>
      _wrap<void>(() async {
        await dio.download(
          url,
          savePath,
          options: Options(headers: headers),
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
          queryParameters: query,
        );
      });

  /// ---- Utilities -----------------------------------------------------------

  /// Closes underlying HTTP client.
  void close({bool force = false}) => dio.close(force: force);

  /// Shared error wrapper that converts DioException -> AppException.
  Future<T> _wrap<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    } catch (e) {
      // Any other unexpected error
      throw AppException.fromDio(e);
    }
  }
}

/// Internal interceptor that attaches this Dio instance onto each request's
/// `options.extra['dio']` so other interceptors (retry/auth) can access it.
class _LinkSelfInterceptor extends Interceptor {
  final Dio _dio;
  _LinkSelfInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['dio'] = _dio;
    handler.next(options);
  }
}
