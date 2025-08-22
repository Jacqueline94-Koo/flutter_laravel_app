import 'env.dart';

const envProd = Env(
  baseUrl: 'https://yourdomain.com/api',
  enableLogging: false,
  authStrategy: 'sanctum',
);
