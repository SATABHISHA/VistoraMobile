import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';

void main() {
  test('parses server-authoritative attendance deduction summary', () {
    final payroll = PayrollEmployeeSummary.fromJson({
      'id': 91,
      'employee_id': 7,
      'status': 'initiated',
      'base_amount': '60000.00',
      'statutory_deduction_amount': '3000.00',
      'attendance_deduction_amount': '6000.00',
      'arrears_amount': '500.00',
      'net_payable': '51500.00',
      'employee': {
        'emp_code': 'EMP007',
        'work_email': 'asha@example.test',
        'mobile': '+91 9999999999',
        'first_name': 'Asha',
        'last_name': 'Roy',
      },
      'gross_amount': '65000.00',
      'payload_snapshot_json': {
        'attendanceDeductionDays': 3,
        'paidLeaveDays': 1,
        'pendingLeaveDays': 1,
        'missingAttendanceDays': 2,
        'holidayDays': 1,
      },
    });

    expect(payroll.employeeName, 'Asha Roy');
    expect(payroll.employeeCode, 'EMP007');
    expect(payroll.employeeEmail, 'asha@example.test');
    expect(payroll.employeeMobile, '+91 9999999999');
    expect(payroll.grossAmount, 65000);
    expect(payroll.deductionDays, 3);
    expect(payroll.paidLeaveDays, 1);
    expect(payroll.pendingLeaveDays, 1);
    expect(payroll.missingAttendanceDays, 2);
    expect(payroll.holidayDays, 1);
    expect(payroll.attendanceDeduction, 6000);
    expect(payroll.netPayable, 51500);
  });
}
