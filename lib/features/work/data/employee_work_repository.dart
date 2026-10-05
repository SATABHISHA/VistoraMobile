import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/work/domain/employee_work_models.dart';

class EmployeeWorkRepository {
  const EmployeeWorkRepository(this._api);
  final ApiClient _api;

  Future<List<EmployeeProject>> projects() async {
    final response = await _api.get(
      '/projects',
      queryParameters: {'perPage': 50},
    );
    return _items(
      response,
    ).map((item) => EmployeeProject.fromJson(asMap(item))).toList();
  }

  Future<ProjectManagementPage> projectManagement() async {
    final response = await _api.get(
      '/projects',
      queryParameters: {'perPage': 100},
    );
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    final projects = asList(
      page['data'] ?? data['items'],
    ).map((item) => EmployeeProject.fromJson(asMap(item))).toList();
    final me = asMap(data['me']);
    final currentId = asInt(me['id']);
    return ProjectManagementPage(
      projects: projects,
      assignableEmployees: asList(
        data['assignable_employees'],
      ).map((item) => ProjectMemberOption.fromJson(asMap(item))).toList(),
      currentEmployeeId: currentId == 0 ? null : currentId,
    );
  }

  Future<void> createProject({
    required String name,
    DateTime? startDate,
    required DateTime endDate,
    required List<int> employeeIds,
    int? supervisorId,
  }) async {
    await _api.post(
      '/projects',
      data: {
        'name': name,
        'supervisor_id': supervisorId,
        'start_date': startDate == null ? null : _date(startDate),
        'end_date': _date(endDate),
        'status': 'active',
        'health_status': 'green',
        'assignments': employeeIds
            .map(
              (employeeId) => {
                'employee_id': employeeId,
                'role': 'Member',
                'status': 'assigned',
              },
            )
            .toList(),
      },
    );
  }

  Future<void> addProjectMember({
    required int projectId,
    required int employeeId,
  }) async {
    await _api.post(
      '/projects/$projectId/members',
      data: {'employee_id': employeeId, 'role': 'Member', 'status': 'assigned'},
    );
  }

  Future<void> removeProjectMember({
    required int projectId,
    required int employeeId,
  }) async {
    await _api.delete('/projects/$projectId/members/$employeeId');
  }

  Future<void> changeProjectSupervisor({
    required int projectId,
    int? supervisorId,
  }) async {
    await _api.patch(
      '/projects/$projectId',
      data: {'supervisor_id': supervisorId},
    );
  }

  Future<void> submitProjectUpdate({
    required int projectId,
    required int assignmentId,
    required String periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
    required int progressPercent,
    String? achievements,
    String? blockers,
    String? nextPlan,
  }) => _api.post(
    '/projects/$projectId/updates',
    data: {
      'assignment_id': assignmentId,
      'period_type': periodType,
      'period_start': _date(periodStart),
      'period_end': periodEnd == null ? null : _date(periodEnd),
      'progress_percent': progressPercent,
      'achievements': achievements,
      'blockers': blockers,
      'next_plan': nextPlan,
    },
  );

  Future<void> completeProject(int projectId) async {
    await _api.post('/projects/$projectId/complete');
  }

  Future<void> rollbackProject(int projectId) async {
    await _api.post('/projects/$projectId/rollback');
  }

  Future<List<InterviewTask>> interviews() async {
    final page = await interviewPage(view: 'all', perPage: 100);
    return page.items;
  }

  Future<InterviewTaskPage> interviewPage({
    String view = 'assigned',
    String? query,
    String? dateFrom,
    String? dateTo,
    String? mode,
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await _api.get(
      '/recruitment/interviews/mine',
      queryParameters: {
        'view': view,
        'page': page,
        'per_page': perPage,
        'search': ?query,
        'date_from': ?dateFrom,
        'date_to': ?dateTo,
        'mode': ?mode,
      },
    );
    final data = asMap(response['data']);
    final pageData = asMap(data['items']);
    final items = asList(
      pageData['data'] ?? data['items'],
    ).map((item) => InterviewTask.fromJson(asMap(item))).toList();
    return InterviewTaskPage(
      items: items,
      page: asInt(pageData['current_page']) == 0
          ? 1
          : asInt(pageData['current_page']),
      lastPage: asInt(pageData['last_page']) == 0
          ? 1
          : asInt(pageData['last_page']),
      total: asInt(pageData['total']),
    );
  }

  Future<String> downloadResume({
    required int candidateId,
    required String fileName,
  }) async {
    final response = await _api.download(
      '/recruitment/candidates/$candidateId/resume',
    );
    final directory = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final output = File('${directory.path}${Platform.pathSeparator}$safeName');
    await output.writeAsBytes(response.data ?? const <int>[], flush: true);
    return output.path;
  }

  Future<void> submitInterviewFeedback({
    required int interviewId,
    required int rating,
    required String recommendation,
    required String feedback,
  }) => _api.post(
    '/recruitment/interviews/$interviewId/feedback',
    data: {
      'rating': rating,
      'recommendation': recommendation,
      'feedback': feedback,
    },
  );

  static List<dynamic> _items(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return asList(page['data'] ?? data['items']);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
