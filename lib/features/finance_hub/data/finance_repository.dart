import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/finance_hub/domain/finance_models.dart';

class FinanceRepository {
  const FinanceRepository(this.api);
  final ApiClient api;
  Future<FinanceSettings> settings() async => FinanceSettings.fromJson(
    asMap(asMap((await api.get('/finance-hub/settings'))['data'])['settings']),
  );
  Future<void> updateSettings(FinanceSettings value) =>
      api.put('/finance-hub/settings', data: value.toJson());
  Future<Map<String, dynamic>> summary({required int year, int? month}) async =>
      asMap(
        (await api.get(
          '/finance-hub/summary',
          queryParameters: {'year': year, 'month': ?month},
        ))['data'],
      );
  Future<FinancePage> entries({
    required String type,
    String? query,
    DateTime? date,
    int? month,
    String? paymentMode,
    required int year,
    int page = 1,
  }) async {
    final body = await api.get(
      '/finance-hub/entries',
      queryParameters: {
        'type': type,
        'q': ?query,
        'date': ?date?.toIso8601String().split('T').first,
        'month': ?month,
        'payment_mode': ?paymentMode,
        'year': year,
        'page': page,
        'perPage': 10,
      },
    );
    final p = asMap(asMap(body['data'])['items']);
    final raw = asList(p['data']);
    return FinancePage(
      raw.map((x) => FinanceEntry.fromJson(asMap(x))).toList(),
      asInt(p['current_page'], 1),
      asInt(p['last_page'], 1),
      asInt(p['total'], raw.length),
      filteredTotalAmount: asDouble(
        asMap(body['data'])['filtered_total_amount'],
      ),
    );
  }

  Future<void> save(Map<String, dynamic> data, {int? id}) => id == null
      ? api.post('/finance-hub/entries', data: data)
      : api.put('/finance-hub/entries/$id', data: data);
  Future<void> delete(int id) => api.delete('/finance-hub/entries/$id');
  Future<Map<String, dynamic>> invoice(int id) async =>
      asMap((await api.get('/finance-hub/invoices/$id'))['data']);
  Future<void> generateInvoice(int entryId, DateTime date) => api.post(
    '/finance-hub/entries/$entryId/invoice',
    data: {'invoice_date': date.toIso8601String().split('T').first},
  );
  Future<void> emailInvoice(int invoiceId, String to) =>
      api.post('/finance-hub/invoices/$invoiceId/email', data: {'to': to});
  Future<List<Map<String, dynamic>>> audit() async {
    final response = await api.get(
      '/finance-hub/audit-logs',
      queryParameters: {'perPage': 50},
    );
    return asList(
      asMap(asMap(response['data'])['items'])['data'],
    ).map((item) => asMap(item)).toList();
  }

  Future<List<int>> export({
    required String type,
    required int year,
    int? month,
    String? paymentMode,
  }) async =>
      (await api.download(
        '/finance-hub/export',
        queryParameters: {
          'type': type,
          'year': year,
          'month': ?month,
          'payment_mode': ?paymentMode,
        },
      )).data ??
      const [];
}
