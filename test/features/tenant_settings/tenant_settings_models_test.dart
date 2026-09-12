import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/tenant_settings/domain/tenant_settings_models.dart';

void main() {
  test('parses tenant branding, geofence and SMTP configuration', () {
    final settings = TenantSettings.fromJson({
      'company_name': 'Ahanova',
      'corp_id': 'AHN001',
      'fiscal_year_start_month': 4,
      'employee_code_prefix': 'EMP',
      'employee_code_next': 12,
      'employee_code_padding': 3,
      'geofence_enabled': 1,
      'attendance_hours_visible_to_self': false,
      'office_latitude': '22.5726',
      'office_longitude': '88.3639',
      'geofence_radius_meters': 200,
      'smtp_host': 'smtp.example.test',
      'smtp_port': 587,
      'smtp_encryption': 'tls',
      'geofence_employee_ids': [17],
      'geofence_employees': [
        {
          'id': 17,
          'emp_code': 'EMP017',
          'first_name': 'Riya',
          'last_name': 'Sen',
          'status': 'active',
        },
      ],
    });

    expect(settings.companyName, 'Ahanova');
    expect(settings.geofenceEnabled, isTrue);
    expect(settings.attendanceHoursVisibleToSelf, isFalse);
    expect(settings.officeLatitude, 22.5726);
    expect(settings.smtpPort, 587);
    expect(settings.geofenceEmployeeIds, [17]);
    expect(settings.geofenceEmployees.single.name, 'Riya Sen');
    expect(settings.geofenceEmployees.single.code, 'EMP017');
  });

  test('worked hours visibility defaults to enabled for existing tenants', () {
    final settings = TenantSettings.fromJson({});

    expect(settings.attendanceHoursVisibleToSelf, isTrue);
  });
}
