import 'package:dio/dio.dart';
import 'package:vistora_mobile/core/errors/app_exception.dart';
import 'package:vistora_mobile/core/storage/token_storage.dart';

class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage})
    : _tokenStorage = tokenStorage,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 25),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.endsWith('/auth/login')) {
            await _tokenStorage.clear();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _request('GET', path, queryParameters: queryParameters);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) => _request('POST', path, data: data, queryParameters: queryParameters);

  Future<Map<String, dynamic>> put(String path, {Object? data}) =>
      _request('PUT', path, data: data);

  Future<Map<String, dynamic>> delete(String path, {Object? data}) =>
      _request('DELETE', path, data: data);

  Future<Response<List<int>>> download(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
      );
      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return Map<String, dynamic>.from(body);
      throw const AppException(
        message: 'The server returned an invalid response.',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  AppException _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const AppException(
        message: 'The request timed out. Please try again.',
        kind: AppErrorKind.timeout,
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppException(
        message:
            'Unable to connect to Vistora. Check your network and server URL.',
        kind: AppErrorKind.connection,
      );
    }

    final status = error.response?.statusCode;
    final raw = error.response?.data;
    final body = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final validation = <String, List<String>>{};
    final errors = body['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        validation[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList()
            : [value.toString()];
      }
    }
    String? code;
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      code = (errors.first as Map)['code']?.toString();
    }
    return AppException(
      message: body['message']?.toString() ?? _defaultMessage(status),
      statusCode: status,
      code: code,
      fieldErrors: validation,
      kind: switch (status) {
        401 => AppErrorKind.unauthorized,
        403 => AppErrorKind.forbidden,
        404 => AppErrorKind.notFound,
        422 => AppErrorKind.validation,
        429 => AppErrorKind.rateLimited,
        != null when status >= 500 => AppErrorKind.server,
        _ => AppErrorKind.unknown,
      },
    );
  }

  String _defaultMessage(int? status) => switch (status) {
    401 => 'Your session has expired. Please sign in again.',
    403 => 'You do not have permission to perform this action.',
    404 => 'The requested information could not be found.',
    422 => 'Please review the submitted information.',
    429 => 'Too many requests. Please wait and try again.',
    != null when status >= 500 => 'Vistora is temporarily unavailable.',
    _ => 'Something went wrong. Please try again.',
  };
}
