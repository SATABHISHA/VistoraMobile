import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/employees/domain/employee_models.dart';

void main() {
  test('parses employee identity, organisation and salary snapshot', () {
    final employee = ManagedEmployee.fromJson({
      'id': 6,
      'emp_code': 'EMP006',
      'first_name': 'Meera',
      'last_name': 'Das',
      'role_type': 'Employee',
      'status': 'active',
      'work_email': 'meera@example.test',
      'branch': {'name': 'Kolkata HQ'},
      'department': {'name': 'Field Sales'},
      'designation': {'name': 'Medical Representative'},
      'user': {'username': 'meera'},
      'current_salary': {'ctc_annual': '420000.00', 'net_monthly': 32000},
    });

    expect(employee.name, 'Meera Das');
    expect(employee.code, 'EMP006');
    expect(employee.hasCredentials, isTrue);
    expect(employee.designation, 'Medical Representative');
    expect(employee.netMonthly, 32000);
  });
}
