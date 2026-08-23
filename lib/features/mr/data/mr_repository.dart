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

  Future<MrSettings> updateSettings(int maxLocationsPerDoctor) async {
    final response = await _api.put(
      '/mr/settings',
      data: {'max_locations_per_doctor': maxLocationsPerDoctor},
    );
    return MrSettings.fromJson(asMap(asMap(response['data'])['settings']));
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
