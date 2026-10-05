import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/billing/domain/billing_models.dart';

class BillingRepository {
  const BillingRepository(this._api);
  final ApiClient _api;

  Future<BillingPage> tenantBills({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
    int? month,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async => _page(
    await _api.get(
      '/billing/bills',
      queryParameters: {
        'page': page,
        'perPage': perPage,
        'status': ?status,
        'year': ?year,
        'month': ?month,
        'date_from': ?dateFrom?.toIso8601String().substring(0, 10),
        'date_to': ?dateTo?.toIso8601String().substring(0, 10),
      },
    ),
  );

  Future<BillingPage> superadminBills({
    int page = 1,
    String? query,
    String? status,
  }) async => _page(
    await _api.get(
      '/superadmin/bills',
      queryParameters: {
        'page': page,
        'perPage': 20,
        'q': ?query,
        'status': ?status,
      },
    ),
  );

  Future<BillCreationResult> createBill(PlatformBillDraft draft) async {
    final response = await _api.post('/superadmin/bills', data: draft.toJson());
    final data = asMap(response['data']);
    return BillCreationResult(
      bill: PlatformBill.fromJson(data),
      emailSent: asMap(data['email'])['sent'] == true,
      emailMessage: asNullableString(asMap(data['email'])['message']),
    );
  }

  Future<List<BillingRecipient>> billRecipients(int tenantId) async {
    final response = await _api.get(
      '/superadmin/tenants/$tenantId/billing-recipients',
    );
    return asList(
      asMap(response['data'])['recipients'],
    ).map((item) => BillingRecipient.fromJson(asMap(item))).toList();
  }

  Future<BillDocument> billDocument(
    int billId, {
    bool superadmin = false,
  }) async {
    final prefix = superadmin ? '/superadmin/bills' : '/billing/bills';
    final response = await _api.get('$prefix/$billId/document');
    return BillDocument.fromJson(asMap(response['data']));
  }

  Future<BillEmailResult> emailBill(
    int billId, {
    String? recipient,
    List<String> recipients = const [],
  }) async {
    final response = await _api.post(
      '/superadmin/bills/$billId/email',
      data: {
        if (recipient != null) 'recipient': recipient,
        'recipients': recipients,
      },
    );
    final data = asMap(response['data']);
    return BillEmailResult(
      sent: data['sent'] == true,
      message: data['message']?.toString() ?? response['message']?.toString(),
    );
  }

  Future<BillCheckoutResult> startPayment(int billId) async {
    final response = await _api.post('/billing/bills/$billId/pay', data: {});
    return BillCheckoutResult.fromJson(asMap(response['data']));
  }

  Future<PlatformBill> markPaid(
    int billId, {
    required String mode,
    String? reference,
  }) async {
    final response = await _api.post(
      '/superadmin/bills/$billId/mark-paid',
      data: {'payment_mode': mode, 'payment_reference': reference},
    );
    return PlatformBill.fromJson(asMap(response['data'])['bill']);
  }

  Future<void> cancel(int billId) =>
      _api.post('/superadmin/bills/$billId/cancel', data: {});

  Future<PaymentGatewayConfig> gatewaySettings() async {
    final response = await _api.get('/superadmin/settings/payment-gateway');
    return PaymentGatewayConfig.fromJson(
      asMap(response['data'])['paymentGateway'],
    );
  }

  Future<PaymentGatewayConfig> saveGatewaySettings(
    PaymentGatewayDraft draft,
  ) async {
    final response = await _api.put(
      '/superadmin/settings/payment-gateway',
      data: draft.toJson(),
    );
    return PaymentGatewayConfig.fromJson(
      asMap(response['data'])['paymentGateway'],
    );
  }

  BillingPage _page(Map<String, dynamic> response) {
    final paginator = asMap(asMap(response['data'])['items']);
    final raw = asList(paginator['data']);
    return BillingPage(
      items: raw.map((item) => PlatformBill.fromJson(asMap(item))).toList(),
      page: asInt(paginator['current_page'], 1),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], raw.length),
    );
  }
}
