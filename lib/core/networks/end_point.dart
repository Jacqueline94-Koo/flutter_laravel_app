class Endpoints {
  static const _v1 = '/api/v1';

  // Auth
  static const login = '$_v1/auth/login';
  static const refresh = '$_v1/auth/refresh';
  static const me = '$_v1/auth/me';

  // Users
  static String user(String id) => '$_v1/users/$id';
  static String userPosts(String id, {int page = 1}) => '$_v1/users/$id/posts?page=$page';
}
