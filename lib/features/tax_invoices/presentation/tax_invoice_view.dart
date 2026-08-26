import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/tax_invoices/domain/tax_invoice_models.dart';
import 'package:vistora_mobile/features/tax_invoices/presentation/tax_invoice_document.dart';

Future<void> showTaxInvoicePreview(
  BuildContext context,
  TaxInvoiceDetail detail,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: VistoraColors.background,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.92,
    minChildSize: 0.62,
    maxChildSize: 0.98,
    builder: (context, controller) =>
        _InvoicePreview(detail: detail, controller: controller),
  ),
);

class _InvoicePreview extends StatelessWidget {
  const _InvoicePreview({required this.detail, required this.controller});

  final TaxInvoiceDetail detail;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final invoice = detail.invoice;
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF342012), Color(0xFF171633), Color(0xFF07283A)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.provider.productName ?? 'Vistora',
                          style: const TextStyle(
                            color: VistoraColors.orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 25,
                          ),
                        ),
                        Text(
                          'Powered by ${detail.provider.companyName}',
                          style: const TextStyle(color: VistoraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TAX INVOICE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        invoice.invoiceNo,
                        style: const TextStyle(color: VistoraColors.cyan),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                money.format(invoice.totalAmount),
                style: const TextStyle(
                  color: VistoraColors.green,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                ),
              ),
              Text(
                invoice.invoiceDate == null
                    ? 'Invoice date unavailable'
                    : DateFormat.yMMMMd().format(invoice.invoiceDate!),
                style: const TextStyle(color: VistoraColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PartyCard(label: 'BILLED BY', party: detail.provider),
        const SizedBox(height: 12),
        _PartyCard(label: 'BILLED TO', party: detail.client),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Payment details',
          rows: [
            ('Purpose', _title(invoice.paymentType)),
            if (invoice.paymentType == 'period')
              ('Frequency', _title(invoice.periodType)),
            if (invoice.periodStart != null && invoice.periodEnd != null)
              (
                'Service period',
                '${DateFormat.yMMMd().format(invoice.periodStart!)} – ${DateFormat.yMMMd().format(invoice.periodEnd!)}',
              ),
            ('Payment mode', _title(invoice.paymentMode)),
            if (invoice.paymentReference != null)
              ('Reference', invoice.paymentReference!),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Amount breakup',
          rows: [
            ('Taxable value', money.format(invoice.subtotal)),
            if (invoice.cgstAmount > 0)
              (
                'CGST @ ${_rate(invoice.cgstPercent)}%',
                money.format(invoice.cgstAmount),
              ),
            if (invoice.sgstAmount > 0)
              (
                'SGST @ ${_rate(invoice.sgstPercent)}%',
                money.format(invoice.sgstAmount),
              ),
            if (invoice.igstAmount > 0)
              (
                'IGST @ ${_rate(invoice.igstPercent)}%',
                money.format(invoice.igstAmount),
              ),
            if (invoice.gstAmount > 0 &&
                invoice.cgstAmount == 0 &&
                invoice.sgstAmount == 0 &&
                invoice.igstAmount == 0)
              ('GST', money.format(invoice.gstAmount)),
            ('Total paid', money.format(invoice.totalAmount)),
          ],
          emphasizeLast: true,
        ),
        if (invoice.notes != null) ...[
          const SizedBox(height: 12),
          _InfoCard(title: 'Notes', rows: [('Details', invoice.notes!)]),
        ],
        if (detail.provider.sealUrl != null) ...[
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Image.network(
                  detail.provider.sealUrl!,
                  height: 82,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                const Text(
                  'Authorised seal',
                  style: TextStyle(color: VistoraColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => Printing.layoutPdf(
                  name: '${invoice.invoiceNo}.pdf',
                  onLayout: (_) => buildTaxInvoicePdf(detail),
                ),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final bytes = await buildTaxInvoicePdf(detail);
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: '${invoice.invoiceNo}.pdf',
                  );
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.label, required this.party});
  final String label;
  final InvoiceParty party;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: VistoraColors.orange,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            party.companyName,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          if (party.corpId != null) Text('Corporate ID: ${party.corpId}'),
          if (party.gstin != null) Text('GSTIN: ${party.gstin}'),
          if (party.address != null) Text(party.address!),
          if (party.email != null) Text(party.email!),
          if (party.phone != null) Text(party.phone!),
          if (party.website != null) Text(party.website!),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
    this.emphasizeLast = false,
  });
  final String title;
  final List<(String, String)> rows;
  final bool emphasizeLast;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[index].$1,
                    style: const TextStyle(color: VistoraColors.muted),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    rows[index].$2,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: emphasizeLast && index == rows.length - 1
                          ? VistoraColors.green
                          : null,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

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
