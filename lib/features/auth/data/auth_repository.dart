import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/storage/token_storage.dart';
import 'package:vistora_mobile/features/auth/domain/auth_session.dart';

class AuthRepository {
  const AuthRepository({required ApiClient api, required TokenStorage storage})
    : _api = api,
      _storage = storage;

  final ApiClient _api;
  final TokenStorage _storage;

  Future<AuthSession> login({
    required String corpId,
    required String identity,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      data: {'corpId': corpId, 'identity': identity, 'password': password},
    );
    final data = _map(response['data']);
    final token = data['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'Login response did not contain an access token.',
      );
    }
    await _storage.write(token);
    try {
      return await restoreSession();
    } catch (_) {
      await _storage.clear();
      rethrow;
    }
  }

  Future<AuthSession> restoreSession() async {
    final response = await _api.get('/auth/me');
    return AuthSession.fromMeResponse(response);
  }

  Future<bool> hasStoredToken() async =>
      (await _storage.read())?.isNotEmpty ?? false;

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _storage.clear();
    }
  }

  Future<void> forgotPassword({
    required String corpId,
    required String email,
  }) => _api.post(
    '/auth/forgot-password',
    data: {'corpId': corpId, 'email': email},
  );

  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) => _api.post(
    '/auth/change-password',
    data: {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': password,
    },
  );

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}
