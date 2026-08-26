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

  test('parses split GST payment and builds a custom-period request', () {
    final payment = PlatformPayment.fromJson({
      'id': 19,
      'corp_id': 'AHN001',
      'company_name': 'Ahanova',
      'invoice_no': 'V2608250000J',
      'package_amount': '10000.00',
      'gst_enabled': 1,
      'gst_type': 'cgst_sgst',
      'cgst_percent': '9',
      'sgst_percent': '9',
      'cgst_amount': '900',
      'sgst_amount': '900',
      'gst_amount': '1800',
      'total_amount': '11800',
      'payment_type': 'period',
      'period_type': 'quarterly',
      'period_start': '2026-07-01',
      'period_end': '2026-09-30',
      'payment_date': '2026-08-25',
      'payment_mode': 'neft',
      'transaction_reference': 'UTR123',
      'status': 'recorded',
    });

    expect(payment.companyName, 'Ahanova');
    expect(payment.gstEnabled, isTrue);
    expect(payment.cgstAmount, 900);
    expect(payment.totalAmount, 11800);
    expect(payment.transactionReference, 'UTR123');

    final request = PlatformPaymentDraft(
      corpId: 'AHN001',
      amount: 5000,
      paymentType: 'period',
      periodType: 'custom',
      paymentDate: DateTime(2026, 8, 25),
      periodStart: DateTime(2026, 8, 1),
      periodEnd: DateTime(2026, 8, 15),
      gstEnabled: true,
      gstType: 'igst',
      cgstPercent: 9,
      sgstPercent: 9,
      igstPercent: 18,
      paymentMode: 'upi',
      transactionReference: 'UPI-1',
    ).toJson();

    expect(request['period_start'], '2026-08-01');
    expect(request['period_end'], '2026-08-15');
    expect(request['igst_percent'], 18);
    expect(request['cgst_percent'], 0);
    expect(request['payment_mode'], 'upi');
  });

  test('parses platform provider GST settings', () {
    final settings = PlatformBillingSettings.fromJson({
      'provider_company_name': 'Ahanova AI Technologies Private Limited',
      'product_name': 'Vistora',
      'provider_gstin': '19ABCDE1234F1Z5',
      'contact_email': 'wecare@ahanova.in',
      'website': 'https://ahanova.in',
      'gst_enabled': true,
      'gst_mode': 'igst',
      'igst_percent': '18',
    });

    expect(settings.gstEnabled, isTrue);
    expect(settings.gstMode, 'igst');
    expect(settings.igstPercent, 18);
    expect(settings.contactEmail, 'wecare@ahanova.in');
  });
}
