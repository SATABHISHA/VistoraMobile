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

  Future<MrPage<MrDoctor>> doctors({
    String? query,
    String? status,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/doctors',
    {'q': ?query, 'status': ?status},
    page,
    perPage,
    MrDoctor.fromJson,
  );

  Future<MrPage<MrLocation>> locations({
    String? query,
    String? status,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/locations',
    {'q': ?query, 'status': ?status},
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
    bool mine = false,
    bool upcoming = false,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/assignments',
    {
      'q': ?query,
      'status': ?status,
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
    bool mine = false,
    int page = 1,
    int perPage = 25,
  }) async => _list(
    '/mr/visit-reports',
    {'q': ?query, 'status': ?status, if (mine) 'mine': 1},
    page,
    perPage,
    MrVisitReport.fromJson,
  );

  Future<void> saveDoctor({int? id, required Map<String, dynamic> data}) =>
      id == null
      ? _api.post('/mr/doctors', data: data)
      : _api.put('/mr/doctors/$id', data: data);
  Future<void> deleteDoctor(int id) => _api.delete('/mr/doctors/$id');

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
    final response = reportId == null
        ? await _api.post(
            '/mr/assignments/$assignmentId/visit-report',
            data: data,
          )
        : await _api.put('/mr/visit-reports/$reportId', data: data);
    final item = asMap(asMap(response['data'])['item']);
    final id = asInt(item['id'], reportId ?? 0);
    await _api.post('/mr/visit-reports/$id/submit');
  }

  Future<void> approveReport(int id) =>
      _api.post('/mr/visit-reports/$id/approve');
  Future<void> rejectReport(int id, String notes) =>
      _api.post('/mr/visit-reports/$id/reject', data: {'review_notes': notes});
  Future<void> revertReport(int id) =>
      _api.post('/mr/visit-reports/$id/revert');

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
    );
  }
}

class MrPage<T> {
  const MrPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  bool get hasMore => currentPage < lastPage;
}
