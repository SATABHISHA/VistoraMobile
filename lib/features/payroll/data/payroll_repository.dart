import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';

class PayrollRepository {
  const PayrollRepository(this._api);
  final ApiClient _api;

  Future<PayrollCollection> cycles({
    required int year,
    required int month,
  }) async {
    final response = await _api.get(
      '/payroll/cycles',
      queryParameters: {'year': year, 'month': month, 'perPage': 5},
    );
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    final company = asMap(data['company']);
    return PayrollCollection(
      companyName: company['company_name']?.toString() ?? 'Company',
      mrEnabled: company['mr_enabled'] == true || company['mr_enabled'] == 1,
      cycles: asList(
        page['data'] ?? data['items'],
      ).map((item) => PayrollCycleSummary.fromJson(asMap(item))).toList(),
    );
  }

  Future<void> initiate({required int year, required int month}) => _api.post(
    '/payroll/cycles/initiate',
    data: {'year': year, 'month': month},
  );

  Future<void> calculateDeductions(int cycleId, {List<int>? employeeIds}) =>
      _api.post(
        '/payroll/cycles/$cycleId/calculate-deductions',
        data: {'employee_ids': ?employeeIds},
      );

  Future<void> rollbackDeductions(int cycleId, {List<int>? employeeIds}) =>
      _api.post(
        '/payroll/cycles/$cycleId/rollback-deductions',
        data: {'employee_ids': ?employeeIds},
      );

  Future<void> calculateMrExpenses(int cycleId, {List<int>? employeeIds}) =>
      _api.post(
        '/payroll/cycles/$cycleId/calculate-mr-expenses',
        data: {'employee_ids': ?employeeIds},
      );

  Future<void> rollbackMrExpenses(int cycleId, {List<int>? employeeIds}) =>
      _api.post(
        '/payroll/cycles/$cycleId/rollback-mr-expenses',
        data: {'employee_ids': ?employeeIds},
      );

  Future<void> rollbackCycle(int cycleId) =>
      _api.post('/payroll/cycles/$cycleId/rollback');

  Future<void> putOnHold(int cycleId) =>
      _api.post('/payroll/cycles/$cycleId/on-hold');

  Future<void> release(int cycleId) async {
    final taskResponse = await _api.post(
      '/payroll/cycles/$cycleId/release-request',
    );
    final task = asMap(asMap(taskResponse['data'])['task']);
    await _api.post(
      '/payroll/cycles/$cycleId/release',
      data: {'task_id': asInt(task['id'])},
    );
  }

  Future<void> addArrears({
    required int cycleId,
    required int employeeId,
    required double amount,
    String? reason,
  }) => _api.post(
    '/payroll/cycles/$cycleId/arrears',
    data: {
      'employee_ids': [employeeId],
      'amount': amount,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    },
  );
}
