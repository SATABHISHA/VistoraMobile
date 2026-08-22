import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/auth/domain/auth_session.dart';

void main() {
  test('parses the Laravel mobile bootstrap contract', () {
    final session = AuthSession.fromMeResponse({
      'success': true,
      'data': {
        'user': {
          'id': 7,
          'corp_id': 'AHN001',
          'name': 'Vistora User',
          'role_type': 'Supervisor',
        },
        'employee': {'id': 19, 'emp_code': 'EMP019'},
        'tenant': {'company_name': 'Ahanova'},
        'permissions': ['attendance.manage'],
        'features': {'mr': true, 'projects': true, 'geofence': false},
      },
    });

    expect(session.user.normalizedRole, 'supervisor');
    expect(session.employeeId, 19);
    expect(session.companyName, 'Ahanova');
    expect(session.hasPermission('attendance.manage'), isTrue);
    expect(session.features.mr, isTrue);
    expect(session.features.fileManager, isFalse);
  });
}
