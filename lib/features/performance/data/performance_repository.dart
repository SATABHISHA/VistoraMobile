import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/performance/domain/performance_models.dart';

class PerformanceRepository {
  const PerformanceRepository(this._api);

  final ApiClient _api;

  Future<PerformancePage> page({int? employeeId, int? month, int? year}) async {
    final response = await _api.get(
      '/performance',
      queryParameters: {
        'perPage': 200,
        ...?employeeId == null ? null : {'employee_id': employeeId},
        ...?month == null ? null : {'month': month},
        ...?year == null ? null : {'year': year},
      },
    );
    final data = asMap(response['data']);
    final items = asMap(data['items']);
    final me = asMap(data['me']);
    final employees = asList(
      data['employees'],
    ).map((item) => PerformanceEmployeeOption.fromJson(asMap(item))).toList();
    return PerformancePage(
      reviews: asList(
        items['data'] ?? data['items'],
      ).map((item) => PerformanceReviewItem.fromJson(asMap(item))).toList(),
      employees: employees,
      reviewableEmployees: asList(
        data['reviewable_employees'],
      ).map((item) => PerformanceEmployeeOption.fromJson(asMap(item))).toList(),
      currentEmployeeId: asInt(me['id']) == 0 ? null : asInt(me['id']),
      canManage: data['can_manage'] == true,
    );
  }

  Future<void> saveReview({
    required int employeeId,
    required int month,
    required int year,
    required Map<String, int> ratings,
    String? comment,
  }) async {
    await _api.post(
      '/performance/reviews',
      data: {
        'employee_id': employeeId,
        'review_month': month,
        'review_year': year,
        ...ratings,
        'comment': comment,
      },
    );
  }

  Future<void> updateReview({
    required int reviewId,
    required int employeeId,
    required int month,
    required int year,
    required Map<String, int> ratings,
    String? comment,
  }) async {
    await _api.put(
      '/performance/reviews/$reviewId',
      data: {
        'employee_id': employeeId,
        'review_month': month,
        'review_year': year,
        ...ratings,
        'comment': comment,
      },
    );
  }

  Future<void> deleteReview(int reviewId) async {
    await _api.delete('/performance/reviews/$reviewId');
  }
}
