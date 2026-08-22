import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/leave/domain/leave_models.dart';

class LeaveRepository {
  const LeaveRepository(this._api);
  final ApiClient _api;

  Future<LeaveSummary> mySummary({int? year, int? month}) async =>
      LeaveSummary.fromResponse(
        await _api.get(
          '/leave/summary/me',
          queryParameters: {'year': ?year, 'month': ?month},
        ),
      );

  Future<List<LeaveRequestItem>> requests({
    int perPage = 50,
    String? status,
    String? query,
  }) async {
    final response = await _api.get(
      '/leave',
      queryParameters: {'perPage': perPage, 'status': ?status, 'q': ?query},
    );
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return asList(
      page['data'] ?? data['items'],
    ).map((item) => LeaveRequestItem.fromJson(asMap(item))).toList();
  }

  Future<void> apply({
    required int leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) => _api.post(
    '/leave',
    data: {
      'leave_type_id': leaveTypeId,
      'start_date': _date(startDate),
      'end_date': _date(endDate),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    },
  );

  Future<List<LeaveApprovalOption>> approvalOptions(int leaveId) async {
    final response = await _api.get('/leave/$leaveId/approval-options');
    return asList(
      asMap(response['data'])['options'],
    ).map((item) => LeaveApprovalOption.fromJson(asMap(item))).toList();
  }

  Future<void> approve(int leaveId, {int? leaveTypeId, String? note}) =>
      _api.post(
        '/leave/$leaveId/approve',
        data: {'leave_type_id': ?leaveTypeId, 'note': ?note},
      );

  Future<void> reject(int leaveId, {String? note}) =>
      _api.post('/leave/$leaveId/reject', data: {'note': ?note});

  Future<void> revert(int leaveId, {String? note}) =>
      _api.post('/leave/$leaveId/revert', data: {'note': ?note});

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
