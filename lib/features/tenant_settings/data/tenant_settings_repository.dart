import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/tenant_settings/domain/tenant_settings_models.dart';

class TenantSettingsRepository {
  const TenantSettingsRepository(this._api);
  final ApiClient _api;

  Future<TenantSettings> settings() async {
    final response = await _api.get('/settings/tenant');
    return _parseSettings(response);
  }

  Future<TenantSettings> update(Map<String, dynamic> data) async {
    final response = await _api.put('/settings/tenant', data: data);
    return _parseSettings(response);
  }

  TenantSettings _parseSettings(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    return TenantSettings.fromJson({
      ...asMap(data['tenant']),
      'geofence_employee_ids': data['geofence_employee_ids'],
      'geofence_employees': data['geofence_employees'],
    });
  }

  Future<List<MasterItem>> masters(String type) async {
    final response = await _api.get('/settings/masters/$type');
    return asList(
      asMap(response['data'])['items'],
    ).map((item) => MasterItem.fromJson(asMap(item))).toList();
  }

  Future<List<String>> employmentTypes() async {
    final response = await _api.get('/settings/employment-types');
    return asList(asMap(response['data'])['items'])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> createMaster({
    required String type,
    required String name,
    String? code,
  }) => _api.post(
    '/settings/masters/$type',
    data: {
      'name': name.trim(),
      if (code?.trim().isNotEmpty == true) 'code': code!.trim(),
    },
  );

  Future<void> deleteMaster(String type, int id) =>
      _api.delete('/settings/masters/$type/$id');

  Future<void> testSmtp(String email) =>
      _api.post('/settings/smtp/test', data: {'to': email.trim()});
}
