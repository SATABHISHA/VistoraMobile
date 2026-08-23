import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/platform_admin/domain/platform_models.dart';

class PlatformRepository {
  const PlatformRepository(this._api);
  final ApiClient _api;

  Future<PlatformOverview> overview() async {
    final response = await _api.get('/superadmin/dashboard');
    return PlatformOverview.fromJson(asMap(response['data']));
  }

  Future<PlatformPage<PlatformTenant>> tenants({
    String? query,
    String? status,
    int page = 1,
    int perPage = 12,
  }) async => _page(
    await _api.get(
      '/superadmin/tenants',
      queryParameters: {
        'q': ?query,
        'status': ?status,
        'page': page,
        'perPage': perPage,
      },
    ),
    PlatformTenant.fromJson,
  );

  Future<void> createTenant({
    required String corpId,
    required String companyName,
  }) => _api.post(
    '/superadmin/tenants',
    data: {
      'corp_id': corpId.trim().toUpperCase(),
      'company_name': companyName.trim(),
      'status': 'active',
    },
  );

  Future<void> toggleTenantStatus(int tenantId) =>
      _api.post('/superadmin/tenants/$tenantId/toggle-status');

  Future<void> updateTenant(int tenantId, Map<String, dynamic> data) =>
      _api.put('/superadmin/tenants/$tenantId', data: data);

  Future<PlatformPage<PlatformPayment>> payments({
    String? query,
    int? month,
    int? year,
    int page = 1,
    int perPage = 12,
  }) async => _page(
    await _api.get(
      '/superadmin/payments',
      queryParameters: {
        'q': ?query,
        'month': ?month,
        'year': ?year,
        'page': page,
        'perPage': perPage,
      },
    ),
    PlatformPayment.fromJson,
  );

  Future<void> recordPayment({
    required String corpId,
    required double amount,
    required String periodType,
    required DateTime paymentDate,
    required bool gstEnabled,
    double gstPercent = 18,
  }) => _api.post(
    '/superadmin/payments',
    data: {
      'corp_id': corpId,
      'package_amount': amount,
      'period_type': periodType,
      'gst_enabled': gstEnabled,
      'gst_percent': gstPercent,
      'payment_date': _date(paymentDate),
    },
  );

  Future<PlatformPage<PlatformOnboardingItem>> onboarding({
    String? status,
    int page = 1,
    int perPage = 12,
  }) async => _page(
    await _api.get(
      '/superadmin/onboarding-queue',
      queryParameters: {'status': ?status, 'page': page, 'perPage': perPage},
    ),
    PlatformOnboardingItem.fromJson,
  );

  Future<void> reviewOnboarding({
    required int id,
    required String decision,
    String? notes,
  }) => _api.post(
    '/superadmin/onboarding-queue/$id/decision',
    data: {
      'decision': decision,
      if (notes?.trim().isNotEmpty == true) 'review_notes': notes!.trim(),
    },
  );

  PlatformPage<T> _page<T>(
    Map<String, dynamic> response,
    T Function(Map<String, dynamic>) parse,
  ) {
    final paginator = asMap(asMap(response['data'])['items']);
    final raw = asList(paginator['data']);
    return PlatformPage<T>(
      items: raw.map((item) => parse(asMap(item))).toList(),
      page: asInt(paginator['current_page'], 1),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], raw.length),
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
