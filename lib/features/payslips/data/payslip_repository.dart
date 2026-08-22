import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/payslips/domain/payslip.dart';

class PayslipRepository {
  const PayslipRepository(this._api);
  final ApiClient _api;

  Future<PayslipCollection> mine({required int year}) async {
    final response = await _api.get(
      '/payroll/me/payslips',
      queryParameters: {'year': year, 'perPage': 50},
    );
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return PayslipCollection(
      companyName: data['company_name']?.toString() ?? 'Company',
      items: asList(
        page['data'] ?? data['items'],
      ).map((item) => Payslip.fromJson(asMap(item))).toList(),
    );
  }
}
