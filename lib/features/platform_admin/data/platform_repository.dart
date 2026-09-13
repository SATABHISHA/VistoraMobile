import 'package:dio/dio.dart';
import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/platform_admin/domain/platform_models.dart';
import 'package:vistora_mobile/features/tax_invoices/domain/tax_invoice_models.dart';

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
    required String adminUsername,
    required String adminEmail,
    required String adminPassword,
    String adminName = 'Tenant Admin',
    String? phone,
    String? gstin,
  }) => _api.post(
    '/superadmin/tenants',
    data: {
      'corp_id': corpId.trim().toUpperCase(),
      'company_name': companyName.trim(),
      'admin_name': adminName.trim(),
      'admin_username': adminUsername.trim(),
      'admin_email': adminEmail.trim(),
      'admin_password': adminPassword,
      'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      'gstin': gstin?.trim().isNotEmpty == true
          ? gstin!.trim().toUpperCase()
          : null,
      'status': 'active',
    },
  );

  Future<List<PlatformTenantAdmin>> tenantAdmins(int tenantId) async {
    final response = await _api.get('/superadmin/tenants/$tenantId/admins');
    return asList(
      asMap(response['data'])['items'],
    ).map((item) => PlatformTenantAdmin.fromJson(asMap(item))).toList();
  }

  Future<void> createTenantAdmin({
    required int tenantId,
    required String name,
    required String roleType,
    required String username,
    required String email,
    required String password,
  }) => _api.post(
    '/superadmin/tenants/$tenantId/admins',
    data: {
      'name': name.trim(),
      'role_type': roleType,
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
    },
  );

  Future<void> updateTenantAdmin({
    required int tenantId,
    required int adminId,
    required Map<String, dynamic> data,
  }) => _api.put('/superadmin/tenants/$tenantId/admins/$adminId', data: data);

  Future<void> toggleTenantStatus(int tenantId) =>
      _api.post('/superadmin/tenants/$tenantId/toggle-status');

  Future<void> updateTenant(int tenantId, Map<String, dynamic> data) =>
      _api.put('/superadmin/tenants/$tenantId', data: data);

  Future<PlatformTenant> updateTenantBillingProfile({
    required int tenantId,
    String? gstin,
    String? phone,
  }) async {
    final response = await _api.put(
      '/superadmin/tenants/$tenantId/billing-profile',
      data: {'gstin': gstin, 'phone': phone},
    );
    return PlatformTenant.fromJson(asMap(asMap(response['data'])['tenant']));
  }

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

  Future<void> savePayment(PlatformPaymentDraft draft, {int? paymentId}) =>
      paymentId == null
      ? _api.post('/superadmin/payments', data: draft.toJson())
      : _api.put('/superadmin/payments/$paymentId', data: draft.toJson());

  Future<void> deletePayment(int paymentId) =>
      _api.delete('/superadmin/payments/$paymentId');

  Future<TaxInvoiceDetail> paymentInvoice(int paymentId) async {
    final response = await _api.get('/superadmin/payments/$paymentId/invoice');
    return TaxInvoiceDetail.fromJson(asMap(response['data']));
  }

  Future<PlatformBillingSettings> billingSettings() async {
    final response = await _api.get('/superadmin/settings');
    return PlatformBillingSettings.fromJson(
      asMap(asMap(response['data'])['settings']),
    );
  }

  Future<String> superadminAccountEmail() async {
    final response = await _api.get('/superadmin/account');
    return asMap(asMap(response['data'])['account'])['email']?.toString() ?? '';
  }

  Future<String> updateSuperadminAccount({
    required String email,
    required String currentPassword,
    String? newPassword,
  }) async {
    final response = await _api.put(
      '/superadmin/account',
      data: {
        'email': email.trim(),
        'current_password': currentPassword,
        if (newPassword?.isNotEmpty == true) ...{
          'password': newPassword,
          'password_confirmation': newPassword,
        },
      },
    );
    return asMap(asMap(response['data'])['account'])['email']?.toString() ??
        email.trim();
  }

  Future<PlatformBillingSettings> saveBillingSettings(
    PlatformBillingSettings settings,
  ) async {
    final response = await _api.put(
      '/superadmin/settings',
      data: settings.toJson(),
    );
    return PlatformBillingSettings.fromJson(
      asMap(asMap(response['data'])['settings']),
    );
  }

  Future<PlatformBillingSettings> uploadBillingSeal({
    required String filename,
    required List<int> bytes,
  }) async {
    final response = await _api.post(
      '/superadmin/settings/seal',
      data: FormData.fromMap({
        'seal': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return PlatformBillingSettings.fromJson(
      asMap(asMap(response['data'])['settings']),
    );
  }

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

  Future<PlatformRegistrationLink> createClientRegistrationLink({
    String? proposedCorpId,
    required String validityType,
    required int validHours,
  }) async {
    final response = await _api.post(
      '/superadmin/client-registration-links',
      data: {
        if (proposedCorpId?.trim().isNotEmpty == true)
          'corp_id_proposed': proposedCorpId!.trim().toUpperCase(),
        'validity_type': validityType,
        'valid_hours': validHours,
      },
    );
    return PlatformRegistrationLink.fromJson(asMap(response['data']));
  }

  Future<void> sendClientRegistrationLink({
    required int linkId,
    required String email,
  }) => _api.post(
    '/superadmin/client-registration-links/$linkId/send',
    data: {'email': email.trim()},
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
}
