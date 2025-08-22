import 'env.dart';

const envDev = Env(
  baseUrl: 'http://localhost:8000/api', // Laravel: /api
  enableLogging: true,
  authStrategy: 'sanctum', // or 'sanctum'
);
