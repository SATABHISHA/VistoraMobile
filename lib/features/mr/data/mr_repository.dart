import 'package:dio/dio.dart';
import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';

class MrRepository {
  const MrRepository(this._api);
  final ApiClient _api;

  Future<MrMetadata> metadata() async {
    final response = await _api.get('/mr/metadata');
    return MrMetadata.fromJson(asMap(response['data']));
  }

  Future<MrSettings> settings() async {
    final response = await _api.get('/mr/settings');
    return MrSettings.fromJson(asMap(asMap(response['data'])['settings']));
  }

  Future<MrSettings> updateSettings({
    required int maxLocationsPerDoctor,
    required bool autoConfirmVisitReports,
    required bool supervisorCanAssignSelf,
    required bool employeeCanAssignSelf,
    bool? restrictEmployeeSupervisorToState,
    Map<String, MrExpenseDutySettings>? expenseDutySettings,
  }) async {
    final data = <String, dynamic>{
      'max_locations_per_doctor': maxLocationsPerDoctor,
      'auto_confirm_visit_reports': autoConfirmVisitReports,
      'supervisor_can_assign_self': supervisorCanAssignSelf,
      'employee_can_assign_self': employeeCanAssignSelf,
      if (expenseDutySettings case final expense?)
        'expense_duty_settings': expense.map(
          (duty, settings) => MapEntry(duty, settings.toJson()),
        ),
    };
    if (restrictEmployeeSupervisorToState != null) {
      data['restrict_employee_supervisor_to_state'] =
          restrictEmployeeSupervisorToState;
    }
    final response = await _api.put('/mr/settings', data: data);
    return MrSettings.fromJson(asMap(asMap(response['data'])['settings']));
  }

  Future<String> requestStateAssignment() async {
    final response = await _api.post('/mr/state-assignment-request');
    return (response['message'] ?? 'Your administrator has been notified.')
        .toString();
  }

