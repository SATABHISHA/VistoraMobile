import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/leave/domain/leave_models.dart';

void main() {
  test('parses employee leave summary and type balances', () {
    final value = LeaveSummary.fromResponse({
      'data': {
        'leave': {
          'credited_total': 12,
          'used_total': 2.5,
          'remaining_total': 9.5,
          'pending_count': 1,
          'approved_count': 2,
          'rejected_count': 0,
          'breakup': [
            {
              'leave_type_id': 3,
              'code': 'CL',
              'name': 'Casual Leave',
              'credited': 12,
              'used': 2.5,
              'remaining': 9.5,
            },
          ],
        },
        'attendance': {'absent_month': 1},
      },
    });

    expect(value.remainingTotal, 9.5);
    expect(value.types.single.id, 3);
    expect(value.absentMonth, 1);
  });

  test('parses team leave identity and approval balance option', () {
    final request = LeaveRequestItem.fromJson({
      'id': 19,
      'start_date': '2026-08-24',
      'end_date': '2026-08-25',
      'days': 2,
      'status': 'pending',
      'employee': {
        'id': 7,
        'emp_code': 'EMP007',
        'first_name': 'Kallol',
        'last_name': 'Acharya',
      },
      'leave_type': {'name': 'Paid Leave'},
    });
    final option = LeaveApprovalOption.fromJson({
      'leave_type_id': 3,
      'name': 'Paid Leave',
      'code': 'PL',
      'balance': 5,
      'after_approval': 3,
    });

    expect(request.employeeId, 7);
    expect(request.employeeName, 'Kallol Acharya');
    expect(request.employeeCode, 'EMP007');
    expect(option.afterApproval, 3);
  });
}
