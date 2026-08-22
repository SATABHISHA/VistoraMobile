import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/payslips/domain/payslip.dart';

void main() {
  test('parses nested Laravel payslip response', () {
    final value = Payslip.fromJson({
      'id': 12,
      'generated_at': '2026-08-01T12:00:00Z',
      'payroll_employee': {
        'gross_amount': 50000,
        'base_amount': 45000,
        'statutory_deduction_amount': 2000,
        'attendance_deduction_amount': 1000,
        'arrears_amount': 500,
        'net_payable': 47500,
        'employee': {
          'emp_code': 'EMP001',
          'first_name': 'Riya',
          'last_name': 'Sen',
        },
        'payroll_cycle': {'year': 2026, 'month': 7},
      },
    });

    expect(value.employeeName, 'Riya Sen');
    expect(value.totalDeductions, 3000);
    expect(value.netPayable, 47500);
  });
}
