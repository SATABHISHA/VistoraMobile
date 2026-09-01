import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/finance_hub/domain/finance_models.dart';

void main() {
  test('parses tenant finance entry, GST and invoice state', () {
    final entry = FinanceEntry.fromJson({
      'id': 8,
      'entry_type': 'income',
      'entry_date': '2026-08-29',
      'category': 'Consulting',
      'party_name': 'Acme Ltd',
      'payment_mode': 'neft',
      'subtotal': '10000.00',
      'gst_type': 'cgst_sgst',
      'cgst_percent': '9.00',
      'cgst_amount': '900.00',
      'sgst_percent': '9.00',
      'sgst_amount': '900.00',
      'igst_amount': '0.00',
      'total_amount': '11800.00',
      'components': [
        {
          'description': 'Implementation',
          'quantity': '2.000',
          'unit_price': '5000.00',
          'gst_included': true,
          'taxable_amount': '8474.58',
          'tax_amount': '1525.42',
          'amount': '10000.00',
        },
      ],
      'invoice': {'id': 3, 'invoice_no': 'VF260000001'},
    });

    expect(entry.total, 11800);
    expect(entry.components.single.quantity, 2);
    expect(entry.components.single.gstIncluded, isTrue);
    expect(entry.components.single.taxableAmount, 8474.58);
    expect(entry.components.single.taxAmount, 1525.42);
    expect(entry.cgstAmount + entry.sgstAmount, 1800);
    expect(entry.invoice?['invoice_no'], 'VF260000001');
  });

  test('parses separately tracked credit card details', () {
    final entry = FinanceEntry.fromJson({
      'id': 9,
      'entry_type': 'expense',
      'entry_date': '2026-08-30',
      'category': 'Travel',
      'payment_mode': 'card',
      'subtotal': 2500,
      'total_amount': 2500,
      'card_issuer': 'HDFC Bank',
      'card_holder_name': 'Finance Team',
      'card_last_four': '4242',
      'components': const [],
    });

    expect(entry.paymentMode, 'card');
    expect(entry.cardIssuer, 'HDFC Bank');
    expect(entry.cardHolderName, 'Finance Team');
    expect(entry.cardLastFour, '4242');
  });
}
