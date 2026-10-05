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

  test('parses submitted project updates for employee and team views', () {
    final project = EmployeeProject.fromJson({
      'id': 5,
      'code': 'UPD-01',
      'name': 'Project Updates',
      'status': 'active',
      'health_status': 'green',
      'assignments': [
        {
          'id': 10,
          'employee_id': 18,
          'role': 'Member',
          'status': 'assigned',
          'updates': [
            {
              'id': 21,
              'period_type': 'weekly',
              'period_start': '2026-10-04',
              'progress_percent': 60,
              'achievements': 'Meera submitted an update.',
            },
          ],
        },
      ],
    });

    expect(project.assignmentFor(18)?.updates.single.progressPercent, 60);
    expect(
      project.assignmentFor(18)?.updates.single.achievements,
      'Meera submitted an update.',
    );
  });

  test(
    'resolves a missing project supervisor from assigned supervisor data',
    () {
      final project = EmployeeProject.fromJson({
        'id': 6,
        'code': 'SUP-01',
        'name': 'Supervisor fallback',
        'assignments': [
          {
            'id': 11,
            'employee_id': 22,
            'role': 'Member',
            'employee': {
              'id': 22,
              'emp_code': 'EMP022',
              'first_name': 'Priya',
              'last_name': 'Gupta',
              'role_type': 'Supervisor',
            },
          },
        ],
      });

      expect(project.supervisorId, 22);
      expect(project.supervisorName, 'Priya Gupta');
    },
  );

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
