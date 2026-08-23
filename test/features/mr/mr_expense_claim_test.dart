import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';

void main() {
  test('parses calculated MR field expense and workflow capabilities', () {
    final claim = MrExpenseClaim.fromJson({
      'id': 19,
      'employee_id': 6,
      'expense_date': '2026-08-23',
      'duty_type': 'ex_hq',
      'area_covered': 'Howrah medical belt',
      'travel_from': 'Kolkata HQ',
      'travel_to': 'Howrah',
      'allowance_amount': '450.00',
      'working_allowance_amount': 100,
      'mode_of_travel': 'Train',
      'distance_km': '32.5',
      'fare_amount': 120,
      'courier_charges': 30,
      'other_doctor_expenses': 50,
      'total_allowance': 550,
      'total_expense': 750,
      'status': 'submitted',
      'submission_count': 1,
      'can_edit': false,
      'can_delete': false,
      'can_submit': false,
      'can_rollback': true,
      'can_review': false,
      'can_revert_review': false,
      'included_in_payroll': false,
      'employee': {
        'id': 6,
        'emp_code': 'EMP006',
        'first_name': 'Meera',
        'last_name': 'Das',
        'designation': {'name': 'Medical Representative'},
        'branch': {'name': 'Kolkata'},
      },
    });

    expect(claim.employeeName, 'Meera Das');
    expect(claim.employeeCode, 'EMP006');
    expect(claim.dutyLabel, 'EX HQ');
    expect(claim.totalExpense, 750);
    expect(claim.canRollback, isTrue);
    expect(claim.canEdit, isFalse);
  });
}
