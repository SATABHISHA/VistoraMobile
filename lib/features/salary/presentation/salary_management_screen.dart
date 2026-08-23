import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/salary/data/salary_repository.dart';
import 'package:vistora_mobile/features/salary/domain/salary_models.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>(
  (ref) => SalaryRepository(ref.watch(apiClientProvider)),
);

class SalaryManagementScreen extends ConsumerStatefulWidget {
  const SalaryManagementScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<SalaryManagementScreen> createState() =>
      _SalaryManagementScreenState();
}

class _SalaryManagementScreenState
    extends ConsumerState<SalaryManagementScreen> {
  late final TextEditingController _search;
  Timer? _debounce;
  int _year = DateTime.now().year;
  int _page = 1;
  late Future<SalaryRosterPage> _future;

  SalaryRepository get repository => ref.read(salaryRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<SalaryRosterPage> _load() => repository.roster(
    year: _year,
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    page: _page,
  );

  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _showEmployee(SalaryRosterEmployee employee) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _SalaryDetailSheet(
        employee: employee,
        year: _year,
        repository: repository,
        onChanged: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var offset = -4; offset <= 1; offset++) DateTime.now().year + offset,
    ]..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Structures')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<SalaryRosterPage>(
          future: _future,
          builder: (context, snapshot) {
            final result = snapshot.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                _SalaryHero(total: result?.total, year: _year),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 560;
                    final search = TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search employee name, ID or email',
                      ),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 300),
                          () => mounted ? _refresh(reset: true) : null,
                        );
                      },
                    );
                    final year = DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: years
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null || value == _year) return;
                        _year = value;
                        _refresh(reset: true);
                      },
                    );
                    if (stacked) {
                      return Column(
                        children: [search, const SizedBox(height: 12), year],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 3, child: search),
                        const SizedBox(width: 12),
                        Expanded(child: year),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(44),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  _SalaryError(error: snapshot.error, retry: _refresh)
                else if (result == null || result.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_outlined, size: 42),
                          SizedBox(height: 10),
                          Text('No active employees match this search.'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...result.items.asMap().entries.map(
                    (entry) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 230 + entry.key * 35),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: _SalaryEmployeeCard(
                        employee: entry.value,
                        year: _year,
                        open: () => _showEmployee(entry.value),
                      ),
                    ),
                  ),
                  _PageControls(
                    page: result.page,
                    lastPage: result.lastPage,
                    previous: result.page > 1
                        ? () {
                            _page--;
                            _refresh();
                          }
                        : null,
                    next: result.hasMore
                        ? () {
                            _page++;
                            _refresh();
                          }
                        : null,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SalaryDetailSheet extends StatefulWidget {
  const _SalaryDetailSheet({
    required this.employee,
    required this.year,
    required this.repository,
    required this.onChanged,
  });

  final SalaryRosterEmployee employee;
  final int year;
  final SalaryRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_SalaryDetailSheet> createState() => _SalaryDetailSheetState();
}

class _SalaryDetailSheetState extends State<_SalaryDetailSheet> {
  late Future<SalaryEmployeeDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.detail(widget.employee.employeeId);
  }

  Future<void> _reload() async {
    setState(
      () => _future = widget.repository.detail(widget.employee.employeeId),
    );
    await Future.wait([_future, widget.onChanged()]);
  }

  Future<void> _revise() async {
    final input = await showModalBottomSheet<_RevisionInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RevisionEditor(year: widget.year),
    );
    if (input == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.revise(
        employeeId: widget.employee.employeeId,
        year: widget.year,
        revisionDate: input.revisionDate,
        incrementAmount: input.increment,
        arrearEffectiveDate: input.arrearEffectiveDate,
      );
      await _reload();
      if (mounted) {
        _message('Salary revision applied and draft payroll refreshed.');
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rollback(SalaryRevisionRecord revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.history),
        title: const Text('Rollback salary revision?'),
        content: const Text(
          'The latest applied increment and its pending arrears will be reversed. Released payroll is never altered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.rollback(
        employeeId: widget.employee.employeeId,
        revisionId: revision.id,
      );
      await _reload();
      if (mounted) _message('Latest salary revision rolled back.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF5A182B) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .92,
    minChildSize: .55,
    maxChildSize: .98,
    builder: (context, controller) => FutureBuilder<SalaryEmployeeDetail>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final structure = detail?.forYear(widget.year);
        final revisions =
            detail?.revisions
                .where((item) => item.year == widget.year)
                .toList() ??
            const <SalaryRevisionRecord>[];
        SalaryRevisionRecord? latestApplied;
        for (final revision in revisions) {
          if (revision.actionStatus == 'applied') {
            latestApplied = revision;
            break;
          }
        }
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: VistoraColors.orange.withValues(alpha: .15),
                  child: Text(
                    _initials(widget.employee.name),
                    style: const TextStyle(
                      color: VistoraColors.orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${widget.employee.code} · ${widget.year} salary'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(45),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot.hasError)
              _SalaryError(
                error: snapshot.error,
                retry: () => setState(
                  () => _future = widget.repository.detail(
                    widget.employee.employeeId,
                  ),
                ),
              )
            else if (structure == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No salary structure for ${widget.year}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create the component-based structure in the Salary Designer. Mobile intentionally does not invent pay-component formulas.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _StructureCard(structure: structure),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _revise,
                icon: const Icon(Icons.trending_up),
                label: const Text('Apply salary revision'),
              ),
              const SizedBox(height: 24),
              Text(
                'Revision history',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (revisions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No revisions recorded for this year.'),
                  ),
                )
              else
                ...revisions.map(
                  (revision) => _RevisionCard(
                    revision: revision,
                    canRollback:
                        latestApplied?.id == revision.id &&
                        revision.canRollback,
                    busy: _busy,
                    rollback: () => _rollback(revision),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _RevisionEditor extends StatefulWidget {
  const _RevisionEditor({required this.year});
  final int year;

  @override
  State<_RevisionEditor> createState() => _RevisionEditorState();
}

class _RevisionEditorState extends State<_RevisionEditor> {
  final _form = GlobalKey<FormState>();
  final _increment = TextEditingController();
  DateTime _revisionDate = DateTime.now();
  DateTime? _arrearEffectiveDate;

  @override
  void dispose() {
    _increment.dispose();
    super.dispose();
  }

  Future<void> _pickRevision() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _revisionDate,
      firstDate: DateTime(widget.year),
      lastDate: DateTime(widget.year, 12, 31),
    );
    if (value != null) setState(() => _revisionDate = value);
  }

  Future<void> _pickEffective() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _arrearEffectiveDate ?? _revisionDate,
      firstDate: DateTime(widget.year),
      lastDate: _revisionDate,
    );
    if (value != null) setState(() => _arrearEffectiveDate = value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Apply salary revision',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Laravel scales the existing structure proportionally and calculates eligible arrears.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _increment,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Annual increment amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter an amount greater than zero.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickRevision,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                'Revision date · ${DateFormat.yMMMd().format(_revisionDate)}',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickEffective,
              icon: const Icon(Icons.history),
              label: Text(
                _arrearEffectiveDate == null
                    ? 'Set arrear effective date (optional)'
                    : 'Arrears from · ${DateFormat.yMMMd().format(_arrearEffectiveDate!)}',
              ),
            ),
            if (_arrearEffectiveDate != null)
              TextButton(
                onPressed: () => setState(() => _arrearEffectiveDate = null),
                child: const Text('Remove arrear date'),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _RevisionInput(
                    increment: double.parse(_increment.text.trim()),
                    revisionDate: _revisionDate,
                    arrearEffectiveDate: _arrearEffectiveDate,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Apply revision'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RevisionInput {
  const _RevisionInput({
    required this.increment,
    required this.revisionDate,
    this.arrearEffectiveDate,
  });
  final double increment;
  final DateTime revisionDate;
  final DateTime? arrearEffectiveDate;
}

class _SalaryHero extends StatelessWidget {
  const _SalaryHero({required this.total, required this.year});
  final int? total;
  final int year;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      gradient: const LinearGradient(
        colors: [Color(0xFF3B201D), Color(0xFF082C43)],
      ),
      border: Border.all(color: VistoraColors.orange.withValues(alpha: .26)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0x33FF6B00),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: VistoraColors.orange,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Salary control centre',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              Text(
                '${total ?? '—'} active employees · $year structures and revisions',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SalaryEmployeeCard extends StatelessWidget {
  const _SalaryEmployeeCard({
    required this.employee,
    required this.year,
    required this.open,
  });
  final SalaryRosterEmployee employee;
  final int year;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) {
    final salary = employee.salary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: VistoraColors.cyan.withValues(alpha: .12),
                    child: Text(
                      _initials(employee.name),
                      style: const TextStyle(
                        color: VistoraColors.cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          employee.code,
                          style: const TextStyle(color: VistoraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    salary == null
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: salary == null
                        ? VistoraColors.amber
                        : VistoraColors.green,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (salary == null)
                Text(
                  'No $year salary structure',
                  style: const TextStyle(
                    color: VistoraColors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else ...[
                Text(
                  salary.payGroupName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MoneyChip(
                      'Annual CTC',
                      salary.ctcAnnual,
                      VistoraColors.orange,
                    ),
                    _MoneyChip(
                      'Net / month',
                      salary.netMonthly,
                      VistoraColors.green,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: open,
                  icon: const Icon(Icons.history),
                  label: const Text('Structure & revisions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructureCard extends StatelessWidget {
  const _StructureCard({required this.structure});
  final SalaryStructureRecord structure;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFF12243A), Color(0xFF17142C)],
      ),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          structure.payGroupName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _SalaryLine('Annual CTC', structure.ctcAnnual, VistoraColors.orange),
        _SalaryLine(
          'Gross monthly',
          structure.grossMonthly,
          VistoraColors.cyan,
        ),
        _SalaryLine(
          'Deductions',
          structure.deductionMonthly,
          VistoraColors.pink,
        ),
        _SalaryLine(
          'Net monthly',
          structure.netMonthly,
          VistoraColors.green,
          strong: true,
        ),
      ],
    ),
  );
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.revision,
    required this.canRollback,
    required this.busy,
    required this.rollback,
  });
  final SalaryRevisionRecord revision;
  final bool canRollback;
  final bool busy;
  final VoidCallback rollback;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMd().format(revision.revisionDate),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(revision.actionStatus),
            ],
          ),
          const SizedBox(height: 9),
          _SalaryLine(
            'Annual increment',
            revision.incrementAmount,
            VistoraColors.orange,
          ),
          _SalaryLine(
            'Old net / month',
            revision.oldNetMonthly,
            VistoraColors.muted,
          ),
          _SalaryLine(
            'New net / month',
            revision.newNetMonthly,
            VistoraColors.green,
          ),
          if (revision.arrearsDue > 0)
            _SalaryLine(
              'Arrears due · ${revision.arrearsStatus}',
              revision.arrearsDue,
              VistoraColors.amber,
            ),
          if (canRollback)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : rollback,
                icon: const Icon(Icons.undo),
                label: const Text('Rollback latest revision'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SalaryLine extends StatelessWidget {
  const _SalaryLine(this.label, this.amount, this.color, {this.strong = false});
  final String label;
  final double amount;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          _money(amount),
          style: TextStyle(
            color: color,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            fontSize: strong ? 17 : null,
          ),
        ),
      ],
    ),
  );
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label ${_money(amount)}',
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'applied'
        ? VistoraColors.green
        : VistoraColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.lastPage,
    this.previous,
    this.next,
  });
  final int page;
  final int lastPage;
  final VoidCallback? previous;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Page $page of $lastPage',
          style: const TextStyle(color: VistoraColors.muted),
        ),
      ),
      IconButton.filledTonal(
        onPressed: previous,
        icon: const Icon(Icons.chevron_left),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        onPressed: next,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _SalaryError extends StatelessWidget {
  const _SalaryError({required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 38, color: VistoraColors.pink),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
