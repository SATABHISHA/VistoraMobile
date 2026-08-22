import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/work/domain/employee_work_models.dart';

void main() {
  test('finds authenticated employee project assignment', () {
    final project = EmployeeProject.fromJson({
      'id': 4,
      'code': 'MOB',
      'name': 'Mobile App',
      'status': 'active',
      'health_status': 'green',
      'assignments': [
        {
          'id': 9,
          'employee_id': 18,
          'role': 'Developer',
          'status': 'in_progress',
        },
      ],
    });

    expect(project.assignmentFor(18)?.id, 9);
    expect(project.assignmentFor(99), isNull);
  });

  test('finds current panelist interview feedback', () {
    final task = InterviewTask.fromJson({
      'id': 7,
      'scheduled_at': '2026-08-21T10:00:00Z',
      'mode': 'virtual',
      'candidate': {
        'first_name': 'Asha',
        'last_name': 'Rao',
        'position': 'Engineer',
      },
      'feedback': [
        {
          'panelist_user_id': 12,
          'rating': 4,
          'recommendation': 'hire',
          'feedback': 'Strong candidate',
        },
      ],
    });

    expect(task.candidateName, 'Asha Rao');
    expect(task.feedbackBy(12)?.rating, 4);
    expect(task.feedbackBy(13), isNull);
  });
}
