// lib/core/api/exceptions.dart
import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final String? code; // http code or custom
  final int? statusCode;
  const AppException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'AppException($statusCode, $code): $message';

  static AppException fromDio(Object e) {
    if (e is DioException) {
      final res = e.response;
      switch (e.type) {
        case DioExceptionType.cancel:
          return const AppException('Request cancelled', code: 'cancelled');
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const AppException('Network timeout', code: 'timeout');
        case DioExceptionType.badResponse:
          final status = res?.statusCode ?? 0;
          final msg = res?.data is Map && res!.data['message'] is String
              ? res.data['message'] as String
              : 'Server error ($status)';
          return AppException(msg, statusCode: status, code: 'bad_response');
        case DioExceptionType.connectionError:
          return const AppException('No internet connection', code: 'network');
        default:
          return const AppException('Unexpected error', code: 'unknown');
      }
    }
    return const AppException('Unexpected error', code: 'unknown');
  }
}
