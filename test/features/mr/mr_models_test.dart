import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';

void main() {
  test('parses metadata with Laravel camel-case business units', () {
    final metadata = MrMetadata.fromJson({
      'states': [
        {'id': 1, 'name': 'West Bengal'},
      ],
      'branches': [
        {'id': 2, 'name': 'Kolkata', 'code': 'KOL'},
      ],
      'businessUnits': [
        {'id': 3, 'name': 'Pharma', 'code': 'PH'},
      ],
      'employees': [
        {'id': 4, 'emp_code': 'E004', 'first_name': 'Asha', 'last_name': 'Roy'},
      ],
    });

    expect(metadata.businessUnits.single.name, 'Pharma');
    expect(metadata.employees.single.name, 'Asha Roy');
    expect(metadata.employees.single.code, 'E004');
  });

  test('parses assignment relationships and embedded report', () {
    final assignment = MrAssignment.fromJson({
      'id': 10,
      'employee_id': 4,
      'doctor_id': 5,
      'location_id': 6,
      'doctor_territory_id': 7,
      'visit_date': '2026-08-21',
      'status': 'planned',
      'visiting_status': 'visited/pending approval',
      'employee': {
        'id': 4,
        'emp_code': 'E004',
        'first_name': 'Asha',
        'last_name': 'Roy',
      },
      'doctor': {'id': 5, 'doctor_name': 'Dr Sen'},
      'location': {'id': 6, 'address': 'Central Clinic'},
      'visit_report': {
        'id': 11,
        'assignment_id': 10,
        'employee_id': 4,
        'status': 'submitted',
        'check_in_source': 'gps',
        'distance_meters': '38.5',
      },
    });

    expect(assignment.doctorName, 'Dr Sen');
    expect(assignment.locationAddress, 'Central Clinic');
    expect(assignment.employeeName, 'Asha Roy');
    expect(assignment.report?.status, 'submitted');
    expect(assignment.report?.distanceMeters, 38.5);
  });

  test('parses report review details and nested assignment', () {
    final report = MrVisitReport.fromJson({
      'id': 22,
      'assignment_id': 10,
      'employee_id': 4,
      'status': 'rejected',
      'visited_at': '2026-08-21T10:30:00Z',
      'review_notes': 'Location needs verification',
      'employee': {'first_name': 'Asha', 'last_name': 'Roy'},
      'assignment': {
        'doctor': {'doctor_name': 'Dr Sen'},
        'location': {'address': 'Central Clinic'},
      },
    });

    expect(report.employeeName, 'Asha Roy');
    expect(report.doctorName, 'Dr Sen');
    expect(report.locationAddress, 'Central Clinic');
    expect(report.reviewNotes, 'Location needs verification');
  });
}
