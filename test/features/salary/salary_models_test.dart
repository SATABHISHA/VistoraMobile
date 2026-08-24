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

  test('calculates the Laravel default pay group formulas', () {
    final designer = SalaryDesignerState.defaults;
    final breakup = designer.calculate(designer.payGroups.first, 600000);

    expect(breakup.lines, hasLength(7));
    expect(
      breakup.lines
          .singleWhere((line) => line.component.code == 'BASIC')
          .monthly,
      20000,
    );
    expect(
      breakup.lines
          .singleWhere((line) => line.component.code == 'PF_EMP')
          .monthly,
      2400,
    );
    expect(breakup.grossMonthly, 46250);
    expect(breakup.deductionMonthly, 2600);
    expect(breakup.netMonthly, 43650);
  });

  test('round trips tenant salary designer definitions', () {
    final original = SalaryDesignerState.defaults.copyWith(
      components: [
        ...SalaryDesignerState.defaults.components,
        const SalaryPayComponent(
          id: 8,
          name: 'Flexible',
          code: 'FL',
          type: 'Earning',
          taxable: '0',
          description: 'Flexible allowance',
        ),
      ],
    );

    final restored = SalaryDesignerState.fromJson(original.toJson());

    expect(restored.components.last.code, 'FL');
    expect(restored.payGroups.first.componentIds, hasLength(7));
    expect(restored.formulas.last.value, 200);
  });
}
