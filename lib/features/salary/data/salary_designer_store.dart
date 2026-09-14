import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vistora_mobile/features/salary/domain/salary_models.dart';

class SalaryDesignerStore {
  SalaryDesignerStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<SalaryDesignerState?> readLegacy(String corpId) async {
    try {
      final value = await _storage.read(key: _key(corpId));
      if (value == null || value.trim().isEmpty) return null;
      final decoded = jsonDecode(value);
      return decoded is Map
          ? SalaryDesignerState.fromJson(Map<String, dynamic>.from(decoded))
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> wasMigrated(String corpId) async =>
      (await _storage.read(key: _migrationKey(corpId))) == '1';

  Future<void> markMigrated(String corpId) =>
      _storage.write(key: _migrationKey(corpId), value: '1');

  Future<void> resetMigration(String corpId) =>
      _storage.delete(key: _migrationKey(corpId));

  Future<SalaryDesignerState> read(String corpId) async {
    try {
      final value = await _storage.read(key: _key(corpId));
      if (value == null || value.trim().isEmpty) {
        return SalaryDesignerState.defaults;
      }
      final decoded = jsonDecode(value);
      return decoded is Map
          ? SalaryDesignerState.fromJson(Map<String, dynamic>.from(decoded))
          : SalaryDesignerState.defaults;
    } catch (_) {
      return SalaryDesignerState.defaults;
    }
  }

  Future<void> write(String corpId, SalaryDesignerState state) =>
      _storage.write(key: _key(corpId), value: jsonEncode(state.toJson()));

  String _key(String corpId) =>
      'vistora_salary_designer_${corpId.trim().toUpperCase()}';

  String _migrationKey(String corpId) => '${_key(corpId)}_api_migrated_v1';
}
