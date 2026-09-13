import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/employees/domain/employee_models.dart';

class EmployeeManagementRepository {
  const EmployeeManagementRepository(this._api);
  final ApiClient _api;

  Future<EmployeePage> employees({
    String? query,
    String? status,
    int page = 1,
    int perPage = 12,
  }) async {
    final response = await _api.get(
      '/employees',
      queryParameters: {
        'q': ?query,
        'status': ?status,
        'page': page,
        'perPage': perPage,
      },
    );
    final paginator = asMap(asMap(response['data'])['items']);
    final raw = asList(paginator['data']);
    return EmployeePage(
      items: raw.map((item) => ManagedEmployee.fromJson(asMap(item))).toList(),
      page: asInt(paginator['current_page'], 1),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], raw.length),
    );
  }

  Future<void> create(Map<String, dynamic> data) =>
      _api.post('/employees', data: {'auto_emp_code': true, ...data});

  Future<void> update({required int id, required Map<String, dynamic> data}) =>
      _api.put('/employees/$id', data: data);

  Future<void> setActive(ManagedEmployee employee, bool active) => _api.post(
    '/employees/${employee.id}/${active ? 'activate' : 'deactivate'}',
  );

  Future<void> credentials({
    required int employeeId,
    required String username,
    required String email,
    required String password,
  }) => _api.post(
    '/employees/$employeeId/credentials',
    data: {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': password,
    },
  );

  Future<String> createInvitation({
    required String email,
    String? employeeName,
    String validityType = '7-days',
  }) async {
    final response = await _api.post(
      '/employee-invitations',
      data: {
        'email': email.trim(),
        if (employeeName?.trim().isNotEmpty == true)
          'employee_name': employeeName!.trim(),
        'validity_type': validityType,
      },
    );
    return asMap(response['data'])['invitationUrl']?.toString() ?? '';
  }

  Future<({bool sent, String message})> emailInvitation({
    required String token,
    String? email,
  }) async {
    final response = await _api.post(
      '/employee-invitations/$token/email',
      data: {if (email?.trim().isNotEmpty == true) 'email': email!.trim()},
    );
    return (
      sent: asMap(response['data'])['sent'] == true,
      message: response['message']?.toString() ?? 'Unable to send onboarding email.',
    );
  }

  Future<({bool sent, String message})> emailCredentials({
    required int employeeId,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/employees/$employeeId/credentials/email',
      data: {'username': username.trim(), 'email': email.trim(), 'password': password},
    );
    return (
      sent: asMap(response['data'])['sent'] == true,
      message: response['message']?.toString() ?? 'Unable to send login email.',
    );
  }
}
