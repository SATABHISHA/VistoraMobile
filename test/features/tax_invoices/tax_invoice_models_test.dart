import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/tax_invoices/domain/tax_invoice_models.dart';

void main() {
  test('parses a complete tax invoice payload with parties and split GST', () {
    final detail = TaxInvoiceDetail.fromJson({
      'invoice': {
        'id': 7,
        'payment_id': 11,
        'corp_id': 'AHN001',
        'invoice_no': 'V2608250000B',
        'invoice_date': '2026-08-25',
        'payment_type': 'installation',
        'payment_mode': 'cheque',
        'payment_reference': 'CHQ-91',
        'client_name': 'Ahanova',
        'subtotal': '20000',
        'cgst_percent': '9',
        'sgst_percent': '9',
        'cgst_amount': '1800',
        'sgst_amount': '1800',
        'gst_amount': '3600',
        'total_amount': '23600',
      },
      'payment': {'notes': 'Initial implementation'},
      'provider': {
        'company_name': 'Ahanova AI Technologies Private Limited',
        'product_name': 'Vistora',
        'gstin': '19ABCDE1234F1Z5',
        'email': 'wecare@ahanova.in',
      },
      'client': {
        'corp_id': 'AHN001',
        'company_name': 'Ahanova',
        'gstin': '19AAAAA0000A1Z5',
      },
    });

    expect(detail.invoice.invoiceNo.length, lessThanOrEqualTo(13));
    expect(detail.invoice.paymentType, 'installation');
    expect(detail.invoice.cgstAmount, 1800);
    expect(detail.invoice.totalAmount, 23600);
    expect(detail.invoice.paymentReference, 'CHQ-91');
    expect(detail.invoice.notes, 'Initial implementation');
    expect(detail.provider.productName, 'Vistora');
    expect(detail.client.corpId, 'AHN001');
  });

  test('uses nested legacy payment values in invoice lists', () {
    final summary = TaxInvoiceSummary.fromJson({
      'id': 2,
      'payment_id': 4,
      'invoice_no': 'INV-OLD-2',
      'invoice_date': '2026-07-01',
      'client_name': 'Legacy Tenant',
      'subtotal': '1000',
      'gst_amount': '180',
      'total_amount': '1180',
      'payment': {
        'corp_id': 'LEG001',
        'period_type': 'monthly',
        'payment_mode': 'online',
      },
    });

    expect(summary.corpId, 'LEG001');
    expect(summary.periodType, 'monthly');
    expect(summary.totalAmount, 1180);
  });
}
