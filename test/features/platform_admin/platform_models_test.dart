import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/platform_admin/domain/platform_models.dart';

void main() {
  test('parses platform tenant feature and usage summary', () {
    final tenant = PlatformTenant.fromJson({
      'id': 4,
      'corp_id': 'AHN001',
      'company_name': 'Ahanova',
      'status': 'active',
      'employee_count': 18,
      'admin_count': 2,
      'storage_used_bytes': 1048576,
      'storage_quota_mb': 250,
      'mr_enabled': 1,
      'project_management_enabled': false,
      'file_manager_enabled': true,
    });

    expect(tenant.companyName, 'Ahanova');
    expect(tenant.employeeCount, 18);
    expect(tenant.mrEnabled, isTrue);
    expect(tenant.projectsEnabled, isFalse);
  });

  test('parses dashboard payments and onboarding entries', () {
    final overview = PlatformOverview.fromJson({
      'activeTenants': 3,
      'inactiveTenants': 1,
      'recentPayments': [
        {
          'id': 9,
          'corp_id': 'AHN001',
          'package_amount': '1000.00',
          'gst_amount': 180,
          'total_amount': '1180.00',
          'period_type': 'monthly',
          'payment_date': '2026-08-23',
          'status': 'recorded',
        },
      ],
    });
    final queue = PlatformOnboardingItem.fromJson({
      'id': 6,
      'submission_id': 14,
      'status': 'pending',
    });

    expect(overview.activeTenants, 3);
    expect(overview.recentPayments.single.totalAmount, 1180);
    expect(queue.submissionId, 14);
  });
}
