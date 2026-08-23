import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/mr/data/mr_repository.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_providers.dart';

class MrExpenseClaimsView extends ConsumerStatefulWidget {
  const MrExpenseClaimsView({
    super.key,
    this.mine = false,
    this.reviewable = false,
  });

  final bool mine;
  final bool reviewable;

  @override
  ConsumerState<MrExpenseClaimsView> createState() =>
      _MrExpenseClaimsViewState();
}

class _MrExpenseClaimsViewState extends ConsumerState<MrExpenseClaimsView> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _status;
  DateTime? _date;
  int? _month;
  int? _year = DateTime.now().year;
  int _page = 1;
  int _perPage = 10;
  bool _mutating = false;
  late Future<MrPage<MrExpenseClaim>> _future;

  MrRepository get _repository => ref.read(mrRepositoryProvider);

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

  Future<MrPage<MrExpenseClaim>> _load() => _repository.expenseClaims(
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    status: _status,
    date: _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
    month: _month,
    year: _year,
    mine: widget.mine,
    reviewable: widget.reviewable,
    page: _page,
    perPage: _perPage,
  );

  Future<void> _refresh({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _refresh(resetPage: true);
    });
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    String message = 'Field expense updated.',
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _edit([MrExpenseClaim? claim]) async {
    final result = await showModalBottomSheet<_ExpenseEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF10162A),
      builder: (_) => _ExpenseEditorSheet(claim: claim),
    );
    if (result == null || !mounted) return;
    await _mutate(
      () async {
        final id = await _repository.saveExpenseClaim(
          id: claim?.id,
          data: result.data,
        );
        if (result.submitAfterSave) await _repository.submitExpenseClaim(id);
      },
      message: result.submitAfterSave
          ? 'Claim submitted for approval.'
          : 'Draft saved.',
    );
  }

  Future<String?> _notes(String title, {bool required = true}) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: required ? 'Notes *' : 'Notes (optional)',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) {
                  setDialogState(() => error = 'Please enter a reason.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
      await _refresh(resetPage: true);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        _ExpenseHero(reviewable: widget.reviewable),
        const SizedBox(height: 14),
        _filters(),
        if (widget.mine) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _mutating ? null : _edit,
              icon: const Icon(Icons.add),
              label: const Text('New daily claim'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FutureBuilder<MrPage<MrExpenseClaim>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _ExpenseEmpty(
                icon: Icons.cloud_off_outlined,
                title: 'Expenses could not be loaded',
                message: snapshot.error.toString(),
                action: () => _refresh(),
              );
            }
            final page = snapshot.data!;
            if (page.items.isEmpty) {
              return _ExpenseEmpty(
                icon: Icons.receipt_long_outlined,
                title: widget.reviewable
                    ? 'No claims need review'
                    : 'No field expenses yet',
                message: widget.reviewable
                    ? 'Submitted claims from eligible employees will appear here.'
                    : 'Create a dated claim after field travel to begin.',
                action: widget.mine ? _edit : null,
              );
            }
            return Column(
              children: [
                for (var index = 0; index < page.items.length; index++)
                  TweenAnimationBuilder<double>(
                    duration: Duration(
                      milliseconds: 260 + (index.clamp(0, 6) * 55),
                    ),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, 14 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _claimCard(page.items[index]),
                    ),
                  ),
                _pagination(page),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _filters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: _searchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.reviewable
                  ? 'Search employee name, ID or travel'
                  : 'Search area, route or travel mode',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        _refresh(resetPage: true);
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All statuses'),
                        ),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'submitted',
                          child: Text('Submitted'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                      ],
                      onChanged: (value) {
                        _status = value;
                        _refresh(resetPage: true);
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All months'),
                        ),
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: month,
                            child: Text(
                              DateFormat.MMMM().format(DateTime(2026, month)),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        _month = value;
                        _refresh(resetPage: true);
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All years'),
                        ),
                        for (
                          var value = DateTime.now().year;
                          value >= DateTime.now().year - 5;
                          value--
                        )
                          DropdownMenuItem(value: value, child: Text('$value')),
                      ],
                      onChanged: (value) {
                        _year = value;
                        _refresh(resetPage: true);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _date == null
                        ? 'Any date'
                        : DateFormat('dd MMM yyyy').format(_date!),
                  ),
                ),
              ),
              if (_date != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear date',
                  onPressed: () {
                    setState(() => _date = null);
                    _refresh(resetPage: true);
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  Widget _claimCard(MrExpenseClaim claim) {
    final color = _statusColor(claim.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(claim),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: VistoraColors.orange.withValues(
                      alpha: .16,
                    ),
                    child: const Icon(
                      Icons.route_outlined,
                      color: VistoraColors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.reviewable
                              ? '${claim.employeeName ?? 'Employee'} (${claim.employeeCode ?? '—'})'
                              : DateFormat(
                                  'EEEE, dd MMM yyyy',
                                ).format(claim.expenseDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.reviewable
                              ? DateFormat(
                                  'EEEE, dd MMM yyyy',
                                ).format(claim.expenseDate)
                              : '${claim.travelFrom} → ${claim.travelTo}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: claim.status, color: color),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.areaCovered,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${claim.dutyLabel} • ${claim.modeOfTravel} • ${_distance(claim.distanceKm)}',
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(claim.totalExpense),
                    style: const TextStyle(
                      color: VistoraColors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                    ),
                  ),
                ],
              ),
              if (claim.includedInPayroll) ...[
                const SizedBox(height: 10),
                const _InfoStrip(
                  icon: Icons.lock_clock_outlined,
                  text:
                      'Included in payroll — approval is locked until payroll reversal.',
                ),
              ],
              if (_actionsFor(claim).isNotEmpty) ...[
                const Divider(height: 24),
                Wrap(spacing: 7, runSpacing: 7, children: _actionsFor(claim)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actionsFor(MrExpenseClaim claim) => [
    if (claim.canEdit)
      TextButton.icon(
        onPressed: _mutating ? null : () => _edit(claim),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
    if (claim.canSubmit)
      FilledButton.tonalIcon(
        onPressed: _mutating
            ? null
            : () => _mutate(
                () => _repository.submitExpenseClaim(claim.id),
                message: 'Claim submitted for approval.',
              ),
        icon: const Icon(Icons.send_outlined),
        label: const Text('Submit'),
      ),
    if (claim.canRollback)
      TextButton.icon(
        onPressed: _mutating
            ? null
            : () async {
                final notes = await _notes('Roll back this submission');
                if (notes != null && mounted) {
                  await _mutate(
                    () => _repository.rollbackExpenseClaim(claim.id, notes),
                    message: 'Submission returned to draft.',
                  );
                }
              },
        icon: const Icon(Icons.undo),
        label: const Text('Recall'),
      ),
    if (claim.canReview)
      FilledButton.icon(
        onPressed: _mutating
            ? null
            : () async {
                final notes = await _notes(
                  'Approve field expense',
                  required: false,
                );
                if (notes != null && mounted) {
                  await _mutate(
                    () =>
                        _repository.approveExpenseClaim(claim.id, notes: notes),
                    message: 'Field expense approved.',
                  );
                }
              },
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Approve'),
      ),
    if (claim.canReview)
      OutlinedButton.icon(
        onPressed: _mutating
            ? null
            : () async {
                final notes = await _notes('Reject field expense');
                if (notes != null && mounted) {
                  await _mutate(
                    () => _repository.rejectExpenseClaim(claim.id, notes),
                    message: 'Field expense rejected.',
                  );
                }
              },
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Reject'),
      ),
    if (claim.canRevertReview)
      TextButton.icon(
        onPressed: _mutating
            ? null
            : () async {
                final notes = await _notes('Revert review decision');
                if (notes != null && mounted) {
                  await _mutate(
                    () => _repository.revertExpenseReview(claim.id, notes),
                    message: 'Review reverted to submitted.',
                  );
                }
              },
        icon: const Icon(Icons.settings_backup_restore),
        label: const Text('Revert decision'),
      ),
    if (claim.canDelete)
      TextButton.icon(
        onPressed: _mutating
            ? null
            : () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete draft?'),
                    content: const Text(
                      'This never-submitted draft will be removed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (yes == true && mounted) {
                  await _mutate(
                    () => _repository.deleteExpenseClaim(claim.id),
                    message: 'Draft deleted.',
                  );
                }
              },
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete'),
      ),
  ];

  Widget _pagination(MrPage<MrExpenseClaim> result) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${result.total} claim${result.total == 1 ? '' : 's'} • Page ${result.currentPage} of ${result.lastPage}',
          ),
        ),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page > 1
              ? () {
                  _page--;
                  _refresh();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: result.hasMore
              ? () {
                  _page++;
                  _refresh();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        PopupMenuButton<int>(
          tooltip: 'Items per page',
          initialValue: _perPage,
          onSelected: (value) {
            _perPage = value;
            _refresh(resetPage: true);
          },
          itemBuilder: (_) => [
            for (final value in const [10, 20, 50])
              PopupMenuItem(value: value, child: Text('$value per page')),
          ],
          icon: const Icon(Icons.view_list_outlined),
        ),
      ],
    ),
  );

  Future<void> _showDetails(MrExpenseClaim claim) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF10162A),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      minChildSize: .45,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Field expense details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(
                status: claim.status,
                color: _statusColor(claim.status),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (claim.employeeName != null)
            _Detail(
              'Employee',
              '${claim.employeeName} (${claim.employeeCode ?? '—'})',
            ),
          if (claim.designation != null)
            _Detail('Designation', claim.designation!),
          if (claim.headquarters != null)
            _Detail('Headquarters', claim.headquarters!),
          _Detail(
            'Expense date',
            DateFormat('EEEE, dd MMMM yyyy').format(claim.expenseDate),
          ),
          _Detail('Duty category', claim.dutyLabel),
          _Detail('Area covered', claim.areaCovered),
          _Detail('Travel route', '${claim.travelFrom} → ${claim.travelTo}'),
          _Detail(
            'Mode / distance',
            '${claim.modeOfTravel} • ${_distance(claim.distanceKm)}',
          ),
          const Divider(height: 30),
          _AmountRow(
            'HQ / EX HQ / Outstation allowance',
            claim.allowanceAmount,
          ),
          _AmountRow('Working allowance', claim.workingAllowanceAmount),
          _AmountRow('Total allowance', claim.totalAllowance, strong: true),
          _AmountRow('Travel fare', claim.fareAmount),
          _AmountRow('Courier charges', claim.courierCharges),
          _AmountRow('Other doctor expenses', claim.otherDoctorExpenses),
          const Divider(height: 24),
          _AmountRow(
            'Total claim',
            claim.totalExpense,
            strong: true,
            accent: true,
          ),
          if (claim.remarks?.isNotEmpty == true)
            _Detail('Remarks', claim.remarks!),
          if (claim.reviewNotes?.isNotEmpty == true)
            _Detail('Review notes', claim.reviewNotes!),
          if (claim.rollbackNotes?.isNotEmpty == true)
            _Detail('Rollback notes', claim.rollbackNotes!),
          if (claim.reviewerName?.isNotEmpty == true)
            _Detail('Reviewed by', claim.reviewerName!),
          if (claim.includedInPayroll)
            const _InfoStrip(
              icon: Icons.payments_outlined,
              text: 'This approved claim is included in payroll.',
            ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class _ExpenseEditorResult {
  const _ExpenseEditorResult(this.data, this.submitAfterSave);
  final Map<String, dynamic> data;
  final bool submitAfterSave;
}

class _ExpenseEditorSheet extends StatefulWidget {
  const _ExpenseEditorSheet({this.claim});
  final MrExpenseClaim? claim;

  @override
  State<_ExpenseEditorSheet> createState() => _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends State<_ExpenseEditorSheet> {
  final _form = GlobalKey<FormState>();
  late DateTime _date;
  late String _dutyType;
  late final TextEditingController _area;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _allowance;
  late final TextEditingController _working;
  late final TextEditingController _mode;
  late final TextEditingController _distance;
  late final TextEditingController _fare;
  late final TextEditingController _courier;
  late final TextEditingController _other;
  late final TextEditingController _remarks;

  List<TextEditingController> get _amountControllers => [
    _allowance,
    _working,
    _fare,
    _courier,
    _other,
  ];

  @override
  void initState() {
    super.initState();
    final claim = widget.claim;
    _date = claim?.expenseDate ?? DateTime.now();
    _dutyType = claim?.dutyType ?? 'hq';
    _area = TextEditingController(text: claim?.areaCovered);
    _from = TextEditingController(text: claim?.travelFrom);
    _to = TextEditingController(text: claim?.travelTo);
    _allowance = _number(claim?.allowanceAmount);
    _working = _number(claim?.workingAllowanceAmount);
    _mode = TextEditingController(text: claim?.modeOfTravel);
    _distance = _number(claim?.distanceKm);
    _fare = _number(claim?.fareAmount);
    _courier = _number(claim?.courierCharges);
    _other = _number(claim?.otherDoctorExpenses);
    _remarks = TextEditingController(text: claim?.remarks);
    for (final controller in _amountControllers) {
      controller.addListener(_recalculate);
    }
  }

  TextEditingController _number(double? value) => TextEditingController(
    text: value == null || value == 0 ? '' : value.toStringAsFixed(2),
  );

  void _recalculate() {
    if (mounted) setState(() {});
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;
  double get _allowanceTotal => _value(_allowance) + _value(_working);
  double get _grandTotal =>
      _allowanceTotal + _value(_fare) + _value(_courier) + _value(_other);

  @override
  void dispose() {
    for (final controller in [
      _area,
      _from,
      _to,
      _allowance,
      _working,
      _mode,
      _distance,
      _fare,
      _courier,
      _other,
      _remarks,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _finish(bool submit) {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ExpenseEditorResult({
        'expense_date': DateFormat('yyyy-MM-dd').format(_date),
        'duty_type': _dutyType,
        'area_covered': _area.text.trim(),
        'travel_from': _from.text.trim(),
        'travel_to': _to.text.trim(),
        'allowance_amount': _value(_allowance),
        'working_allowance_amount': _value(_working),
        'mode_of_travel': _mode.text.trim(),
        'distance_km': _value(_distance),
        'fare_amount': _value(_fare),
        'courier_charges': _value(_courier),
        'other_doctor_expenses': _value(_other),
        'remarks': _remarks.text.trim(),
      }, submit),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .55,
      maxChildSize: .98,
      builder: (context, controller) => Form(
        key: _form,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Text(
              widget.claim == null
                  ? 'New daily field expense'
                  : 'Edit field expense',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Employee details, designation and headquarters are filled securely from your profile.',
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(DateFormat('EEEE, dd MMMM yyyy').format(_date)),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'hq', label: Text('HQ')),
                ButtonSegment(value: 'ex_hq', label: Text('EX HQ')),
                ButtonSegment(value: 'outstation', label: Text('Outstation')),
              ],
              selected: {_dutyType},
              onSelectionChanged: (value) =>
                  setState(() => _dutyType = value.first),
            ),
            const SizedBox(height: 14),
            _required(_area, 'Area covered', Icons.map_outlined),
            _required(_from, 'Travel from', Icons.trip_origin),
            _required(_to, 'Travel to', Icons.location_on_outlined),
            _required(
              _mode,
              'Mode of travel',
              Icons.directions_transit_outlined,
            ),
            _numeric(_distance, 'Distance (km)', Icons.straighten),
            const SizedBox(height: 8),
            Text(
              'Allowances',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            _numeric(
              _allowance,
              '${_dutyType == 'hq'
                  ? 'HQ'
                  : _dutyType == 'ex_hq'
                  ? 'EX HQ'
                  : 'Outstation'} allowance',
              Icons.wallet_outlined,
            ),
            _numeric(_working, 'Working allowance', Icons.work_outline),
            _numeric(_fare, 'Travel fare', Icons.local_taxi_outlined),
            _numeric(
              _courier,
              'Courier charges',
              Icons.local_shipping_outlined,
            ),
            _numeric(
              _other,
              'Other doctor expenses',
              Icons.medical_information_outlined,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarks,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x3327D99A), Color(0x3329C5F6)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: VistoraColors.green.withValues(alpha: .45),
                ),
              ),
              child: Column(
                children: [
                  _AmountRow('Total allowance', _allowanceTotal),
                  _AmountRow(
                    'Total expense claim',
                    _grandTotal,
                    strong: true,
                    accent: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _finish(false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save draft'),
                ),
                FilledButton.icon(
                  onPressed: _grandTotal <= 0 ? null : () => _finish(true),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Save & submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _required(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label *',
        prefixIcon: Icon(icon),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label is required.' : null,
    ),
  );

  Widget _numeric(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final parsed = double.tryParse(value.trim());
        return parsed == null || parsed < 0
            ? 'Enter a valid non-negative amount.'
            : null;
      },
    ),
  );
}

class _ExpenseHero extends StatelessWidget {
  const _ExpenseHero({required this.reviewable});
  final bool reviewable;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF44231D), Color(0xFF0B2940)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: VistoraColors.orange.withValues(alpha: .28)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 25,
          backgroundColor: Color(0x33FF6B00),
          child: Icon(Icons.receipt_long_outlined, color: VistoraColors.orange),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reviewable ? 'Field expense approvals' : 'My field expenses',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                reviewable
                    ? 'Review eligible team travel claims with a complete audit trail.'
                    : 'Log one clear, dated travel claim after each field day.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExpenseEmpty extends StatelessWidget {
  const _ExpenseEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(icon, size: 46, color: VistoraColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: action,
              child: const Text('Continue'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: .65)),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
    ),
  );
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: VistoraColors.cyan.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: VistoraColors.cyan, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(
              color: VistoraColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(
    this.label,
    this.amount, {
    this.strong = false,
    this.accent = false,
  });
  final String label;
  final double amount;
  final bool strong;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _money(amount),
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            fontSize: strong ? 17 : null,
            color: accent ? VistoraColors.green : null,
          ),
        ),
      ],
    ),
  );
}

Color _statusColor(String status) => switch (status) {
  'approved' => VistoraColors.green,
  'submitted' => VistoraColors.orange,
  'rejected' => const Color(0xFFFF6B7A),
  _ => VistoraColors.cyan,
};

String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
String _distance(double value) => value <= 0
    ? 'distance not entered'
    : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} km';
