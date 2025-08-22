// lib/core/api/api_result.dart
import 'package:flutter_laravel_app/core/api/exceptions.dart';

sealed class ApiResult<T> {
  const ApiResult();
  bool get isSuccess => this is Success<T>;
  T? get data => this is Success<T> ? (this as Success<T>).value : null;
  AppException? get error => this is Failure<T> ? (this as Failure<T>).error : null;
}

class Success<T> extends ApiResult<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends ApiResult<T> {
  final AppException error;
  const Failure(this.error);
}
