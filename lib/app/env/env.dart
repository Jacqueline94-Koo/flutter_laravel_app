// lib/app/env/env.dart
class Env {
  final String baseUrl;
  final bool enableLogging;
  final String authStrategy;

  const Env({
    required this.baseUrl,
    this.enableLogging = false,
    this.authStrategy = 'sanctum',
  });
}
