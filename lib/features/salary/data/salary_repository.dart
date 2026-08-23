import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/salary/domain/salary_models.dart';

class SalaryRepository {
  const SalaryRepository(this._api);

  final ApiClient _api;

  Future<SalaryRosterPage> roster({
    required int year,
    String? query,
    int page = 1,
    int perPage = 12,
  }) async {
    final response = await _api.get(
      '/employees-salary-structures',
      queryParameters: {
        'year': year,
        'paginated': 1,
        'q': ?query,
        'page': page,
        'perPage': perPage,
      },
    );
    final data = asMap(response['data']);
    final paginator = asMap(data['items']);
    final items = asList(paginator['data']);
    return SalaryRosterPage(
      items: items
          .map((item) => SalaryRosterEmployee.fromJson(asMap(item)))
          .toList(),
      page: asInt(paginator['current_page'], 1),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], items.length),
      year: asInt(data['year'], year),
    );
  }

  Future<SalaryEmployeeDetail> detail(int employeeId) async {
    final response = await _api.get('/employees/$employeeId/salary-structures');
    return SalaryEmployeeDetail.fromJson(asMap(response['data']));
  }

  Future<void> revise({
    required int employeeId,
    required int year,
    required DateTime revisionDate,
    required double incrementAmount,
    DateTime? arrearEffectiveDate,
  }) => _api.post(
    '/employees/$employeeId/salary-revisions',
    data: {
      'year': year,
      'revision_date': _date(revisionDate),
      'increment_amount': incrementAmount,
      if (arrearEffectiveDate != null)
        'arrear_effective_date': _date(arrearEffectiveDate),
    },
  );

  Future<void> rollback({required int employeeId, required int revisionId}) =>
      _api.delete('/employees/$employeeId/salary-revisions/$revisionId');

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
