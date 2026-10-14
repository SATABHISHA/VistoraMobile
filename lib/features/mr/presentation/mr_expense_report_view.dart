import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/mr/data/mr_repository.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_providers.dart';

class MrExpenseReportView extends ConsumerStatefulWidget {
  const MrExpenseReportView({super.key, this.reviewable = false});

  final bool reviewable;

  @override
  ConsumerState<MrExpenseReportView> createState() =>
      _MrExpenseReportViewState();
}

class _MrExpenseReportViewState extends ConsumerState<MrExpenseReportView> {
  final _search = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic> _response = {};
  String? _status;
  int? _year;
  int? _month;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 1;
  int _perPage = 5;
  String _viewMode = 'summary';
  int? _employeeId;
  bool _loading = true;
  bool _exporting = false;
  bool _exportingAll = false;
  bool _mutatingMonth = false;
  bool _loadingReviewClaims = false;
  String? _error;

  MrRepository get _repository => ref.read(mrRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (widget.reviewable) {
      final now = DateTime.now();
      _year = now.year;
      _month = now.month;
    }
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String? get _from =>
      _dateFrom == null ? null : DateFormat('yyyy-MM-dd').format(_dateFrom!);
  String? get _to =>
      _dateTo == null ? null : DateFormat('yyyy-MM-dd').format(_dateTo!);

  Future<void> _refresh({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repository.expenseReport(
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status,
        employeeId: _employeeId,
        year: _year,
        month: _month,
        dateFrom: _from,
        dateTo: _to,
        reviewable: widget.reviewable,
        view: _viewMode,
        page: _page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _response = asMap(response['data']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = from ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? (from ? _dateTo : _dateFrom) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: from ? 'Period starts on' : 'Period ends on',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
    await _refresh(resetPage: true);
  }

  Future<void> _export({bool details = false, int? employeeId}) async {
    setState(() => _exporting = true);
    try {
      final response = await _repository.exportExpenseReport(
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status,
        employeeId: employeeId,
        year: _year,
        month: _month,
        dateFrom: _from,
        dateTo: _to,
        details: details,
        reviewable: widget.reviewable,
      );
      final bytes = response.data ?? const <int>[];
      final isXlsx =
          response.headers.value('content-type')?.contains('spreadsheetml') ??
          false;
      final directory = await getTemporaryDirectory();
      final period = _from != null && _to != null
          ? '${_from}_to_$_to'
          : _from != null
          ? 'from_$_from'
          : _to != null
          ? 'to_$_to'
          : _year != null
          ? 'year_$_year'
          : _month != null
          ? 'month_$_month'
          : 'till_date';
      final file = File(
        '${directory.path}${Platform.pathSeparator}Vistora-MR-Expense-${employeeId == null ? '' : 'Employee-$employeeId-'}${details ? 'Details' : 'Summary'}-$period.${isXlsx ? 'xlsx' : 'csv'}',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Expense ${details ? 'details' : 'summary'} saved: ${file.path}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportAll() async {
    setState(() => _exportingAll = true);
    try {
      final response = await _repository.exportAllExpenseReport(
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status,
        year: _year,
        month: _month,
        dateFrom: _from,
        dateTo: _to,
        reviewable: widget.reviewable,
      );
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}Vistora-MR-Expenses-All-${_year ?? 'till-date'}${_month == null ? '' : '-$_month'}.zip',
      );
      await file.writeAsBytes(response.data ?? const <int>[], flush: true);
      await OpenFilex.open(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All MR expense reports saved: ${file.path}')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _exportingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _response;
    final page = asMap(data['items']);
    final rows = asList(page['data']).map(asMap).toList();
    final summary = asMap(data['summary']);
    final pageNumber = asInt(page['current_page'], _page);
    final lastPage = asInt(page['last_page'], 1);
    final total = asInt(page['total'], rows.length);
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          _reportHero(colors),
          const SizedBox(height: 14),
          _filters(colors),
          const SizedBox(height: 14),
          if (_loadingReviewClaims) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xff20295a), Color(0xff102d40)],
                ),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .35),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Loading submitted claims for the selected month…',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _loadError(colors)
          else ...[
            _summaryCard(summary, colors),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              _emptyState(colors)
            else
              ...rows.indexed.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _expenseCard(entry.$2, entry.$1, colors),
                ),
              ),
            if (total > 0) _pager(pageNumber, lastPage, total, colors),
          ],
        ],
      ),
    );
  }

  Widget _reportHero(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xff20295a), Color(0xff102d40), Color(0xff171b3d)],
      ),
      border: Border.all(color: colors.primary.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.insights_rounded, color: colors.primary),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TENANT MR REPORTING',
                style: TextStyle(
                  color: VistoraColors.muted,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Employee expenses',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'Review complete claim calculations for your selected period.',
                style: TextStyle(color: VistoraColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _filters(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
    ),
    child: Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 350),
              () => _refresh(resetPage: true),
            );
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search employee, ID, route or area',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  for (final value in const [
                    'draft',
                    'submitted',
                    'approved',
                    'rejected',
                  ])
                    DropdownMenuItem<String?>(
                      value: value,
                      child: Text(_title(value)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _status = value);
                  _refresh(resetPage: true);
                },
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _year,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All years'),
                  ),
                  for (var year = DateTime.now().year; year >= 2020; year--)
                    DropdownMenuItem<int?>(value: year, child: Text('$year')),
                ],
                onChanged: (value) {
                  setState(() => _year = value);
                  _refresh(resetPage: true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All months'),
                  ),
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem<int?>(
                      value: month,
                      child: Text(
                        DateFormat('MMMM').format(DateTime(2020, month)),
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _month = value);
                  _refresh(resetPage: true);
                },
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _perPage,
                decoration: const InputDecoration(labelText: 'Per page'),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 per page')),
                  DropdownMenuItem(value: 5, child: Text('5 per page')),
                  DropdownMenuItem(value: 10, child: Text('10 per page')),
                  DropdownMenuItem(value: 20, child: Text('20 per page')),
                  DropdownMenuItem(value: 50, child: Text('50 per page')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _perPage = value);
                  _refresh(resetPage: true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(from: true),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _dateFrom == null
                      ? 'From date'
                      : DateFormat('dd MMM yy').format(_dateFrom!),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(from: false),
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dateTo == null
                      ? 'To date'
                      : DateFormat('dd MMM yy').format(_dateTo!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'details',
                icon: Icon(Icons.view_agenda_outlined),
                label: Text('Details view'),
              ),
              ButtonSegment(
                value: 'summary',
                icon: Icon(Icons.summarize_outlined),
                label: Text('Summary view'),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() => _viewMode = selection.first);
              _refresh(resetPage: true);
            },
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_employeeId != null)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _employeeId = null;
                    _viewMode = 'summary';
                  });
                  _refresh(resetPage: true);
                },
                icon: const Icon(Icons.groups_outlined),
                label: const Text('All employees'),
              ),
            IconButton.filledTonal(
              tooltip: 'Clear all filters',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
            OutlinedButton.icon(
              onPressed: _exporting ? null : () => _export(),
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Summary'),
            ),
            FilledButton.icon(
              onPressed: _exporting ? null : () => _export(details: true),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text('Details'),
            ),
            OutlinedButton.icon(
              onPressed: _exportingAll ? null : _exportAll,
              icon: _exportingAll
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_zip_outlined),
              label: const Text('Export all ZIP'),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _clearFilters() async {
    _search.clear();
    setState(() {
      _status = null;
      _employeeId = null;
      _year = null;
      _month = null;
      _dateFrom = null;
      _dateTo = null;
    });
    await _refresh(resetPage: true);
  }

  Widget _summaryCard(Map<String, dynamic> summary, ColorScheme colors) {
    final count = asInt(summary['employee_count']);
    final claims = asInt(summary['claim_count']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count employees · $claims claims',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'TOTAL EXPENSE',
                  summary['total_expense'],
                  colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'ALLOWANCE',
                  summary['total_allowance'],
                  const Color(0xff68dda7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, Object? amount, Color accent) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xff0b1127),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: VistoraColors.muted,
            fontSize: 9,
            letterSpacing: .8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            _money(amount),
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _expenseCard(Map<String, dynamic> row, int index, ColorScheme colors) {
    final employee = asMap(row['employee']);
    final name =
        [employee['first_name'], employee['middle_name'], employee['last_name']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' ');
    final status = row['status']?.toString() ?? 'unknown';
    final statusCounts = {
      'Approved': asInt(row['approved_count']),
      'Submitted': asInt(row['submitted_count']),
      'Draft': asInt(row['draft_count']),
      'Rejected': asInt(row['rejected_count']),
    }.entries.where((entry) => entry.value > 0).toList();
    final statusColor = switch (status) {
      'approved' => const Color(0xff55d99b),
      'rejected' => const Color(0xffff6b82),
      'submitted' => const Color(0xffffc166),
      _ => colors.primary,
    };
    final start = row['period_start']?.toString();
    final end = row['period_end']?.toString();
    if (_viewMode == 'summary') {
      return _summaryExpenseCard(
        row,
        index,
        colors,
        name,
        status,
        statusCounts,
        statusColor,
        start,
        end,
      );
    }
    return _detailExpenseCard(row, index, colors, name, status, statusColor);
  }

  Widget _detailExpenseCard(
    Map<String, dynamic> row,
    int index,
    ColorScheme colors,
    String name,
    String status,
    Color statusColor,
  ) {
    final employee = asMap(row['employee']);
    row = {
      ...row,
      'claim_count': 1,
      'allowance_total': row['allowance_amount'],
      'working_allowance_total': row['working_allowance_amount'],
      'fare_total': row['fare_amount'],
      'courier_total': row['courier_charges'],
      'other_expenses_total': row['other_doctor_expenses'],
    };
    final statusCounts = <MapEntry<String, int>>[];
    final start = row['expense_date']?.toString();
    final end = start;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .96, end: 1),
      duration: Duration(milliseconds: 260 + (index % 5) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff171f3b), Color(0xff11172d)],
          ),
          border: Border.all(color: statusColor.withValues(alpha: .28)),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: .055),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primary.withValues(alpha: .18),
                  child: Text(
                    (name.isEmpty ? 'E' : name[0]).toUpperCase(),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Employee' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${employee['emp_code'] ?? 'No employee ID'} · ${asInt(row['claim_count'])} expense(s)',
                        style: const TextStyle(
                          color: VistoraColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: .35),
                    ),
                  ),
                  child: Text(
                    _title(status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [Color(0x2aef762f), Color(0x222977d1)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_shortDate(start)} – ${_shortDate(end)}',
                      style: const TextStyle(
                        color: VistoraColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    _money(row['total_expense']),
                    style: const TextStyle(
                      color: Color(0xff79e1b3),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (statusCounts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final entry in statusCounts)
                    _statusChip(entry.key, entry.value, colors),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _amountChip('Fixed allowance', row['allowance_total']),
                _amountChip(
                  'Working allowance',
                  row['working_allowance_total'],
                ),
                _amountChip('Total allowance', row['total_allowance']),
                _amountChip('Fare', row['fare_total']),
                _amountChip('Courier', row['courier_total']),
                _amountChip(
                  'Other doctor expenses',
                  row['other_expenses_total'],
                ),
              ],
            ),
            if ((row['remarks']?.toString().trim().isNotEmpty ?? false) ||
                (row['review_notes']?.toString().trim().isNotEmpty ?? false) ||
                (row['rollback_notes']?.toString().trim().isNotEmpty ??
                    false)) ...[
              const SizedBox(height: 12),
              if (row['remarks']?.toString().trim().isNotEmpty ?? false)
                _detailLine('Remarks', row['remarks'].toString()),
              if (row['review_notes']?.toString().trim().isNotEmpty ?? false)
                _detailLine('Review remarks', row['review_notes'].toString()),
              if (row['rollback_notes']?.toString().trim().isNotEmpty ?? false)
                _detailLine(
                  'Rollback remarks',
                  row['rollback_notes'].toString(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xff0d142b),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VistoraColors.muted.withValues(alpha: .18)),
    ),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: VistoraColors.muted, fontSize: 12),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  Widget _summaryExpenseCard(
    Map<String, dynamic> row,
    int index,
    ColorScheme colors,
    String name,
    String status,
    List<MapEntry<String, int>> statusCounts,
    Color statusColor,
    String? start,
    String? end,
  ) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .96, end: 1),
    duration: Duration(milliseconds: 260 + (index % 5) * 45),
    curve: Curves.easeOutCubic,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff202653), Color(0xff11172d)],
        ),
        border: Border.all(color: statusColor.withValues(alpha: .3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: .18),
                child: Text(
                  (name.isEmpty ? 'E' : name[0]).toUpperCase(),
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Employee' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${employeeId(row)} · ${asInt(row['claim_count'])} expense(s)',
                      style: const TextStyle(
                        color: VistoraColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0x2aef762f), Color(0x222977d1)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total expense · ${_shortDate(start)} – ${_shortDate(end)}',
                    style: const TextStyle(
                      color: VistoraColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  _money(row['total_expense']),
                  style: const TextStyle(
                    color: Color(0xff79e1b3),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (statusCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in statusCounts)
                  _statusChip(entry.key, entry.value, colors),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _amountChip('Total allowance', row['total_allowance']),
              _amountChip(
                'Travel + other',
                asDouble(row['fare_total']) +
                    asDouble(row['courier_total']) +
                    asDouble(row['other_expenses_total']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final id = _numericEmployeeId(row);
                  if (id == null) return;
                  setState(() {
                    _employeeId = id;
                    _viewMode = 'details';
                  });
                  _refresh(resetPage: true);
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View breakdown'),
              ),
              OutlinedButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _export(
                        details: true,
                        employeeId: _numericEmployeeId(row),
                      ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export Excel'),
              ),
              if (widget.reviewable && asInt(row['submitted_count']) > 0)
                FilledButton.icon(
                  onPressed: _mutatingMonth || _loadingReviewClaims
                      ? null
                      : () => _monthAction(row, 'approve'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve all submitted'),
                ),
              if (widget.reviewable && asInt(row['submitted_count']) > 0)
                OutlinedButton.icon(
                  onPressed: _mutatingMonth || _loadingReviewClaims
                      ? null
                      : () => _rejectMonth(row),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject claims'),
                ),
              if (widget.reviewable &&
                  (asInt(row['approved_count']) > 0 ||
                      asInt(row['rejected_count']) > 0))
                TextButton.icon(
                  onPressed: _mutatingMonth || _loadingReviewClaims
                      ? null
                      : () => _monthAction(row, 'revert'),
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Revert review'),
                ),
              if (widget.reviewable && (_month == null || _year == null))
                const Text(
                  'Review actions will ask you to choose the exact year and month.',
                  style: TextStyle(color: VistoraColors.muted, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _statusBadge(String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      _title(value),
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10),
    ),
  );

  String employeeId(Map<String, dynamic> row) =>
      asMap(row['employee'])['emp_code']?.toString() ?? 'No employee ID';

  int? _numericEmployeeId(Map<String, dynamic> row) {
    final value = row['employee_id'] ?? asMap(row['employee'])['id'];
    return int.tryParse(value?.toString() ?? '');
  }

  Future<Map<String, int>?> _chooseReviewPeriod(String action) {
    final now = DateTime.now();
    var selectedYear = _year ?? now.year;
    var selectedMonth = _month ?? now.month;
    final actionLabel = switch (action) {
      'approve' => 'approve',
      'reject' => 'reject',
      _ => 'revert review for',
    };
    return showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('Choose review month'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select the exact month to $actionLabel. This employee card may contain claims from more than one month.',
                  style: const TextStyle(color: VistoraColors.muted),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [
                    for (var year = now.year; year >= 2020; year--)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      dialogSetState(() => selectedYear = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    for (var month = 1; month <= 12; month++)
                      DropdownMenuItem(
                        value: month,
                        child: Text(
                          DateFormat('MMMM').format(DateTime(2020, month)),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      dialogSetState(() => selectedMonth = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'year': selectedYear,
                'month': selectedMonth,
              }),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectMonth(Map<String, dynamic> row) async {
    final employee = _numericEmployeeId(row);
    if (employee == null) {
      _showError(
        'The employee for this expense summary could not be identified.',
      );
      return;
    }
    var year = _year;
    var month = _month;
    if (year == null || month == null) {
      final period = await _chooseReviewPeriod('reject');
      if (period == null || !mounted) return;
      final selectedYear = period['year'];
      final selectedMonth = period['month'];
      if (selectedYear == null || selectedMonth == null) {
        _showError('Please select a valid review year and month.');
        return;
      }
      year = selectedYear;
      month = selectedMonth;
    }

    if (mounted) {
      setState(() => _loadingReviewClaims = true);
    }

    try {
      final claims = <Map<String, dynamic>>[];
      var pageNumber = 1;
      var lastPage = 1;
      do {
        final response = await _repository.expenseReport(
          employeeId: employee,
          year: year,
          month: month,
          reviewable: widget.reviewable,
          view: 'details',
          page: pageNumber,
          perPage: 100,
        );
        final data = asMap(response['data']);
        final page = asMap(data['items']);
        claims.addAll(
          asList(page['data'])
              .map(asMap)
              .where((claim) => claim['status']?.toString() == 'submitted'),
        );
        lastPage = asInt(page['last_page']) > 0
            ? asInt(page['last_page'])
            : pageNumber;
        pageNumber += 1;
      } while (pageNumber <= lastPage);

      if (mounted) {
        setState(() => _loadingReviewClaims = false);
      }

      if (claims.isEmpty) {
        await _showReviewNotice(
          'No submitted claims found',
          'There are no submitted claims available to reject for ${DateFormat('MMMM yyyy').format(DateTime(year, month))}. Choose another month and try again.',
        );
        return;
      }

      final selection = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          final notesController = TextEditingController();
          var rejectAll = true;
          final selected = <int>{};
          var claimPage = 1;
          var claimPageSize = 5;
          String? validation;
          return StatefulBuilder(
            builder: (context, dialogSetState) {
              final dialogHeight = math.min(
                MediaQuery.sizeOf(context).height * .65,
                620.0,
              );
              final lastClaimPage =
                  (claims.length + claimPageSize - 1) ~/ claimPageSize;
              final pageStart = (claimPage - 1) * claimPageSize;
              final visibleClaims = claims
                  .skip(pageStart)
                  .take(claimPageSize)
                  .toList();
              return AlertDialog(
                title: const Text('Reject employee claims'),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: dialogHeight,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const Text(
                        'Reject every submitted claim or choose only the claims that need correction. Remarks are required.',
                        style: TextStyle(color: VistoraColors.muted),
                      ),
                      const SizedBox(height: 10),
                      RadioListTile<bool>(
                        value: true,
                        groupValue: rejectAll,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reject all submitted claims'),
                        subtitle: Text(
                          '${claims.length} submitted claim(s) in this month',
                        ),
                        onChanged: (value) =>
                            dialogSetState(() => rejectAll = value ?? true),
                      ),
                      RadioListTile<bool>(
                        value: false,
                        groupValue: rejectAll,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reject specific claim(s)'),
                        subtitle: const Text('Select one or more claims below'),
                        onChanged: (value) =>
                            dialogSetState(() => rejectAll = value ?? false),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: ListView.builder(
                            key: ValueKey(
                              '$claimPage-$claimPageSize-$rejectAll',
                            ),
                            itemCount: visibleClaims.length,
                            itemBuilder: (context, index) {
                              final claim = visibleClaims[index];
                              final claimId = asInt(claim['id']);
                              final duty = _title(
                                claim['duty_type']?.toString() ?? '',
                              );
                              final brief =
                                  [
                                        duty,
                                        claim['area_covered']?.toString(),
                                        claim['mode_of_travel']?.toString(),
                                      ]
                                      .where(
                                        (value) =>
                                            value != null && value.isNotEmpty,
                                      )
                                      .join(' Â· ');
                              return CheckboxListTile(
                                value: selected.contains(claimId),
                                enabled: !rejectAll,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  '${_shortDate(claim['expense_date']?.toString())} Â· ${_money(claim['total_expense'])}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  brief.isEmpty ? 'Expense claim' : brief,
                                ),
                                onChanged: (checked) => dialogSetState(() {
                                  if (checked == true) {
                                    selected.add(claimId);
                                  } else {
                                    selected.remove(claimId);
                                  }
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${claims.length} submitted claims',
                              style: const TextStyle(
                                color: VistoraColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Text('Rows', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          DropdownButton<int>(
                            value: claimPageSize,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            items: const [3, 5, 10, 20, 50]
                                .map(
                                  (size) => DropdownMenuItem<int>(
                                    value: size,
                                    child: Text('$size'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              dialogSetState(() {
                                claimPageSize = value;
                                claimPage = 1;
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous claims',
                            onPressed: claimPage > 1
                                ? () => dialogSetState(() => claimPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                'Page $claimPage of $lastClaimPage',
                                key: ValueKey('$claimPage-$lastClaimPage'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: VistoraColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next claims',
                            onPressed: claimPage < lastClaimPage
                                ? () => dialogSetState(() => claimPage++)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Remarks (required)',
                          hintText: 'Explain what the MR needs to correct...',
                        ),
                      ),
                      if (validation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          validation!,
                          style: const TextStyle(
                            color: Color(0xffff8fa3),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final notes = notesController.text.trim();
                      if (notes.isEmpty) {
                        dialogSetState(
                          () => validation =
                              'Please enter remarks before rejecting claims.',
                        );
                        return;
                      }
                      if (!rejectAll && selected.isEmpty) {
                        dialogSetState(
                          () => validation =
                              'Select at least one claim to reject.',
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'reject_all': rejectAll,
                        'claim_ids': selected.toList(),
                        'notes': notes,
                      });
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || selection == null) return;

      final rejectAll = selection['reject_all'] == true;
      final claimIds = asList(
        selection['claim_ids'],
      ).map(asInt).where((id) => id > 0).toList();
      final count = rejectAll ? claims.length : claimIds.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm claim rejection'),
          content: Text(
            rejectAll
                ? 'All $count submitted claim(s) for this employee and month will be rejected.'
                : '$count selected claim(s) will be rejected. Other submitted claims will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reject claims'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _mutatingMonth = true);
      try {
        final response = await _repository.reviewExpenseMonth(
          employeeId: employee,
          year: year!,
          month: month!,
          action: 'reject',
          notes: selection['notes']?.toString(),
          claimIds: rejectAll ? null : claimIds,
          rejectAll: rejectAll,
        );
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${asInt(response['updated'])} claim(s) rejected for the month.',
              ),
            ),
          );
        }
      } catch (error) {
        if (mounted) _showError(error.toString());
      } finally {
        if (mounted) setState(() => _mutatingMonth = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadingReviewClaims = false);
        await _showReviewNotice(
          'Could not load claims',
          error.toString().replaceFirst('Exception: ', ''),
        );
        _showError(
          'Could not load the selected month’s claims: ${error.toString()}',
        );
      }
    }
  }

  Future<void> _showReviewNotice(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .45,
          ),
          child: SingleChildScrollView(child: Text(message)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _monthAction(Map<String, dynamic> row, String action) async {
    final employee = _numericEmployeeId(row);
    if (employee == null) {
      _showError(
        'The employee for this expense summary could not be identified.',
      );
      return;
    }
    var year = _year;
    var month = _month;
    if (year == null || month == null) {
      final period = await _chooseReviewPeriod(action);
      if (period == null || !mounted) return;
      year = period['year'];
      month = period['month'];
    }
    String? notes;
    if (action != 'approve') {
      notes = await _reviewNotes(
        action == 'reject'
            ? 'Reject monthly expenses'
            : 'Revert monthly review',
      );
      if (notes == null) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == 'approve'
              ? 'Approve this month?'
              : action == 'reject'
              ? 'Reject this month?'
              : 'Revert this month?',
        ),
        content: Text(
          action == 'approve'
              ? 'All submitted claims for this employee and month will be approved.'
              : 'The selected employee month will be updated with the recorded remarks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutatingMonth = true);
    try {
      final response = await _repository.reviewExpenseMonth(
        employeeId: employee,
        year: year!,
        month: month!,
        action: action,
        notes: notes,
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${asInt(response['updated'])} claim(s) updated for the month.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _mutatingMonth = false);
    }
  }

  Future<String?> _reviewNotes(String title) => showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Remarks (required)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );

  Widget _statusChip(String label, int count, ColorScheme colors) {
    final tint = switch (label) {
      'Approved' => const Color(0xff55d99b),
      'Rejected' => const Color(0xffff6b82),
      'Submitted' => const Color(0xffffc166),
      _ => colors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: tint.withValues(alpha: .3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: tint,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _amountChip(String label, Object? amount) => Container(
    constraints: const BoxConstraints(minWidth: 135),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xff0c132a),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: VistoraColors.muted,
            fontSize: 8,
            letterSpacing: .6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money(amount),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _pager(int page, int last, int total, ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$total employee totals - Page $page of $last',
            style: const TextStyle(color: VistoraColors.muted, fontSize: 11),
          ),
        ),
        IconButton.filledTonal(
          onPressed: page > 1
              ? () {
                  setState(() => _page--);
                  _refresh();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 5),
        IconButton.filledTonal(
          onPressed: page < last
              ? () {
                  setState(() => _page++);
                  _refresh();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _emptyState(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 42, color: VistoraColors.muted),
        SizedBox(height: 10),
        Text(
          'No expense totals for this period',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'Try changing the date range or clearing a filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: VistoraColors.muted),
        ),
      ],
    ),
  );

  Widget _loadError(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: colors.errorContainer.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(Icons.cloud_off_outlined, color: colors.error),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Could not load the report.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
  );

  String _money(Object? value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(asDouble(value));
  String _shortDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    return parsed == null ? '—' : DateFormat('dd MMM yy').format(parsed);
  }

  String _title(String value) => value.isEmpty
      ? 'All statuses'
      : value[0].toUpperCase() + value.substring(1);
}
