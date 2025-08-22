abstract class AppFailure {
  final String message;
  const AppFailure(this.message);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.msg = 'No internet connection.']);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.msg = 'Request timed out.']);
}

class ServerFailure extends AppFailure {
  final int? statusCode;
  const ServerFailure(super.msg, {this.statusCode});
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.msg = 'Something went wrong.']);
}
