enum AppErrorKind {
  connection,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
  server,
  unknown,
}

class AppException implements Exception {
  const AppException({
    required this.message,
    this.kind = AppErrorKind.unknown,
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
  });

  final String message;
  final AppErrorKind kind;
  final int? statusCode;
  final String? code;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => kind == AppErrorKind.unauthorized;

  @override
  String toString() => message;
}