  Future<MrPage<MrDoctor>> doctors({
    String? query,
    String? status,
    String? date,
    int? year,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/doctors',
    {'q': ?query, 'status': ?status, 'date': ?date, 'year': ?year},
    page,
    perPage,
    MrDoctor.fromJson,
  );

  Future<MrPage<MrLocation>> locations({
    String? query,
    String? status,
    String? date,
    int? year,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/locations',
    {'q': ?query, 'status': ?status, 'date': ?date, 'year': ?year},
    page,
    perPage,
    MrLocation.fromJson,
  );

  Future<MrPage<MrTerritory>> territories({
    String? query,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/territories',
    {'q': ?query},
    page,
    perPage,
    MrTerritory.fromJson,
  );

  Future<MrPage<MrAssignment>> assignments({
    String? query,
    String? status,
    String? visitDate,
    int? year,
    int? employeeId,
    int? doctorId,
    int? locationId,
    bool mine = false,
    bool upcoming = false,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/assignments',
    {
      'q': ?query,
      'status': ?status,
      'visit_date': ?visitDate,
      'year': ?year,
      'employee_id': ?employeeId,
      'doctor_id': ?doctorId,
      'location_id': ?locationId,
      if (mine) 'mine': 1,
      if (upcoming) 'upcoming': 1,
    },
    page,
    perPage,
    MrAssignment.fromJson,
  );

  Future<MrPage<MrVisitReport>> reports({
    String? query,
    String? status,
    String? visitedDate,
    int? year,
    bool mine = false,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/visit-reports',
    {
      'q': ?query,
      'status': ?status,
      'visited_date': ?visitedDate,
      'year': ?year,
      if (mine) 'mine': 1,
    },
    page,
    perPage,
    MrVisitReport.fromJson,
  );

  Future<MrPage<MrExpenseClaim>> expenseClaims({
    String? query,
    String? status,
    String? date,
    int? month,
    int? year,
    bool mine = false,
    bool reviewable = false,
    int page = 1,
    int perPage = 10,
  }) async => _list(
    '/mr/expense-claims',
    {
      'q': ?query,
      'status': ?status,
      'date': ?date,
      'month': ?month,
      'year': ?year,
      if (mine) 'mine': 1,
      if (reviewable) 'reviewable': 1,
    },
    page,
    perPage,
    MrExpenseClaim.fromJson,
  );

  Future<Map<String, dynamic>> expenseReport({
    String? query,
    String? status,
    int? year,
    int? month,
    String? dateFrom,
    String? dateTo,
    String view = 'details',
    int page = 1,
    int perPage = 10,
  }) => _api.get(
    '/mr/expense-report',
    queryParameters: {
      'q': ?query,
      'status': ?status,
      'year': ?year,
      'month': ?month,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
      'view': view,
      'page': page,
      'per_page': perPage,
    },
  );

  Future<Response<List<int>>> exportExpenseReport({
    String? query,
    String? status,
    int? year,
    int? month,
    String? dateFrom,
    String? dateTo,
    bool details = false,
  }) => _api.download(
    '/mr/expense-report/export',
    queryParameters: {
      'q': ?query,
      'status': ?status,
      'year': ?year,
      'month': ?month,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
      if (details) 'details': 1,
    },
  );

  Future<int> saveExpenseClaim({
    int? id,
    required Map<String, dynamic> data,
  }) async {
    final response = id == null
        ? await _api.post('/mr/expense-claims', data: data)
        : await _api.put('/mr/expense-claims/$id', data: data);
    return asInt(asMap(asMap(response['data'])['item'])['id'], id ?? 0);
  }

  Future<MrExpenseGenerationReadiness> expenseGenerationReadiness() async {
    final response = await _api.get('/mr/expense-claims/generation-readiness');
    return MrExpenseGenerationReadiness.fromJson(asMap(response['data']));
  }

  Future<MrExpenseDateReadiness> expenseDateReadiness(String date) async {
    final response = await _api.get(
      '/mr/expense-claims/report-readiness?date=$date',
    );
    return MrExpenseDateReadiness.fromJson(asMap(response['data']));
  }

  Future<MrExpenseClaim> autoGenerateExpenseClaim({
    required String dutyType,
    required bool submit,
  }) async {
    final response = await _api.post(
      '/mr/expense-claims/auto-generate',
      data: {'duty_type': dutyType, 'mode': submit ? 'submit' : 'edit'},
    );
    return MrExpenseClaim.fromJson(asMap(asMap(response['data'])['item']));
  }

  Future<void> deleteExpenseClaim(int id) =>
      _api.delete('/mr/expense-claims/$id');

  Future<void> submitExpenseClaim(int id) =>
      _api.post('/mr/expense-claims/$id/submit');

  Future<void> rollbackExpenseClaim(int id, String notes) => _api.post(
    '/mr/expense-claims/$id/rollback-submission',
    data: {'rollback_notes': notes},
  );

  Future<void> approveExpenseClaim(int id, {String? notes}) => _api.post(
    '/mr/expense-claims/$id/approve',
    data: {
      if (notes != null && notes.trim().isNotEmpty)
        'review_notes': notes.trim(),
    },
  );

  Future<void> rejectExpenseClaim(int id, String notes) =>
      _api.post('/mr/expense-claims/$id/reject', data: {'review_notes': notes});

  Future<void> revertExpenseReview(int id, String notes) =>
      _api.post('/mr/expense-claims/$id/revert', data: {'review_notes': notes});

  Future<void> saveDoctor({int? id, required Map<String, dynamic> data}) =>
      id == null
      ? _api.post('/mr/doctors', data: data)
      : _api.put('/mr/doctors/$id', data: data);
  Future<void> deleteDoctor(int id) => _api.delete('/mr/doctors/$id');

  Future<List<MrLocation>> doctorLocations(int doctorId) async {
    final response = await _api.get('/mr/doctors/$doctorId/locations');
    return asList(
      asMap(response['data'])['items'],
    ).map((item) => MrLocation.fromJson(asMap(item))).toList();
  }

  Future<void> updateDoctorLocations(int doctorId, List<int> locationIds) =>
      _api.put(
        '/mr/doctors/$doctorId/locations',
        data: {'location_ids': locationIds},
      );

  Future<void> saveLocation({int? id, required Map<String, dynamic> data}) =>
      id == null
      ? _api.post('/mr/locations', data: data)
      : _api.put('/mr/locations/$id', data: data);
  Future<void> deleteLocation(int id) => _api.delete('/mr/locations/$id');

  Future<void> saveTerritory({int? id, required Map<String, dynamic> data}) =>
      id == null
      ? _api.post('/mr/territories', data: data)
      : _api.put('/mr/territories/$id', data: data);
  Future<void> deleteTerritory(int id) => _api.delete('/mr/territories/$id');

  Future<void> saveAssignment({int? id, required Map<String, dynamic> data}) =>
      id == null
      ? _api.post('/mr/assignments', data: data)
      : _api.put('/mr/assignments/$id', data: data);
  Future<void> cancelAssignment(int id) =>
      _api.post('/mr/assignments/$id/cancel');
  Future<void> deleteAssignment(int id) => _api.delete('/mr/assignments/$id');

  Future<void> saveAndSubmitReport({
    required int assignmentId,
    int? reportId,
    required Map<String, dynamic> data,
  }) async {
    final id = await saveReport(
      assignmentId: assignmentId,
      reportId: reportId,
      data: data,
    );
    await submitReport(id);
  }

  Future<int> saveReport({
    required int assignmentId,
    int? reportId,
    required Map<String, dynamic> data,
  }) async {
    final response = reportId == null
        ? await _api.post(
            '/mr/assignments/$assignmentId/visit-report',
            data: data,
          )
        : await _api.put('/mr/visit-reports/$reportId', data: data);
    final item = asMap(asMap(response['data'])['item']);
    return asInt(item['id'], reportId ?? 0);
  }

  Future<void> submitReport(int id) =>
      _api.post('/mr/visit-reports/$id/submit');

  Future<void> rollbackSubmission(int id, String notes) => _api.post(
    '/mr/visit-reports/$id/rollback-submission',
    data: {'rollback_notes': notes},
  );

  Future<void> approveReport(int id) =>
      _api.post('/mr/visit-reports/$id/approve');
  Future<void> rejectReport(int id, String notes) =>
      _api.post('/mr/visit-reports/$id/reject', data: {'review_notes': notes});
  Future<void> revertReport(int id) =>
      _api.post('/mr/visit-reports/$id/revert');

  Future<MrPage<MrAuditEvent>> auditLogs({
    String? query,
    String? action,
    String? date,
    int? year,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/audit-logs',
    {'q': ?query, 'action': ?action, 'date': ?date, 'year': ?year},
    page,
    perPage,
    MrAuditEvent.fromJson,
  );

  Future<MrPage<T>> _list<T>(
    String path,
    Map<String, dynamic> query,
    int pageNumber,
    int perPage,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final response = await _api.get(
      path,
      queryParameters: {...query, 'page': pageNumber, 'per_page': perPage},
    );
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return MrPage<T>(
      items: asList(
        page['data'] ?? data['items'],
      ).map((item) => parser(asMap(item))).toList(),
      currentPage: asInt(page['current_page'], pageNumber),
      lastPage: asInt(page['last_page'], 1),
      total: asInt(page['total'], asList(page['data']).length),
    );
  }
}

class MrPage<T> {
  const MrPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage;
}
