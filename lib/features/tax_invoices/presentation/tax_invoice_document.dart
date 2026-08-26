import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vistora_mobile/features/tax_invoices/domain/tax_invoice_models.dart';

Future<Uint8List> buildTaxInvoicePdf(TaxInvoiceDetail detail) async {
  final invoice = detail.invoice;
  final provider = detail.provider;
  final client = detail.client;
  final money = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ');
  pw.ImageProvider? seal;
  if (provider.sealUrl != null) {
    try {
      seal = await networkImage(provider.sealUrl!);
    } catch (_) {
      seal = null;
    }
  }

  final document = pw.Document(
    title: 'Tax Invoice ${invoice.invoiceNo}',
    author: provider.companyName,
    subject: '${provider.productName ?? 'Vistora'} subscription invoice',
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      footer: (context) => pw.Center(
        child: pw.Text(
          'Computer-generated tax invoice | ${invoice.invoiceNo} | Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
      ),
      build: (_) => [
        pw.Container(
          height: 7,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#F97316'),
                PdfColor.fromHex('#EC407A'),
                PdfColor.fromHex('#0EA5E9'),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    provider.productName ?? 'Vistora',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#F97316'),
                    ),
                  ),
                  pw.Text(
                    'Powered by ${provider.companyName}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#172033'),
                  ),
                ),
                pw.Text(
                  invoice.invoiceNo,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  invoice.invoiceDate == null
                      ? 'Date unavailable'
                      : DateFormat.yMMMMd().format(invoice.invoiceDate!),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _party(
                'FROM',
                provider.companyName,
                provider.gstin,
                provider.address,
                [provider.email, provider.phone, provider.website],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _party(
                'BILLED TO',
                client.companyName,
                client.gstin,
                client.address,
                [client.corpId, client.phone],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        _sectionTitle('Billing details'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(2.6),
          },
          children: [
            _detailRow('Payment purpose', _title(invoice.paymentType)),
            if (invoice.paymentType == 'period')
              _detailRow('Billing frequency', _title(invoice.periodType)),
            if (invoice.periodStart != null && invoice.periodEnd != null)
              _detailRow(
                'Service period',
                '${DateFormat.yMMMd().format(invoice.periodStart!)} - ${DateFormat.yMMMd().format(invoice.periodEnd!)}',
              ),
            _detailRow('Payment mode', _title(invoice.paymentMode)),
            if (invoice.paymentReference != null)
              _detailRow('Payment reference', invoice.paymentReference!),
            if (invoice.notes != null) _detailRow('Notes', invoice.notes!),
          ],
        ),
        pw.SizedBox(height: 20),
        _sectionTitle('Amount breakup'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.7),
            1: pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#172033')),
              children: [
                _amountCell('DESCRIPTION', header: true),
                _amountCell('AMOUNT', header: true, right: true),
              ],
            ),
            pw.TableRow(
              children: [
                _amountCell(
                  '${provider.productName ?? 'Vistora'} - ${_title(invoice.paymentType)} payment',
                ),
                _amountCell(money.format(invoice.subtotal), right: true),
              ],
            ),
            if (invoice.cgstAmount > 0)
              _taxRow('CGST', invoice.cgstPercent, invoice.cgstAmount, money),
            if (invoice.sgstAmount > 0)
              _taxRow('SGST', invoice.sgstPercent, invoice.sgstAmount, money),
            if (invoice.igstAmount > 0)
              _taxRow('IGST', invoice.igstPercent, invoice.igstAmount, money),
            if (invoice.gstAmount > 0 &&
                invoice.cgstAmount == 0 &&
                invoice.sgstAmount == 0 &&
                invoice.igstAmount == 0)
              pw.TableRow(
                children: [
                  _amountCell('GST'),
                  _amountCell(money.format(invoice.gstAmount), right: true),
                ],
              ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ECFDF5'),
            border: pw.Border.all(color: PdfColor.fromHex('#86EFAC')),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL PAID',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#166534'),
                ),
              ),
              pw.Text(
                money.format(invoice.totalAmount),
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#166534'),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 28),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Thank you for choosing ${provider.productName ?? 'Vistora'}. This receipt confirms the recorded payment shown above.',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            if (seal != null) ...[
              pw.SizedBox(width: 18),
              pw.Column(
                children: [
                  pw.Image(seal, width: 76, height: 76, fit: pw.BoxFit.contain),
                  pw.Text(
                    'Authorised seal',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _party(
  String label,
  String name,
  String? gstin,
  String? address,
  List<String?> contacts,
) => pw.Container(
  padding: const pw.EdgeInsets.all(12),
  decoration: pw.BoxDecoration(
    color: PdfColor.fromHex('#F8FAFC'),
    borderRadius: pw.BorderRadius.circular(6),
    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#F97316'),
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      if (gstin != null)
        pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 8)),
      if (address != null)
        pw.Text(address, style: const pw.TextStyle(fontSize: 8)),
      for (final value in contacts.whereType<String>())
        pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
    ],
  ),
);

pw.Widget _sectionTitle(String value) => pw.Text(
  value.toUpperCase(),
  style: pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
    color: PdfColor.fromHex('#F97316'),
    letterSpacing: 1.05,
  ),
);

pw.TableRow _detailRow(String label, String value) =>
    pw.TableRow(children: [_amountCell(label, bold: true), _amountCell(value)]);

pw.TableRow _taxRow(
  String name,
  double rate,
  double amount,
  NumberFormat money,
) => pw.TableRow(
  children: [
    _amountCell('$name @ ${_rate(rate)}%'),
    _amountCell(money.format(amount), right: true),
  ],
);

pw.Widget _amountCell(
  String value, {
  bool header = false,
  bool right = false,
  bool bold = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 8),
  child: pw.Text(
    value,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: header ? 8 : 9,
      color: header ? PdfColors.white : PdfColors.black,
      fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

String _title(String value) => value
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _rate(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
