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

  Future<void> create({
    required String firstName,
    required String lastName,
    required String role,
    String? workEmail,
    String? mobile,
  }) => _api.post(
    '/employees',
    data: {
      'auto_emp_code': true,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'role_type': role,
      if (workEmail?.trim().isNotEmpty == true) 'work_email': workEmail!.trim(),
      if (mobile?.trim().isNotEmpty == true) 'mobile': mobile!.trim(),
    },
  );

  Future<void> update({
    required int id,
    required String firstName,
    required String lastName,
    required String role,
    String? workEmail,
    String? mobile,
  }) => _api.put(
    '/employees/$id',
    data: {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'role_type': role,
      'work_email': workEmail?.trim().isEmpty == true
          ? null
          : workEmail?.trim(),
      'mobile': mobile?.trim().isEmpty == true ? null : mobile?.trim(),
    },
  );

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
}
