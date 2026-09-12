import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberedLogin {
  const RememberedLogin({required this.corpId, required this.identity});

  final String corpId;
  final String identity;
}

abstract interface class LoginIdentityStorage {
  Future<RememberedLogin?> read();
  Future<void> write({required String corpId, required String identity});
  Future<void> clear();
}

class SecureLoginIdentityStorage implements LoginIdentityStorage {
  SecureLoginIdentityStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _corpIdKey = 'vistora_remembered_corp_id';
  static const _identityKey = 'vistora_remembered_identity';

  final FlutterSecureStorage _storage;

  @override
  Future<RememberedLogin?> read() async {
    final corpId = await _storage.read(key: _corpIdKey);
    final identity = await _storage.read(key: _identityKey);
    if (corpId == null ||
        corpId.trim().isEmpty ||
        identity == null ||
        identity.trim().isEmpty) {
      return null;
    }

    return RememberedLogin(corpId: corpId, identity: identity);
  }

  @override
  Future<void> write({required String corpId, required String identity}) async {
    await _storage.write(key: _corpIdKey, value: corpId.trim().toUpperCase());
    await _storage.write(key: _identityKey, value: identity.trim());
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _corpIdKey);
    await _storage.delete(key: _identityKey);
  }
}
