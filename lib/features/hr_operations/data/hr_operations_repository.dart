import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/hr_operations/domain/hr_operations_models.dart';

class HrOperationsRepository {
  const HrOperationsRepository(this._api);
  final ApiClient _api;

  Future<List<HrEmployee>> employees({String? query}) async {
    final response = await _api.get(
      '/employees',
      queryParameters: {'q': ?query, 'perPage': 100},
    );
    return _pageItems(
      response,
    ).map((item) => HrEmployee.fromJson(asMap(item))).toList();
  }

  Future<HrPage<RecruitmentCandidate>> candidates({
    String? query,
    String? status,
    int page = 1,
    int perPage = 10,
  }) async => _page(
    await _api.get(
      '/recruitment',
      queryParameters: {
        'search': ?query,
        'status': ?status,
        'page': page,
        'per_page': perPage,
      },
    ),
    RecruitmentCandidate.fromJson,
  );

  Future<void> createCandidate(Map<String, dynamic> data) =>
      _api.post('/recruitment', data: data);

  Future<void> pipelineAction(int candidateId, String action) => _api.post(
    '/recruitment/$candidateId/pipeline-action',
    data: {'action': action},
  );

  Future<void> scheduleInterview({
    required int candidateId,
    required DateTime scheduledAt,
    required List<int> panelistUserIds,
    required String mode,
    String? notes,
  }) => _api.post(
    '/recruitment/candidates/$candidateId/interviews',
    data: {
      'scheduled_at': scheduledAt.toIso8601String(),
      'panelist_user_ids': panelistUserIds,
      'mode': mode,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    },
  );

  Future<List<LetterTemplate>> offerTemplates() async {
    final response = await _api.get('/recruitment/offer-templates');
    return asList(
      asMap(response['data'])['items'],
    ).map((item) => LetterTemplate.fromJson(asMap(item))).toList();
  }

  Future<void> saveOfferTemplate({
    int? id,
    required String name,
    required String bodyHtml,
  }) => id == null
      ? _api.post(
          '/recruitment/offer-templates',
          data: {'name': name, 'body_html': bodyHtml},
        )
      : _api.put(
          '/recruitment/offer-templates/$id',
          data: {'name': name, 'body_html': bodyHtml},
        );

  Future<HrPage<RecruitmentOffer>> offers({
    String? query,
    int? month,
    int? year,
    int page = 1,
  }) async => _page(
    await _api.get(
      '/recruitment/offers',
      queryParameters: {
        'q': ?query,
        'month': ?month,
        'year': ?year,
        'page': page,
        'per_page': 10,
      },
    ),
    RecruitmentOffer.fromJson,
  );

  Future<void> generateOffer({
    required int candidateId,
    required int templateId,
    required String position,
    required DateTime startDate,
    required double ctc,
  }) => _api.post(
    '/recruitment/candidates/$candidateId/offer-letter',
    data: {
      'template_id': templateId,
      'position': position,
      'start_date': _date(startDate),
      'offered_ctc': ctc,
    },
  );

  Future<void> updateOfferStatus(int offerId, String status) => _api.post(
    '/recruitment/offers/$offerId/status',
    data: {'status': status},
  );

  Future<List<LetterTemplate>> appointmentTemplates() async {
    final response = await _api.get('/appointment-templates');
    return asList(
      asMap(response['data'])['items'],
    ).map((item) => LetterTemplate.fromJson(asMap(item))).toList();
  }

  Future<HrPage<EmployeeLetter>> appointmentLetters({int page = 1}) async =>
      _page(
        await _api.get(
          '/employee-documents',
          queryParameters: {'page': page, 'perPage': 10},
        ),
        EmployeeLetter.fromJson,
      );

  Future<void> generateAppointment({
    required int employeeId,
    required int templateId,
    String? designation,
    DateTime? joiningDate,
    String? place,
  }) => _api.post(
    '/employees/$employeeId/appointment-letters',
    data: {
      'template_id': templateId,
      if (designation?.trim().isNotEmpty == true)
        'designation': designation!.trim(),
      if (joiningDate != null) 'joining_date': _date(joiningDate),
      if (place?.trim().isNotEmpty == true) 'place': place!.trim(),
    },
  );

  Future<HrPage<FinalSettlementItem>> settlements({int page = 1}) async =>
      _page(
        await _api.get(
          '/final-settlements',
          queryParameters: {'page': page, 'perPage': 10},
        ),
        FinalSettlementItem.fromJson,
      );

  Future<Map<String, dynamic>> calculateSettlement({
    required int employeeId,
    required DateTime resignationDate,
    required DateTime lastWorkingDate,
  }) async {
    final response = await _api.post(
      '/employees/$employeeId/final-settlement/calculate',
      data: {
        'resignation_date': _date(resignationDate),
        'last_working_date': _date(lastWorkingDate),
      },
    );
    return asMap(asMap(response['data'])['calculation']);
  }

  Future<void> saveSettlement({
    required int employeeId,
    required Map<String, dynamic> data,
  }) => _api.put('/employees/$employeeId/final-settlement', data: data);

  Future<void> updateSettlementStatus(int id, String status) =>
      _api.post('/final-settlements/$id/status', data: {'status': status});

  Future<void> revokeSettlement(int id) =>
      _api.post('/final-settlements/$id/revoke');

  Future<void> disburseSettlements(List<int> ids) =>
      _api.post('/final-settlements/disburse', data: {'settlement_ids': ids});

  HrPage<T> _page<T>(
    Map<String, dynamic> response,
    T Function(Map<String, dynamic>) parser,
  ) {
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    final raw = asList(page['data'] ?? data['items']);
    return HrPage(
      items: raw.map((item) => parser(asMap(item))).toList(),
      page: asInt(page['current_page'], 1),
      lastPage: asInt(page['last_page'], 1),
      total: asInt(page['total'], raw.length),
    );
  }

  static List<dynamic> _pageItems(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return asList(page['data'] ?? data['items']);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
