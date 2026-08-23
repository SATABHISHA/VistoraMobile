import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/hr_operations/domain/hr_operations_models.dart';

void main() {
  test('parses recruitment offer with candidate and template details', () {
    final offer = RecruitmentOffer.fromJson({
      'id': 14,
      'position': 'Territory Manager',
      'status': 'sent',
      'offered_ctc': '720000.50',
      'start_date': '2026-09-01',
      'rendered_html': '<p>Tenant branded offer</p>',
      'generated_at': '2026-08-23T10:00:00+05:30',
      'candidate': {
        'first_name': 'Asha',
        'last_name': 'Roy',
        'email': 'asha@example.test',
      },
      'template': {'name': 'Standard Offer Letter'},
    });

    expect(offer.candidateName, 'Asha Roy');
    expect(offer.position, 'Territory Manager');
    expect(offer.offeredCtc, 720000.50);
    expect(offer.templateName, 'Standard Offer Letter');
    expect(offer.status, 'sent');
  });

  test('parses appointment and full-and-final records defensively', () {
    final appointment = EmployeeLetter.fromJson({
      'id': 5,
      'rendered_html': '<article>Appointment</article>',
      'generated_at': '2026-08-23T09:00:00Z',
      'employee': {
        'first_name': 'Meera',
        'last_name': 'Das',
        'emp_code': 'EMP006',
      },
      'template': {'name': 'Modern Corporate'},
    });
    final settlement = FinalSettlementItem.fromJson({
      'id': 8,
      'employee_id': 6,
      'resignation_date': '2026-08-01',
      'last_working_date': '2026-08-23',
      'salary_due': '23000.00',
      'leave_encashment': 4000,
      'gratuity': 0,
      'bonus': 1000,
      'deductions': 500,
      'net_settlement': '27500.00',
      'status': 'reviewed',
      'employee': {
        'id': 6,
        'first_name': 'Meera',
        'last_name': 'Das',
        'emp_code': 'EMP006',
      },
    });

    expect(appointment.employeeName, 'Meera Das');
    expect(appointment.employeeCode, 'EMP006');
    expect(appointment.templateName, 'Modern Corporate');
    expect(settlement.employeeName, 'Meera Das');
    expect(settlement.netSettlement, 27500);
    expect(settlement.status, 'reviewed');
  });
}
