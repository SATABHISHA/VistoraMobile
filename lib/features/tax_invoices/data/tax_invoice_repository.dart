import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/tax_invoices/domain/tax_invoice_models.dart';

class TaxInvoiceRepository {
  const TaxInvoiceRepository(this._api);

  final ApiClient _api;

  Future<TaxInvoicePage> list({
    String? query,
    int? month,
    int? year,
    int page = 1,
    int perPage = 12,
  }) async {
    final response = await _api.get(
      '/tax-invoices',
      queryParameters: {
        'q': ?query,
        'month': ?month,
        'year': ?year,
        'page': page,
        'perPage': perPage,
      },
    );
    final paginator = asMap(asMap(response['data'])['items']);
    final raw = asList(paginator['data']);
    return TaxInvoicePage(
      items: raw
          .map((item) => TaxInvoiceSummary.fromJson(asMap(item)))
          .toList(),
      page: asInt(paginator['current_page'], 1),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], raw.length),
    );
  }

  Future<TaxInvoiceDetail> show(int invoiceId) async {
    final response = await _api.get('/tax-invoices/$invoiceId');
    return TaxInvoiceDetail.fromJson(asMap(response['data']));
  }
}
