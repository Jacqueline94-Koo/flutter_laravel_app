import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'error/failure.dart';

class Result<T> {
  final T? data;
  final AppFailure? error;
  const Result._({this.data, this.error});
  bool get isOk => error == null;
  static Result<T> ok<T>(T data) => Result._(data: data);
  static Result<T> err<T>(AppFailure error) => Result._(error: error);
}

Future<Result<T>> safeApiCall<T>({
  required Future<T> Function() call,
  String Function(DioException)? customErrorParser,
  Duration timeout = const Duration(seconds: 15),
}) async {
  try {
    final data = await call().timeout(timeout);
    return Result.ok(data);
  } on SocketException {
    return Result.err(const NetworkFailure('No internet connection.'));
  } on TimeoutException {
    return Result.err(const TimeoutFailure());
  } on DioException catch (e) {
    final parsed = customErrorParser?.call(e);
    final serverMsg = _extractServerMessage(e);
    final msg = parsed ?? serverMsg ?? (e.message ?? 'Request failed.');
    return Result.err(ServerFailure(msg, statusCode: e.response?.statusCode));
  } catch (e) {
    return Result.err(UnknownFailure(e.toString()));
  }
}

String? _extractServerMessage(DioException e) {
  final data = e.response?.data;
  if (data == null) return null;
  if (data is String) return data;
  if (data is Map && data['message'] is String) return data['message'] as String;
  return data.toString();
}
