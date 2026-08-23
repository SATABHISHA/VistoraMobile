import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/salary/domain/salary_models.dart';

void main() {
  test('parses salary roster and revision details', () {
    final employee = SalaryRosterEmployee.fromJson({
      'employee_id': 7,
      'emp_code': 'EMP007',
      'name': 'Asha Rao',
      'status': 'active',
      'salary': {
        'id': 4,
        'year': 2026,
        'pay_group_name': 'Standard',
        'ctc_annual': '600000.00',
        'gross_monthly': 48000,
        'deduction_monthly': 3000,
        'net_monthly': 45000,
        'pay_group_snapshot_json': {'name': 'Standard', 'components': []},
      },
    });
    final revision = SalaryRevisionRecord.fromJson({
      'id': 9,
      'year': 2026,
      'revision_date': '2026-08-01',
      'increment_amount': 60000,
      'action_status': 'applied',
      'old_net_monthly': 40000,
      'new_net_monthly': 45000,
      'arrears_due': 10000,
      'arrears_status': 'pending',
    });

    expect(employee.salary?.ctcAnnual, 600000);
    expect(employee.salary?.netMonthly, 45000);
    expect(revision.canRollback, isTrue);
    expect(revision.arrearsDue, 10000);
  });
}
