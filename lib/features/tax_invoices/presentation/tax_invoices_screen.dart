import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/tax_invoices/data/tax_invoice_repository.dart';
import 'package:vistora_mobile/features/tax_invoices/domain/tax_invoice_models.dart';
import 'package:vistora_mobile/features/tax_invoices/presentation/tax_invoice_view.dart';

final taxInvoiceRepositoryProvider = Provider<TaxInvoiceRepository>(
  (ref) => TaxInvoiceRepository(ref.watch(apiClientProvider)),
);

class TaxInvoicesScreen extends ConsumerStatefulWidget {
  const TaxInvoicesScreen({super.key});

  @override
  ConsumerState<TaxInvoicesScreen> createState() => _TaxInvoicesScreenState();
}

class _TaxInvoicesScreenState extends ConsumerState<TaxInvoicesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  int? _month;
  int? _year;
  int _perPage = 10;
  int? _openingId;
  late Future<TaxInvoicePage> _future;

  TaxInvoiceRepository get repository => ref.read(taxInvoiceRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<TaxInvoicePage> _load() => repository.list(
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    month: _month,
    year: _year,
    page: _page,
    perPage: _perPage,
  );

  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _open(TaxInvoiceSummary invoice) async {
    if (_openingId != null) return;
    setState(() => _openingId = invoice.id);
    try {
      final detail = await repository.show(invoice.id);
      if (!mounted) return;
      await showTaxInvoicePreview(context, detail);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tax Invoices'),
          Text(
            'Company billing vault',
            style: TextStyle(fontSize: 12, color: VistoraColors.muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh invoices',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<TaxInvoicePage>(
        future: _future,
        builder: (context, snapshot) {
          final result = snapshot.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF351F12),
                      Color(0xFF161630),
                      Color(0xFF06283A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    _InvoiceIcon(),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your invoice archive',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'View, print or download verified tax invoices.',
                            style: TextStyle(color: VistoraColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search invoice, purpose or payment mode',
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 320),
                    () => mounted ? _refresh(reset: true) : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: month,
                            child: Text(
                              DateFormat.MMM().format(DateTime(2026, month)),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        _month = value;
                        _refresh(reset: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        for (
                          var year = DateTime.now().year + 1;
                          year >= DateTime.now().year - 5;
                          year--
                        )
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (value) {
                        _year = value;
                        _refresh(reset: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    child: DropdownButtonFormField<int>(
                      value: _perPage,
                      decoration: const InputDecoration(labelText: 'Rows'),
                      items: const [10, 20, 50]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _perPage = value ?? 10;
                        _refresh(reset: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState != ConnectionState.done)
                for (var index = 0; index < 3; index++) const _InvoiceSkeleton()
              else if (snapshot.hasError)
                _InvoiceError(error: snapshot.error, retry: _refresh)
              else if (result == null || result.items.isEmpty)
                const _InvoiceEmpty()
              else ...[
                for (final entry in result.items.asMap().entries)
                  _AnimatedInvoiceCard(
                    index: entry.key,
                    invoice: entry.value,
                    busy: _openingId == entry.value.id,
                    onTap: () => _open(entry.value),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${result.total} invoice(s) · Page ${result.page} of ${result.lastPage}',
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: result.page > 1
                          ? () {
                              _page--;
                              _refresh();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: result.hasMore
                          ? () {
                              _page++;
                              _refresh();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _AnimatedInvoiceCard extends StatelessWidget {
  const _AnimatedInvoiceCard({
    required this.index,
    required this.invoice,
    required this.busy,
    required this.onTap,
  });

  final int index;
  final TaxInvoiceSummary invoice;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 280 + index.clamp(0, 8) * 45),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _InvoiceIcon(small: true),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            invoice.invoiceDate == null
                                ? 'Date unavailable'
                                : DateFormat.yMMMd().format(
                                    invoice.invoiceDate!,
                                  ),
                            style: const TextStyle(color: VistoraColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _CardMetric(
                        label: 'PURPOSE',
                        value: _title(invoice.paymentType),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CardMetric(
                        label: 'TOTAL PAID',
                        value: money.format(invoice.totalAmount),
                        color: VistoraColors.green,
                      ),
                    ),
                  ],
                ),
                if (invoice.gstAmount > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Includes GST ${money.format(invoice.gstAmount)} · ${_title(invoice.paymentMode)}',
                    style: const TextStyle(
                      color: VistoraColors.amber,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  const _CardMetric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: VistoraColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VistoraColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _InvoiceIcon extends StatelessWidget {
  const _InvoiceIcon({this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
    width: small ? 48 : 58,
    height: small ? 48 : 58,
    decoration: BoxDecoration(
      color: VistoraColors.orange.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(small ? 15 : 18),
    ),
    child: Icon(
      Icons.receipt_long_outlined,
      color: VistoraColors.orange,
      size: small ? 25 : 30,
    ),
  );
}

class _InvoiceSkeleton extends StatelessWidget {
  const _InvoiceSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 145,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: VistoraColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    alignment: Alignment.center,
    child: const CircularProgressIndicator(),
  );
}

class _InvoiceEmpty extends StatelessWidget {
  const _InvoiceEmpty();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: VistoraColors.muted,
          ),
          SizedBox(height: 10),
          Text(
            'No tax invoices match these filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VistoraColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _InvoiceError extends StatelessWidget {
  const _InvoiceError({required this.error, required this.retry});
  final Object? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: VistoraColors.pink, size: 42),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: retry, child: const Text('Try again')),
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
