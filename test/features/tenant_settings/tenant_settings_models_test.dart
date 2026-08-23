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
      'office_latitude': '22.5726',
      'office_longitude': '88.3639',
      'geofence_radius_meters': 200,
      'smtp_host': 'smtp.example.test',
      'smtp_port': 587,
      'smtp_encryption': 'tls',
    });

    expect(settings.companyName, 'Ahanova');
    expect(settings.geofenceEnabled, isTrue);
    expect(settings.officeLatitude, 22.5726);
    expect(settings.smtpPort, 587);
  });
}
