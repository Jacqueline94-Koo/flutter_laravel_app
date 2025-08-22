import 'package:dio/dio.dart';
import 'package:flutter_laravel_app/core/networks/services/auth_service.dart';

import 'interceptors/auth_interceptor.dart';

class DioClient {
  DioClient(this._auth) {
    dio = Dio(BaseOptions(
      ///TODO: Change the api link
      baseUrl: const String.fromEnvironment('API_BASE', defaultValue: 'https://api.example.com'),
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
    dio.interceptors.addAll([
      AuthInterceptor(_auth),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }
  final AuthService _auth;
  late final Dio dio;
}
