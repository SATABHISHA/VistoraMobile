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
      'settings': {'max_locations_per_doctor': 3},
    });

    expect(metadata.businessUnits.single.name, 'Pharma');
    expect(metadata.employees.single.name, 'Asha Roy');
    expect(metadata.employees.single.code, 'E004');
    expect(metadata.settings.maxLocationsPerDoctor, 3);
  });

  test('parses doctor locations and optional geofence configuration', () {
    final doctor = MrDoctor.fromJson({
      'id': 5,
      'doctor_name': 'Dr Sen',
      'status': 'active',
      'locations': [
        {
          'id': 6,
          'address': 'Central Clinic',
          'state_id': 1,
          'latitude': '22.5726',
          'longitude': '88.3639',
          'geofence_radius_meters': 250,
          'status': 'active',
          'branch': {'id': 2, 'name': 'Kolkata'},
          'business_unit': {'id': 3, 'name': 'Pharma'},
        },
      ],
    });

    expect(doctor.locationCount, 1);
    expect(doctor.locations.single.hasGeofence, isTrue);
    expect(doctor.locations.single.radiusMeters, 250);
    expect(doctor.locations.single.branchName, 'Kolkata');
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
      'can_edit': false,
      'can_delete': false,
      'geofence_required': true,
      'employee': {
        'id': 4,
        'emp_code': 'E004',
        'first_name': 'Asha',
        'last_name': 'Roy',
      },
      'doctor': {'id': 5, 'doctor_name': 'Dr Sen'},
      'location': {
        'id': 6,
        'address': 'Central Clinic',
        'latitude': 22.57,
        'longitude': 88.36,
        'geofence_radius_meters': 200,
      },
      'visit_report': {
        'id': 11,
        'assignment_id': 10,
        'employee_id': 4,
        'status': 'submitted',
        'check_in_source': 'gps',
        'distance_meters': '38.5',
        'submission_count': 1,
      },
    });

    expect(assignment.doctorName, 'Dr Sen');
    expect(assignment.locationAddress, 'Central Clinic');
    expect(assignment.employeeName, 'Asha Roy');
    expect(assignment.report?.status, 'submitted');
    expect(assignment.report?.distanceMeters, 38.5);
    expect(assignment.geofenceRequired, isTrue);
    expect(assignment.canEdit, isFalse);
    expect(assignment.report?.submissionCount, 1);
  });

  test('parses report review details and nested assignment', () {
    final report = MrVisitReport.fromJson({
      'id': 22,
      'assignment_id': 10,
      'employee_id': 4,
      'status': 'rejected',
      'visited_at': '2026-08-21T10:30:00Z',
      'review_notes': 'Location needs verification',
      'submission_count': 2,
      'rolled_back_at': '2026-08-21T11:00:00Z',
      'rollback_notes': 'Submitted the wrong notes',
      'captured_address': '12 Park Street, Kolkata',
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
    expect(report.submissionCount, 2);
    expect(report.rollbackNotes, 'Submitted the wrong notes');
    expect(report.capturedAddress, '12 Park Street, Kolkata');
  });

  test('parses MR audit actor and subject employee', () {
    final event = MrAuditEvent.fromJson({
      'id': 99,
      'action': 'mr.report.submission_rolled_back',
      'entity_type': 'MrVisitReport',
      'entity_id': 22,
      'occurred_at': '2026-08-21T11:00:00Z',
      'actor': {'name': 'Asha Roy'},
      'actor_role': 'Employee',
      'subject_employee': {
        'emp_code': 'E004',
        'first_name': 'Asha',
        'last_name': 'Roy',
      },
      'old_values_json': {'status': 'submitted'},
      'new_values_json': {'status': 'draft'},
    });

    expect(event.actorName, 'Asha Roy');
    expect(event.employeeCode, 'E004');
    expect(event.newValues['status'], 'draft');
  });
}
