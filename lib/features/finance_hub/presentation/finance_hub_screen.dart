import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/finance_hub/data/finance_repository.dart';
import 'package:vistora_mobile/features/finance_hub/domain/finance_models.dart';

final financeRepositoryProvider = Provider(
  (ref) => FinanceRepository(ref.watch(apiClientProvider)),
);

class FinanceHubScreen extends ConsumerStatefulWidget {
  const FinanceHubScreen({super.key});
  @override
  ConsumerState<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends ConsumerState<FinanceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  FinanceSettings settings = const FinanceSettings();
  FinancePage? page;
  FinancePage? cardPage;
  Future<List<Map<String, dynamic>>>? auditFuture;
  Map<String, dynamic> summary = {};
  bool loading = true;
  int year = DateTime.now().year;
  int? month;
  DateTime? filterDate;
  int currentPage = 1;
  int cardCurrentPage = 1;
  int lastTab = 0;
  String type = 'income';
  final search = TextEditingController();
  FinanceRepository get repo => ref.read(financeRepositoryProvider);
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 6, vsync: this)..addListener(_tabChanged);
    _loadAll();
  }

  void _tabChanged() {
    if (!mounted) return;
    setState(() {});
    if (tabs.index == lastTab) return;
    lastTab = tabs.index;
    if (tabs.index == 1 || tabs.index == 2) {
      final selectedType = tabs.index == 1 ? 'income' : 'expense';
      if (type != selectedType) {
        type = selectedType;
        _entries(1);
      }
    } else if (tabs.index == 3) {
      _cardEntries(1);
    }
  }

  @override
  void dispose() {
    tabs.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      settings = await repo.settings();
      await Future.wait([_summary(), _entries()]);
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _summary() async {
    summary = await repo.summary(year: year, month: month);
    if (mounted) setState(() {});
  }

  Future<void> _entries([int? target]) async {
    currentPage = target ?? currentPage;
    page = await repo.entries(
      type: type,
      query: search.text.trim().isEmpty ? null : search.text.trim(),
      month: month,
      date: filterDate,
      year: year,
      page: currentPage,
    );
    if (mounted) setState(() {});
  }

  Future<void> _cardEntries([int? target]) async {
    cardCurrentPage = target ?? cardCurrentPage;
    cardPage = await repo.entries(
      type: 'expense',
      paymentMode: 'card',
      month: month,
      date: filterDate,
      year: year,
      page: cardCurrentPage,
    );
    if (mounted) setState(() {});
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String cash(Object? v) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(double.tryParse('$v') ?? 0);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vistora Finance Hub'),
      bottom: TabBar(
        controller: tabs,
        isScrollable: true,
        tabs: const [
          Tab(icon: Icon(Icons.insights_outlined), text: 'Overview'),
          Tab(icon: Icon(Icons.call_received), text: 'Income'),
          Tab(icon: Icon(Icons.call_made), text: 'Expenses'),
          Tab(icon: Icon(Icons.credit_card), text: 'Credit Card Payments'),
          Tab(icon: Icon(Icons.tune), text: 'Settings'),
          Tab(icon: Icon(Icons.history), text: 'Audit'),
        ],
      ),
    ),
    floatingActionButton: tabs.index == 1 || tabs.index == 2 || tabs.index == 3
        ? FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: Text(
              tabs.index == 3
                  ? 'Card payment'
                  : 'Record ${tabs.index == 1 ? 'income' : 'expense'}',
            ),
          )
        : null,
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: tabs,
            children: [
              _overview(),
              _ledger('income'),
              _ledger('expense'),
              _creditCards(),
              _settings(),
              _audit(),
            ],
          ),
  );
  Widget _overview() {
    final monthly = (summary['monthly'] as List? ?? const []);
    final max = monthly.fold<double>(
      1,
      (m, x) => [
        m,
        double.tryParse('${x['income']}') ?? 0,
        double.tryParse('${x['expense']}') ?? 0,
        double.tryParse('${x['credit_card']}') ?? 0,
      ].reduce((a, b) => a > b ? a : b),
    );
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Control. Clarity. Growth.',
            style: TextStyle(
              color: VistoraColors.cyan,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Finance at a glance',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _metric(
            'Income',
            summary['income'],
            VistoraColors.green,
            Icons.trending_up,
          ),
          _metric(
            'Operating expenses',
            summary['expense'],
            const Color(0xffff6680),
            Icons.trending_down,
          ),
          _metric(
            'Profit / Loss',
            summary['profit_loss'],
            (double.tryParse('${summary['profit_loss']}') ?? 0) >= 0
                ? VistoraColors.cyan
                : const Color(0xffff6680),
            Icons.account_balance_wallet_outlined,
          ),
          _metric(
            'Credit card tracked separately',
            summary['credit_card'],
            const Color(0xffa78bfa),
            Icons.credit_card,
          ),
          const SizedBox(height: 18),
          _filters(),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Income vs operating expense',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final raw in monthly)
                          Expanded(
                            child: _monthBars(
                              Map<String, dynamic>.from(raw),
                              max,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, Object? value, Color color, IconData icon) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: double.tryParse('$value') ?? 0),
        duration: const Duration(milliseconds: 700),
        builder: (context, v, child) => Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: VistoraColors.muted),
                  ),
                ),
                Text(
                  cash(v),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _monthBars(Map<String, dynamic> m, double max) {
    final i = double.tryParse('${m['income']}') ?? 0,
        e = double.tryParse('${m['expense']}') ?? 0,
        c = double.tryParse('${m['credit_card']}') ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 650),
                    height: 190 * i / max,
                    color: VistoraColors.green,
                  ),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 650),
                    height: 190 * c / max,
                    color: const Color(0xffa78bfa),
                  ),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 650),
                    height: 190 * e / max,
                    color: const Color(0xffff6680),
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat.MMM().format(DateTime(2020, m['month'] as int)),
            style: const TextStyle(fontSize: 9, color: VistoraColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _filters() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<int>(
          initialValue: year,
          items: [
            for (int y = DateTime.now().year; y >= DateTime.now().year - 6; y--)
              DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: (v) {
            year = v!;
            _summary();
            _entries(1);
            _cardEntries(1);
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: DropdownButtonFormField<int?>(
          initialValue: month,
          items: [
            const DropdownMenuItem(value: null, child: Text('All months')),
            for (int m = 1; m <= 12; m++)
              DropdownMenuItem(
                value: m,
                child: Text(DateFormat.MMMM().format(DateTime(2020, m))),
              ),
          ],
          onChanged: (v) {
            month = v;
            _summary();
            _entries(1);
            _cardEntries(1);
          },
        ),
      ),
    ],
  );
  Widget _ledger(String requested) {
    final list = type == requested ? (page?.items ?? []) : <FinanceEntry>[];
    return RefreshIndicator(
      onRefresh: () => _entries(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filters(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: filterDate ?? DateTime.now(),
                    );
                    if (selected != null) {
                      filterDate = selected;
                      _entries(1);
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    filterDate == null
                        ? 'Any date'
                        : DateFormat.yMMMd().format(filterDate!),
                  ),
                ),
              ),
              if (filterDate != null)
                IconButton(
                  tooltip: 'Clear date',
                  onPressed: () {
                    filterDate = null;
                    _entries(1);
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: search,
            onSubmitted: (_) => _entries(1),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search party, category or reference',
              suffixIcon: IconButton(
                onPressed: () => _entries(1),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Export Excel report'),
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: Text('No records found.')),
            )
          else
            for (final entry in list) _entryCard(entry),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Page ${page?.page ?? 1} of ${page?.lastPage ?? 1}'),
              Wrap(
                children: [
                  IconButton(
                    onPressed: (page?.page ?? 1) > 1
                        ? () => _entries(currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: (page?.page ?? 1) < (page?.lastPage ?? 1)
                        ? () => _entries(currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditCards() {
    final entries = cardPage?.items ?? const <FinanceEntry>[];
    final selectedTotal = cardPage?.filteredTotalAmount ?? 0;
    final visibleTotal = selectedTotal;
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_summary(), _cardEntries()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: selectedTotal),
            duration: const Duration(milliseconds: 750),
            builder: (context, value, child) => Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xff4c3b88), Color(0xff171d3a)],
                ),
                border: Border.all(color: const Color(0xff7c6bc4)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0x33ffffff),
                    child: Icon(Icons.credit_card, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credit Card Payments',
                          style: TextStyle(color: Color(0xffd8d0ff)),
                        ),
                        Text(
                          cash(value),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Tracked separately and excluded from operating-expense and profit/loss totals.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _filters(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _exportCards,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Export card history'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${cardPage?.total ?? 0} transactions • ${cash(visibleTotal)} on this page',
            style: const TextStyle(color: VistoraColors.muted),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(54),
              child: Center(child: Text('No credit card payments found.')),
            )
          else
            for (final entry in entries) _creditCardTile(entry),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Page ${cardPage?.page ?? 1} of ${cardPage?.lastPage ?? 1}'),
              Row(
                children: [
                  IconButton(
                    onPressed: (cardPage?.page ?? 1) > 1
                        ? () => _cardEntries(cardCurrentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: (cardPage?.page ?? 1) < (cardPage?.lastPage ?? 1)
                        ? () => _cardEntries(cardCurrentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditCardTile(FinanceEntry e) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .96, end: 1),
    duration: const Duration(milliseconds: 420),
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: Card(
      color: const Color(0xff201b43),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _edit(e),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card, color: Color(0xffb8a8ff)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.category,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    cash(e.total),
                    style: const TextStyle(
                      color: Color(0xffd8d0ff),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${e.cardIssuer ?? e.bankName ?? 'Credit Card'} ${e.cardLastFour == null ? '' : '•••• ${e.cardLastFour}'}',
              ),
              Text(
                '${DateFormat.yMMMd().format(e.date)} • ${e.partyName ?? 'No party'}',
                style: const TextStyle(color: VistoraColors.muted),
              ),
              if (e.cardHolderName != null)
                Text(
                  e.cardHolderName!,
                  style: const TextStyle(color: Color(0xffb8a8ff)),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('View'),
                    onPressed: () => _viewEntry(e),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit'),
                    onPressed: () => _edit(e),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _entryCard(FinanceEntry e) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _edit(e),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      (e.type == 'income'
                              ? VistoraColors.green
                              : const Color(0xffff6680))
                          .withValues(alpha: .15),
                  child: Icon(
                    e.type == 'income' ? Icons.south_west : Icons.north_east,
                    color: e.type == 'income'
                        ? VistoraColors.green
                        : const Color(0xffff6680),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${DateFormat.yMMMd().format(e.date)} • ${e.partyName ?? 'No party'}',
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  cash(e.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: e.type == 'income'
                        ? VistoraColors.green
                        : const Color(0xffff6680),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    e.paymentMode == 'card'
                        ? 'Credit Card'
                        : e.paymentMode.replaceAll('_', ' '),
                  ),
                ),
                if (e.paymentMode == 'card')
                  const Chip(label: Text('Tracked separately from P&L')),
                Chip(
                  label: Text(
                    e.invoice == null
                        ? 'Invoice: No'
                        : 'Invoice: ${e.invoice!['invoice_no']}',
                  ),
                ),
                if (e.invoice != null)
                  ActionChip(
                    avatar: const Icon(Icons.receipt_long, size: 17),
                    label: const Text('View'),
                    onPressed: () => _invoice(e.invoice!['id'] as int),
                  ),
                if (e.type == 'income' && e.invoice == null)
                  ActionChip(
                    label: const Text('Generate invoice'),
                    onPressed: () => _generate(e),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('View details'),
                  onPressed: () => _viewEntry(e),
                ),
                ActionChip(
                  label: const Text('Delete'),
                  onPressed: () => _delete(e),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _viewEntry(FinanceEntry e) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: VistoraColors.surface,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      maxChildSize: .94,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xffff7a3d).withValues(alpha: .16),
                child: Icon(
                  e.paymentMode == 'card'
                      ? Icons.credit_card
                      : e.type == 'income'
                      ? Icons.south_west
                      : Icons.north_east,
                  color: VistoraColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.category,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${DateFormat.yMMMd().format(e.date)} • ${e.partyName ?? 'No party'}',
                      style: const TextStyle(color: VistoraColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xff171b31),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _detailMetric('Taxable value', cash(e.subtotal)),
                  _detailMetric(
                    'GST',
                    cash(e.cgstAmount + e.sgstAmount + e.igstAmount),
                  ),
                  _detailMetric('Grand total', cash(e.total), accent: true),
                  _detailMetric(
                    'Payment mode',
                    e.paymentMode.replaceAll('_', ' '),
                  ),
                  if (e.referenceNo != null)
                    _detailMetric('Reference', e.referenceNo!),
                  if (e.bankName != null) _detailMetric('Bank', e.bankName!),
                ],
              ),
            ),
          ),
          if (e.gstType != 'none') ...[
            const SizedBox(height: 10),
            Text(
              e.gstType == 'igst'
                  ? 'IGST ${e.igstPercent}%: ${cash(e.igstAmount)}'
                  : 'CGST ${e.cgstPercent}%: ${cash(e.cgstAmount)}  •  SGST ${e.sgstPercent}%: ${cash(e.sgstAmount)}',
              style: const TextStyle(
                color: Color(0xff70ddff),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Components',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final component in e.components)
            Card(
              child: ListTile(
                title: Text(component.description),
                subtitle: Text(
                  '${component.quantity} × ${cash(component.unitPrice)}\n'
                  '${component.gstIncluded ? 'GST included' : 'GST added'} • Taxable ${cash(component.taxableAmount)} • GST ${cash(component.taxAmount)}',
                ),
                trailing: Text(
                  cash(component.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          if (e.description != null) ...[
            const SizedBox(height: 12),
            Text(
              e.description!,
              style: const TextStyle(color: VistoraColors.muted),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _detailMetric(String label, String value, {bool accent = false}) =>
      SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: VistoraColors.muted)),
            Text(
              value,
              style: TextStyle(
                fontSize: accent ? 19 : 15,
                fontWeight: FontWeight.w900,
                color: accent ? VistoraColors.green : null,
              ),
            ),
          ],
        ),
      );

  Future<void> _edit([FinanceEntry? entry]) async {
    type = tabs.index == 2 || tabs.index == 3 ? 'expense' : 'income';
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VistoraColors.surface,
      builder: (_) => _FinanceEntrySheet(
        type: type,
        entry: entry,
        initialPaymentMode: tabs.index == 3 && entry == null ? 'card' : null,
        settings: settings,
        repo: repo,
      ),
    );
    if (changed == true) {
      await _entries();
      await _cardEntries();
      await _summary();
    }
  }

  Future<void> _delete(FinanceEntry e) async {
    if (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete record?'),
            content: const Text(
              'The change will remain visible in the audit trail.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) !=
        true) {
      return;
    }
    try {
      await repo.delete(e.id);
      await _entries();
      await _cardEntries();
      await _summary();
    } catch (x) {
      _error(x);
    }
  }

  Future<void> _generate(FinanceEntry e) async {
    try {
      await repo.generateInvoice(e.id, e.date);
      await _entries();
    } catch (x) {
      _error(x);
    }
  }

  Future<void> _invoice(int id) async {
    try {
      final d = await repo.invoice(id);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => _InvoiceDialog(data: d, repo: repo),
        );
      }
    } catch (x) {
      _error(x);
    }
  }

  Future<void> _export() async {
    try {
      final bytes = await repo.export(type: type, year: year, month: month),
          dir = await getTemporaryDirectory(),
          file = File('${dir.path}/Vistora-Finance-$type-$year.csv');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (x) {
      _error(x);
    }
  }

  Future<void> _exportCards() async {
    try {
      final bytes = await repo.export(
            type: 'expense',
            year: year,
            month: month,
            paymentMode: 'card',
          ),
          dir = await getTemporaryDirectory(),
          file = File('${dir.path}/Vistora-Credit-Cards-$year.csv');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (x) {
      _error(x);
    }
  }

  Widget _settings() => _FinanceSettingsForm(
    value: settings,
    onSave: (v) async {
      try {
        await repo.updateSettings(v);
        settings = v;
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finance settings saved.')),
        );
      } catch (x) {
        _error(x);
      }
    },
  );

  Widget _audit() => FutureBuilder<List<Map<String, dynamic>>>(
    future: auditFuture ??= repo.audit(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text(snapshot.error.toString()));
      }
      final rows = snapshot.data ?? const [];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Immutable audit trail',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Every Finance Hub change remains traceable.',
            style: TextStyle(color: VistoraColors.muted),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: Text('No finance activity yet.')),
            )
          else
            for (final row in rows)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.history, size: 18),
                  ),
                  title: Text('${row['action'] ?? 'Finance activity'}'),
                  subtitle: Text(
                    '${(row['actor'] is Map ? row['actor']['name'] : null) ?? 'System'} • ${row['entity_type'] ?? ''} #${row['entity_id'] ?? ''}',
                  ),
                  trailing: Text(
                    DateFormat.MMMd().add_jm().format(
                      DateTime.parse(row['occurred_at'].toString()).toLocal(),
                    ),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: VistoraColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class _FinanceEntrySheet extends StatefulWidget {
  const _FinanceEntrySheet({
    required this.type,
    required this.settings,
    required this.repo,
    this.entry,
    this.initialPaymentMode,
  });
  final String type;
  final FinanceSettings settings;
  final FinanceRepository repo;
  final FinanceEntry? entry;
  final String? initialPaymentMode;
  @override
  State<_FinanceEntrySheet> createState() => _FinanceEntrySheetState();
}

class _FinanceEntrySheetState extends State<_FinanceEntrySheet> {
  final form = GlobalKey<FormState>();
  late DateTime date;
  late String mode, gst;
  late bool invoice;
  bool saving = false;
  final category = TextEditingController(),
      party = TextEditingController(),
      email = TextEditingController(),
      gstin = TextEditingController(),
      address = TextEditingController(),
      reference = TextEditingController(),
      cheque = TextEditingController(),
      bank = TextEditingController(),
      cardIssuer = TextEditingController(),
      cardHolder = TextEditingController(),
      cardLastFour = TextEditingController(),
      description = TextEditingController();
  final components = <List<TextEditingController>>[];
  final componentGstIncluded = <bool>[];
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    date = e?.date ?? DateTime.now();
    mode = e?.paymentMode ?? widget.initialPaymentMode ?? 'cash';
    gst = e?.gstType ?? 'none';
    invoice = false;
    category.text = e?.category ?? '';
    party.text = e?.partyName ?? '';
    email.text = e?.partyEmail ?? '';
    gstin.text = e?.partyGstin ?? '';
    address.text = e?.partyAddress ?? '';
    reference.text = e?.referenceNo ?? '';
    cheque.text = e?.chequeNo ?? '';
    bank.text = e?.bankName ?? '';
    cardIssuer.text = e?.cardIssuer ?? '';
    cardHolder.text = e?.cardHolderName ?? '';
    cardLastFour.text = e?.cardLastFour ?? '';
    description.text = e?.description ?? '';
    for (final c in e?.components ?? const <FinanceComponent>[]) {
      _add(c);
    }
    if (components.isEmpty) {
      _add();
    }
  }

  void _add([FinanceComponent? c]) {
    components.add([
      TextEditingController(text: c?.description),
      TextEditingController(text: c?.hsnSac),
      TextEditingController(text: '${c?.quantity ?? 1}'),
      TextEditingController(text: c == null ? '' : '${c.unitPrice}'),
    ]);
    componentGstIncluded.add(c?.gstIncluded ?? false);
  }

  double get _gstRate => gst == 'igst'
      ? widget.settings.igst
      : gst == 'cgst_sgst'
      ? widget.settings.cgst + widget.settings.sgst
      : 0;

  ({double taxable, double tax, double total}) _componentAmounts(int index) {
    final qty = double.tryParse(components[index][2].text) ?? 0;
    final unitPrice = double.tryParse(components[index][3].text) ?? 0;
    final entered = qty * unitPrice;
    if (_gstRate <= 0) return (taxable: entered, tax: 0, total: entered);
    if (componentGstIncluded[index]) {
      final taxable = entered / (1 + (_gstRate / 100));
      return (taxable: taxable, tax: entered - taxable, total: entered);
    }
    final tax = entered * _gstRate / 100;
    return (taxable: entered, tax: tax, total: entered + tax);
  }

  ({double taxable, double tax, double total}) get _entryAmounts {
    double taxable = 0, tax = 0, total = 0;
    for (var i = 0; i < components.length; i++) {
      final value = _componentAmounts(i);
      taxable += value.taxable;
      tax += value.tax;
      total += value.total;
    }
    return (taxable: taxable, tax: tax, total: total);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: form,
      child: ListView(
        children: [
          Text(
            '${widget.entry == null ? 'Record' : 'Edit'} ${widget.type}',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(DateFormat.yMMMd().format(date))),
              TextButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (d != null) setState(() => date = d);
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Date'),
              ),
            ],
          ),
          TextFormField(
            controller: category,
            decoration: const InputDecoration(labelText: 'Category'),
            validator: _required,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: party,
            decoration: const InputDecoration(labelText: 'Party / client'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Client email'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: gstin,
            decoration: const InputDecoration(labelText: 'Client GSTIN'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Party address'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField(
            initialValue: mode,
            decoration: const InputDecoration(labelText: 'Payment mode'),
            items:
                const [
                      'cash',
                      'cheque',
                      'bank_transfer',
                      'neft',
                      'rtgs',
                      'upi',
                      'card',
                      'other',
                    ]
                    .map(
                      (x) => DropdownMenuItem(
                        value: x,
                        child: Text(
                          x == 'card' ? 'Credit Card' : x.replaceAll('_', ' '),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => mode = v!),
          ),
          const SizedBox(height: 10),
          if (mode == 'cheque')
            TextFormField(
              controller: cheque,
              decoration: const InputDecoration(labelText: 'Cheque number'),
              validator: _required,
            )
          else
            TextFormField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Reference / transaction ID',
              ),
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: bank,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          if (mode == 'card') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xff292250),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xff6558a0)),
              ),
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.credit_card, color: Color(0xffb8a8ff)),
                    title: Text(
                      'Credit card details',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'This payment is tracked separately and excluded from operating expense and P&L.',
                    ),
                  ),
                  TextFormField(
                    controller: cardIssuer,
                    decoration: const InputDecoration(
                      labelText: 'Card issuer / bank',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cardHolder,
                    decoration: const InputDecoration(
                      labelText: 'Card holder name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cardLastFour,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 card digits',
                    ),
                    validator: (v) =>
                        v != null &&
                            v.isNotEmpty &&
                            !RegExp(r'^\d{4}$').hasMatch(v)
                        ? 'Enter exactly 4 digits'
                        : null,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Billing components',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => setState(_add),
                icon: const Icon(Icons.add_circle, color: VistoraColors.orange),
              ),
            ],
          ),
          for (int i = 0; i < components.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      controller: components[i][0],
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: components[i][1],
                      decoration: const InputDecoration(labelText: 'HSN / SAC'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: components[i][2],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            validator: _number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: components[i][3],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Unit price',
                            ),
                            validator: _number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          onPressed: components.length == 1
                              ? null
                              : () => setState(() {
                                  components.removeAt(i);
                                  componentGstIncluded.removeAt(i);
                                }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    if (widget.settings.gstEnabled && gst != 'none') ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: componentGstIncluded[i],
                        onChanged: (value) => setState(
                          () => componentGstIncluded[i] = value ?? false,
                        ),
                        title: const Text('GST Included'),
                        subtitle: Text(
                          componentGstIncluded[i]
                              ? 'GST is extracted from this entered amount.'
                              : 'GST is added over this entered amount.',
                        ),
                      ),
                      Builder(
                        builder: (_) {
                          final value = _componentAmounts(i);
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff10263a),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xff17688a),
                              ),
                            ),
                            child: Text(
                              'Taxable ${_money(value.taxable)}  •  GST ${_money(value.tax)}  •  Total ${_money(value.total)}',
                              style: const TextStyle(
                                color: Color(0xff70ddff),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (widget.settings.gstEnabled)
            DropdownButtonFormField(
              initialValue: gst,
              decoration: const InputDecoration(labelText: 'GST treatment'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No GST')),
                DropdownMenuItem(
                  value: 'cgst_sgst',
                  child: Text('CGST + SGST'),
                ),
                DropdownMenuItem(value: 'igst', child: Text('IGST')),
              ],
              onChanged: (v) => setState(() => gst = v!),
            ),
          if (widget.settings.gstEnabled) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (_) {
                final value = _entryAmounts;
                final cgst = gst == 'cgst_sgst' ? value.tax / 2 : 0.0;
                final sgst = gst == 'cgst_sgst' ? value.tax - cgst : 0.0;
                final igst = gst == 'igst' ? value.tax : 0.0;
                return Card(
                  color: const Color(0xff10263a),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live GST preview',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text('Taxable value: ${_money(value.taxable)}'),
                        if (gst == 'cgst_sgst') ...[
                          Text('CGST: ${_money(cgst)}'),
                          Text('SGST: ${_money(sgst)}'),
                        ],
                        if (gst == 'igst') Text('IGST: ${_money(igst)}'),
                        const Divider(),
                        Text(
                          'Grand total: ${_money(value.total)}',
                          style: const TextStyle(
                            color: VistoraColors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          if (widget.type == 'income')
            SwitchListTile(
              value: invoice,
              onChanged: (v) => setState(() => invoice = v),
              title: const Text('Generate Tax Invoice'),
              subtitle: const Text(
                'You can view, print, download or email it after saving.',
              ),
            ),
          TextFormField(
            controller: description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes / description'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save finance entry'),
          ),
        ],
      ),
    ),
  );
  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
  String? _number(String? v) =>
      (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a valid amount' : null;
  String _money(double value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.repo.save({
        'entry_type': widget.type,
        'entry_date': date.toIso8601String().split('T').first,
        'category': category.text.trim(),
        'party_name': party.text.trim().isEmpty ? null : party.text.trim(),
        'party_email': email.text.trim().isEmpty ? null : email.text.trim(),
        'party_gstin': gstin.text.trim().isEmpty ? null : gstin.text.trim(),
        'party_address': address.text.trim().isEmpty
            ? null
            : address.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        'payment_mode': mode,
        'reference_no': reference.text.trim().isEmpty
            ? null
            : reference.text.trim(),
        'cheque_no': cheque.text.trim().isEmpty ? null : cheque.text.trim(),
        'bank_name': bank.text.trim().isEmpty ? null : bank.text.trim(),
        'card_issuer': mode == 'card' && cardIssuer.text.trim().isNotEmpty
            ? cardIssuer.text.trim()
            : null,
        'card_holder_name': mode == 'card' && cardHolder.text.trim().isNotEmpty
            ? cardHolder.text.trim()
            : null,
        'card_last_four': mode == 'card' && cardLastFour.text.trim().isNotEmpty
            ? cardLastFour.text.trim()
            : null,
        'gst_type': gst,
        'cgst_percent': widget.settings.cgst,
        'sgst_percent': widget.settings.sgst,
        'igst_percent': widget.settings.igst,
        'components': [
          for (int i = 0; i < components.length; i++)
            {
              'description': components[i][0].text.trim(),
              'hsn_sac': components[i][1].text.trim().isEmpty
                  ? null
                  : components[i][1].text.trim(),
              'quantity': double.parse(components[i][2].text),
              'unit_price': double.parse(components[i][3].text),
              'gst_included': componentGstIncluded[i],
            },
        ],
        'generate_invoice': invoice,
        'invoice_date': invoice
            ? date.toIso8601String().split('T').first
            : null,
      }, id: widget.entry?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _FinanceSettingsForm extends StatefulWidget {
  const _FinanceSettingsForm({required this.value, required this.onSave});
  final FinanceSettings value;
  final Future<void> Function(FinanceSettings) onSave;
  @override
  State<_FinanceSettingsForm> createState() => _FinanceSettingsFormState();
}

class _FinanceSettingsFormState extends State<_FinanceSettingsForm> {
  late final email = TextEditingController(text: widget.value.email),
      website = TextEditingController(text: widget.value.website),
      address = TextEditingController(text: widget.value.address),
      prefix = TextEditingController(text: widget.value.prefix),
      cgst = TextEditingController(text: '${widget.value.cgst}'),
      sgst = TextEditingController(text: '${widget.value.sgst}'),
      igst = TextEditingController(text: '${widget.value.igst}');
  late bool enabled = widget.value.gstEnabled;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Invoice identity & GST',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
      ),
      const Text(
        'These details appear on every Finance Hub Tax Invoice.',
        style: TextStyle(color: VistoraColors.muted),
      ),
      const SizedBox(height: 18),
      TextField(
        controller: email,
        decoration: const InputDecoration(labelText: 'Contact email'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: website,
        decoration: const InputDecoration(labelText: 'Website'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: address,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Billing address'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: prefix,
        maxLength: 4,
        decoration: const InputDecoration(labelText: 'Invoice prefix'),
      ),
      SwitchListTile(
        value: enabled,
        onChanged: (v) => setState(() => enabled = v),
        title: const Text('Enable GST invoicing'),
      ),
      if (enabled)
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: cgst,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CGST %'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: sgst,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'SGST %'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: igst,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'IGST %'),
              ),
            ),
          ],
        ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => widget.onSave(
          FinanceSettings(
            email: email.text.trim().isEmpty ? null : email.text.trim(),
            website: website.text.trim().isEmpty ? null : website.text.trim(),
            address: address.text.trim().isEmpty ? null : address.text.trim(),
            prefix: prefix.text.trim(),
            gstEnabled: enabled,
            cgst: double.tryParse(cgst.text) ?? 0,
            sgst: double.tryParse(sgst.text) ?? 0,
            igst: double.tryParse(igst.text) ?? 0,
          ),
        ),
        icon: const Icon(Icons.save),
        label: const Text('Save Finance Settings'),
      ),
    ],
  );
}

class _InvoiceDialog extends StatelessWidget {
  const _InvoiceDialog({required this.data, required this.repo});
  final Map<String, dynamic> data;
  final FinanceRepository repo;
  @override
  Widget build(BuildContext context) {
    final inv = Map<String, dynamic>.from(data['invoice'] as Map),
        entry = Map<String, dynamic>.from(data['entry'] as Map),
        seller = Map<String, dynamic>.from(
          inv['seller_snapshot_json'] as Map? ?? {},
        ),
        buyer = Map<String, dynamic>.from(
          inv['buyer_snapshot_json'] as Map? ?? {},
        ),
        components = (inv['components_snapshot_json'] as List? ?? const []);
    String money(v) => NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    ).format(double.tryParse('$v') ?? 0);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tax Invoice'),
          actions: [
            IconButton(
              tooltip: 'Print / save PDF',
              onPressed: () => Printing.layoutPdf(
                name: 'Tax-Invoice-${inv['invoice_no']}',
                onLayout: (_) => _pdf(inv, entry, seller, buyer, components),
              ),
              icon: const Icon(Icons.print_outlined),
            ),
            IconButton(
              tooltip: 'Download / share PDF',
              onPressed: () async => Printing.sharePdf(
                bytes: await _pdf(inv, entry, seller, buyer, components),
                filename: 'Tax-Invoice-${inv['invoice_no']}.pdf',
              ),
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              onPressed: () async {
                final c = TextEditingController(
                  text: '${buyer['email'] ?? ''}',
                );
                final to = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Email invoice'),
                    content: TextField(
                      controller: c,
                      decoration: const InputDecoration(
                        labelText: 'Recipient email',
                      ),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context, c.text.trim()),
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                );
                if (to != null && to.isNotEmpty) {
                  await repo.emailInvoice(inv['id'] as int, to);
                }
              },
              icon: const Icon(Icons.email_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              '${seller['company_name'] ?? ''}',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: VistoraColors.orange,
              ),
            ),
            Text(
              '${seller['address'] ?? ''}\nGSTIN: ${seller['gstin'] ?? 'Not provided'}',
            ),
            const Divider(height: 32),
            const Text(
              'TAX INVOICE',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            Text(
              '${inv['invoice_no']} • ${DateFormat.yMMMd().format(DateTime.parse(inv['invoice_date'].toString()))}',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Bill to\n${buyer['name'] ?? 'Client'}\n${buyer['address'] ?? ''}\nGSTIN: ${buyer['gstin'] ?? 'Not provided'}',
                ),
              ),
            ),
            for (final raw in components)
              ListTile(
                title: Text('${raw['description']}'),
                subtitle: Text(
                  '${raw['quantity']} × ${money(raw['unit_price'])}',
                ),
                trailing: Text(
                  money(raw['amount']),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            const Divider(),
            ListTile(
              title: const Text('Subtotal'),
              trailing: Text(money(entry['subtotal'])),
            ),
            if ((double.tryParse('${entry['cgst_amount']}') ?? 0) > 0) ...[
              ListTile(
                title: Text('CGST ${entry['cgst_percent']}%'),
                trailing: Text(money(entry['cgst_amount'])),
              ),
              ListTile(
                title: Text('SGST ${entry['sgst_percent']}%'),
                trailing: Text(money(entry['sgst_amount'])),
              ),
            ],
            if ((double.tryParse('${entry['igst_amount']}') ?? 0) > 0)
              ListTile(
                title: Text('IGST ${entry['igst_percent']}%'),
                trailing: Text(money(entry['igst_amount'])),
              ),
            Card(
              color: VistoraColors.orange.withValues(alpha: .15),
              child: ListTile(
                title: const Text(
                  'Invoice total',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                trailing: Text(
                  money(entry['total_amount']),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: VistoraColors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _pdf(
    Map<String, dynamic> inv,
    Map<String, dynamic> entry,
    Map<String, dynamic> seller,
    Map<String, dynamic> buyer,
    List<dynamic> components,
  ) async {
    final document = pw.Document();
    String amount(Object? value) =>
        'Rs ${NumberFormat('#,##0.00', 'en_IN').format(double.tryParse('$value') ?? 0)}';
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${seller['company_name'] ?? ''}',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepOrange,
                      ),
                    ),
                    pw.Text('${seller['address'] ?? ''}'),
                    pw.Text('GSTIN: ${seller['gstin'] ?? 'Not provided'}'),
                    pw.Text(
                      '${seller['email'] ?? ''} ${seller['website'] ?? ''}',
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
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('${inv['invoice_no']}'),
                  pw.Text(
                    DateFormat.yMMMd().format(
                      DateTime.parse(inv['invoice_date'].toString()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Divider(color: PdfColors.deepOrange, thickness: 3),
          pw.SizedBox(height: 16),
          pw.Text(
            'BILL TO',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            '${buyer['name'] ?? 'Client'}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('${buyer['address'] ?? ''}'),
          pw.Text('GSTIN: ${buyer['gstin'] ?? 'Not provided'}'),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const ['Description', 'HSN/SAC', 'Qty', 'Rate', 'Amount'],
            data: components
                .map(
                  (raw) => [
                    raw['description'],
                    raw['hsn_sac'] ?? '-',
                    raw['quantity'],
                    amount(raw['unit_price']),
                    amount(raw['amount']),
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey900,
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 260,
              child: pw.Column(
                children: [
                  _pdfTotal('Subtotal', amount(entry['subtotal'])),
                  if ((double.tryParse('${entry['cgst_amount']}') ?? 0) >
                      0) ...[
                    _pdfTotal(
                      'CGST ${entry['cgst_percent']}%',
                      amount(entry['cgst_amount']),
                    ),
                    _pdfTotal(
                      'SGST ${entry['sgst_percent']}%',
                      amount(entry['sgst_amount']),
                    ),
                  ],
                  if ((double.tryParse('${entry['igst_amount']}') ?? 0) > 0)
                    _pdfTotal(
                      'IGST ${entry['igst_percent']}%',
                      amount(entry['igst_amount']),
                    ),
                  pw.Divider(),
                  _pdfTotal('TOTAL', amount(entry['total_amount']), bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfTotal(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
            pw.Text(
              value,
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ],
        ),
      );
}
