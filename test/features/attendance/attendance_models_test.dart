import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/attendance/domain/attendance_models.dart';

void main() {
  test('parses today attendance and geofence state', () {
    final value = TodayAttendance.fromResponse({
      'data': {
        'canClockIn': false,
        'canClockOut': true,
        'serverTime': '2026-08-21T10:00:00+05:30',
        'geofence': {'enabled': true, 'radius_meters': 200},
        'attendance': {
          'id': 8,
          'employee_id': 4,
          'status': 'present',
          'worked_minutes_live': 125,
          'check_in_at': '2026-08-21T08:00:00+05:30',
          'is_live': true,
        },
      },
    });

    expect(value.canClockOut, isTrue);
    expect(value.geofence.enabled, isTrue);
    expect(value.attendance?.id, 8);
    expect(value.attendance?.workedMinutes, 125);
  });

  test('calendar retains record id required for regularization', () {
    final value = AttendanceCalendar.fromResponse({
      'data': {
        'days': [
          {
            'id': 44,
            'date': '2026-08-20',
            'day': 20,
            'weekday': 'Thu',
            'status': 'present',
            'worked_minutes': 480,
          },
        ],
        'summary': {'present': 1},
      },
    });

    expect(value.days.single.id, 44);
    expect(value.summary['present'], 1);
  });

  test('roster parses subordinate identity, live time and location', () {
    final value = AttendanceRoster.fromResponse({
      'data': {
        'items': [
          {
            'employee_id': 9,
            'employee': {
              'emp_code': 'EMP009',
              'first_name': 'Asha',
              'last_name': 'Roy',
              'work_email': 'asha@example.test',
              'mobile': '9876543210',
            },
            'status': 'present',
            'worked_minutes': 410,
            'latitude': 22.5726,
            'longitude': 88.3639,
            'location_address': 'Kolkata office',
            'is_live': true,
          },
        ],
        'summary': {'present': 1},
      },
    });

    expect(value.items.single.employeeName, 'Asha Roy');
    expect(value.items.single.employeeCode, 'EMP009');
    expect(value.items.single.locationAddress, 'Kolkata office');
    expect(value.items.single.isLive, isTrue);
  });
}
