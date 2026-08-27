import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/payroll/data/payroll_repository.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';
import 'package:vistora_mobile/features/payslips/domain/payslip.dart';
import 'package:vistora_mobile/features/payslips/presentation/payslips_screen.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>(
  (ref) => PayrollRepository(ref.watch(apiClientProvider)),
);

class PayrollAdminScreen extends ConsumerStatefulWidget {
  const PayrollAdminScreen({super.key});

  @override
  ConsumerState<PayrollAdminScreen> createState() => _PayrollAdminScreenState();
}

class _PayrollAdminScreenState extends ConsumerState<PayrollAdminScreen> {
  int year = DateTime.now().year;
  int month = DateTime.now().month;
  bool mutating = false;
  final search = TextEditingController();
  String query = '';
  late Future<PayrollCollection> result;

  @override
  void initState() {
    super.initState();
    result = _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  PayrollRepository get repository => ref.read(payrollRepositoryProvider);
  Future<PayrollCollection> _load() =>
      repository.cycles(year: year, month: month);

  Future<void> refresh() async {
    setState(() => result = _load());
    await result;
  }

  Future<void> mutate(Future<void> Function() action) async {
    if (mutating) return;
    setState(() => mutating = true);
    try {
      await action();
      await refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll updated successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payroll Administration')),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder<PayrollCollection>(
        future: result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
              ],
            );
          }
          final collection = snapshot.data!;
          final cycle = collection.cycles.firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.companyName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/salary-structures'),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Salary designer'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(
                            DateFormat.MMMM().format(DateTime(2026, index + 1)),
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        month = value ?? month;
                        refresh();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: List.generate(
                        5,
                        (index) => DropdownMenuItem(
                          value: DateTime.now().year - 2 + index,
                          child: Text('${DateTime.now().year - 2 + index}'),
                        ),
                      ),
                      onChanged: (value) {
                        year = value ?? year;
                        refresh();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (cycle == null)
                FilledButton.icon(
                  onPressed: mutating
                      ? null
                      : () => mutate(
                          () => repository.initiate(year: year, month: month),
                        ),
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Initiate Salary'),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormat.MMMM().format(DateTime(cycle.year, cycle.month))} ${cycle.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Chip(label: Text(cycle.status.toUpperCase())),
                          ],
                        ),
                        Text(
                          '${cycle.employees.length} employees • ${_money(cycle.totalPayroll)} total payroll',
                        ),
                        if (collection.mrEnabled)
                          Text(
                            'Approved field expenses included: ${_money(cycle.mrExpenseTotal)}',
                            style: const TextStyle(color: VistoraColors.green),
                          ),
                        const SizedBox(height: 12),
                        if (cycle.status != 'released')
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: mutating
                                    ? null
                                    : () => mutate(
                                        () => repository.calculateDeductions(
                                          cycle.id,
                                        ),
                                      ),
                                icon: const Icon(Icons.calculate_outlined),
                                label: const Text('Calculate & Deduct'),
                              ),
                              OutlinedButton.icon(
                                onPressed: mutating
                                    ? null
                                    : () => _confirmRollbackDeductions(cycle),
                                icon: const Icon(Icons.undo),
                                label: const Text('Rollback Deductions'),
                              ),
                              if (collection.mrEnabled)
                                FilledButton.tonalIcon(
                                  onPressed: mutating
                                      ? null
                                      : () => _bulkMrExpense(
                                          cycle,
                                          include: true,
                                        ),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('Include Field Expenses'),
                                ),
                              if (collection.mrEnabled)
                                OutlinedButton.icon(
                                  onPressed: mutating
                                      ? null
                                      : () => _bulkMrExpense(
                                          cycle,
                                          include: false,
                                        ),
                                  icon: const Icon(Icons.undo),
                                  label: const Text('Revert Field Expenses'),
                                ),
                              OutlinedButton.icon(
                                onPressed: mutating || cycle.status == 'on_hold'
                                    ? null
                                    : () => _putSelectedOnHold(cycle),
                                icon: const Icon(Icons.pause_circle_outline),
                                label: const Text('Put On Hold'),
                              ),
                              FilledButton.icon(
                                onPressed: mutating
                                    ? null
                                    : () => _confirmRelease(cycle),
                                icon: const Icon(Icons.verified_outlined),
                                label: const Text('Release Payroll'),
                              ),
                            ],
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: mutating
                                ? null
                                : () => _confirmCycleRollback(cycle),
                            icon: const Icon(Icons.settings_backup_restore),
                            label: const Text('Rollback Released Cycle'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  onChanged: (value) => setState(() {
                    query = value.trim().toLowerCase();
                  }),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search name, employee code, email or mobile',
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(() {
                              search.clear();
                              query = '';
                            }),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                ...cycle.employees
                    .where(_matches)
                    .map(
                      (item) => _EmployeePayrollCard(
                        item: item,
                        enabled: !mutating && cycle.status != 'released',
                        released: cycle.status == 'released',
                        view: () => _showEmployee(cycle, item, collection),
                        rollbackEmployee: () => mutate(
                          () => repository.rollbackEmployee(
                            cycleId: cycle.id,
                            payrollItemId: item.id,
                          ),
                        ),
                        viewSlip: () =>
                            _showPayslip(cycle, item, collection.companyName),
                        calculate: () => mutate(
                          () => repository.calculateDeductions(
                            cycle.id,
                            employeeIds: [item.employeeId],
                          ),
                        ),
                        rollback: () => mutate(
                          () => repository.rollbackDeductions(
                            cycle.id,
                            employeeIds: [item.employeeId],
                          ),
                        ),
                        addArrears: () => _addArrears(cycle, item),
                        mrEnabled: collection.mrEnabled,
                        includeMrExpense: () => mutate(
                          () => repository.calculateMrExpenses(
                            cycle.id,
                            employeeIds: [item.employeeId],
                          ),
                        ),
                        rollbackMrExpense: () => mutate(
                          () => repository.rollbackMrExpenses(
                            cycle.id,
                            employeeIds: [item.employeeId],
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    ),
  );

  bool _matches(PayrollEmployeeSummary item) {
    if (query.isEmpty) return true;
    return [
      item.employeeName,
      item.employeeCode,
      item.employeeEmail ?? '',
      item.employeeMobile ?? '',
    ].any((value) => value.toLowerCase().contains(query));
  }

  Future<void> _putSelectedOnHold(PayrollCycleSummary cycle) async {
    final ids = await _selectEmployees(cycle, 'Put selected payroll on hold');
    if (ids == null || ids.isEmpty || !mounted) return;
    await mutate(() => repository.putOnHold(cycle.id, employeeIds: ids));
  }

  Future<void> _showEmployee(
    PayrollCycleSummary cycle,
    PayrollEmployeeSummary item,
    PayrollCollection collection,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PayrollEmployeeSheet(
        repository: repository,
        cycle: cycle,
        employee: item,
        companyName: collection.companyName,
        editable: cycle.status != 'released',
        onChanged: refresh,
      ),
    );
  }

  void _showPayslip(
    PayrollCycleSummary cycle,
    PayrollEmployeeSummary employee,
    String companyName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PayslipSheet(
        item: Payslip.fromPayroll(cycle: cycle, employee: employee),
        companyName: companyName,
      ),
    );
  }

  Future<void> _confirmRollbackDeductions(PayrollCycleSummary cycle) async {
    final yes = await _confirm(
      'Rollback deductions?',
      'This removes attendance and leave deductions for the selected cycle. They can be calculated again.',
    );
    if (yes) await mutate(() => repository.rollbackDeductions(cycle.id));
  }

  Future<void> _bulkMrExpense(
    PayrollCycleSummary cycle, {
    required bool include,
  }) async {
    final ids = await _selectEmployees(
      cycle,
      include ? 'Include approved field expenses' : 'Revert field expenses',
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await mutate(
      () => include
          ? repository.calculateMrExpenses(cycle.id, employeeIds: ids)
          : repository.rollbackMrExpenses(cycle.id, employeeIds: ids),
    );
  }

  Future<List<int>?> _selectEmployees(
    PayrollCycleSummary cycle,
    String title,
  ) async {
    final selected = cycle.employees.map((item) => item.employeeId).toSet();
    final search = TextEditingController();
    var query = '';
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final visible = cycle.employees.where((item) {
            final needle = query.trim().toLowerCase();
            return needle.isEmpty ||
                item.employeeName.toLowerCase().contains(needle) ||
                item.employeeCode.toLowerCase().contains(needle);
          }).toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .78,
            minChildSize: .45,
            maxChildSize: .94,
            builder: (context, controller) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: search,
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search employee name or ID',
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setSheetState(
                              () => selected.addAll(
                                visible.map((item) => item.employeeId),
                              ),
                            ),
                            child: const Text('Select all shown'),
                          ),
                          TextButton(
                            onPressed: () => setSheetState(
                              () => selected.removeAll(
                                visible.map((item) => item.employeeId),
                              ),
                            ),
                            child: const Text('Clear shown'),
                          ),
                          const Spacer(),
                          Text('${selected.length} selected'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return CheckboxListTile(
                        value: selected.contains(item.employeeId),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            selected.add(item.employeeId);
                          } else {
                            selected.remove(item.employeeId);
                          }
                        }),
                        title: Text(
                          item.employeeName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${item.employeeCode} • Current field expense ${_money(item.mrExpense)}',
                        ),
                        secondary: CircleAvatar(
                          child: Text(
                            item.employeeName.characters.first.toUpperCase(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () => Navigator.pop(
                                  sheetContext,
                                  selected.toList(),
                                ),
                          child: const Text('Apply to selected'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    search.dispose();
    return result;
  }

  Future<void> _confirmCycleRollback(PayrollCycleSummary cycle) async {
    final yes = await _confirm(
      'Rollback released payroll?',
      'Released payslips will be withdrawn and the cycle returned to draft before recalculation.',
    );
    if (yes) await mutate(() => repository.rollbackCycle(cycle.id));
  }

  Future<void> _confirmRelease(PayrollCycleSummary cycle) async {
    final yes = await _confirm(
      'Release payroll?',
      'This releases employee payslips for the selected period after server approval checks.',
    );
    if (yes) await mutate(() => repository.release(cycle.id));
  }

  Future<void> _addArrears(
    PayrollCycleSummary cycle,
    PayrollEmployeeSummary item,
  ) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add arrears • ${item.employeeName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add arrears'),
          ),
        ],
      ),
    );
    final value = double.tryParse(amount.text);
    final note = reason.text;
    amount.dispose();
    reason.dispose();
    if (submitted == true && value != null && value > 0) {
      await mutate(
        () => repository.addArrears(
          cycleId: cycle.id,
          employeeId: item.employeeId,
          amount: value,
          reason: note,
        ),
      );
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}

class _PayrollEmployeeSheet extends StatefulWidget {
  const _PayrollEmployeeSheet({
    required this.repository,
    required this.cycle,
    required this.employee,
    required this.companyName,
    required this.editable,
    required this.onChanged,
  });

  final PayrollRepository repository;
  final PayrollCycleSummary cycle;
  final PayrollEmployeeSummary employee;
  final String companyName;
  final bool editable;
  final Future<void> Function() onChanged;

  @override
  State<_PayrollEmployeeSheet> createState() => _PayrollEmployeeSheetState();
}

class _PayrollEmployeeSheetState extends State<_PayrollEmployeeSheet> {
  final form = GlobalKey<FormState>();
  late final TextEditingController gross;
  late final TextEditingController base;
  late final TextEditingController statutory;
  late final TextEditingController attendance;
  late final TextEditingController arrears;
  late final List<_ComponentDraft> components;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final item = widget.employee;
    gross = _amountController(item.grossAmount);
    base = _amountController(item.baseAmount);
    statutory = _amountController(item.statutoryDeduction);
    attendance = _amountController(item.attendanceDeduction);
    arrears = _amountController(item.arrears);
    components = item.components.map(_ComponentDraft.fromComponent).toList();
  }

  static TextEditingController _amountController(double value) =>
      TextEditingController(text: value.toStringAsFixed(2));

  @override
  void dispose() {
    gross.dispose();
    base.dispose();
    statutory.dispose();
    attendance.dispose();
    arrears.dispose();
    for (final item in components) {
      item.dispose();
    }
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double get _net =>
      (_value(base) +
              _value(arrears) +
              widget.employee.mrExpense -
              _value(attendance))
          .clamp(0, double.infinity)
          .toDouble();

  void _addComponent() {
    setState(() {
      components.add(
        _ComponentDraft(
          name: TextEditingController(),
          amount: TextEditingController(text: '0.00'),
          type: 'Earning',
        ),
      );
    });
  }

  void _removeComponent(int index) {
    final removed = components.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.repository.updateEmployee(
        cycleId: widget.cycle.id,
        payrollItemId: widget.employee.id,
        baseAmount: _value(base),
        grossAmount: _value(gross),
        statutoryDeduction: _value(statutory),
        attendanceDeduction: _value(attendance),
        arrearsAmount: _value(arrears),
        components: components.map((item) => item.value).toList(),
      );
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _rollback() async {
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Return payroll to draft?'),
            content: Text(
              '${widget.employee.employeeName} will be returned to draft so the payroll can be reviewed again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Return to draft'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repository.rollbackEmployee(
        cycleId: widget.cycle.id,
        payrollItemId: widget.employee.id,
      );
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showSlip() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PayslipSheet(
        item: Payslip.fromPayroll(
          cycle: widget.cycle,
          employee: widget.employee,
        ),
        companyName: widget.companyName,
      ),
    );
  }

  void _toast(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .94,
    minChildSize: .65,
    builder: (context, controller) => Form(
      key: form,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: VistoraColors.orange.withValues(alpha: .15),
                child: Text(
                  widget.employee.employeeName
                      .split(RegExp(r'\s+'))
                      .where((part) => part.isNotEmpty)
                      .take(2)
                      .map((part) => part[0].toUpperCase())
                      .join(),
                  style: const TextStyle(
                    color: VistoraColors.orange,
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
                      widget.employee.employeeName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${widget.employee.employeeCode} • ${DateFormat.yMMMM().format(DateTime(widget.cycle.year, widget.cycle.month))}',
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
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B201D), Color(0xFF082C43)],
              ),
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _PayrollMetric(
                  'Gross',
                  _money(_value(gross)),
                  VistoraColors.cyan,
                ),
                _PayrollMetric(
                  'LOP deduction',
                  _money(_value(attendance)),
                  VistoraColors.pink,
                ),
                _PayrollMetric(
                  'Net payable',
                  _money(_net),
                  VistoraColors.green,
                ),
                _PayrollMetric(
                  'Status',
                  widget.employee.status.toUpperCase(),
                  VistoraColors.amber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Payroll values',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _numberField(gross, 'Gross monthly'),
          _numberField(statutory, 'Statutory deductions'),
          _numberField(base, 'Net salary before attendance'),
          _numberField(attendance, 'Attendance / LOP deduction'),
          _numberField(arrears, 'Arrears / adjustments'),
          if (widget.employee.mrExpense > 0)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Approved field expenses'),
              trailing: Text(
                _money(widget.employee.mrExpense),
                style: const TextStyle(
                  color: VistoraColors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Salary components',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              if (widget.editable)
                FilledButton.tonalIcon(
                  onPressed: _addComponent,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (components.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No component snapshot is attached to this payroll yet. Add the earning and deduction breakup before saving.',
                ),
              ),
            )
          else
            for (var index = 0; index < components.length; index++)
              _componentEditor(index),
          const SizedBox(height: 20),
          const Text(
            'Attendance impact',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallMetric(
                'Present',
                '${widget.employee.presentDays}',
                VistoraColors.green,
              ),
              _smallMetric(
                'Absent',
                '${widget.employee.absentDays}',
                VistoraColors.pink,
              ),
              _smallMetric(
                'Half day',
                '${widget.employee.halfDays}',
                VistoraColors.amber,
              ),
              _smallMetric(
                'Paid leave',
                '${widget.employee.paidLeaveDays}',
                VistoraColors.cyan,
              ),
              _smallMetric(
                'Missing',
                '${widget.employee.missingAttendanceDays}',
                VistoraColors.orange,
              ),
              _smallMetric(
                'Holidays',
                '${widget.employee.holidayDays}',
                VistoraColors.muted,
              ),
            ],
          ),
          if (widget.employee.leaveBalances.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Leave balances',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Credited'), numeric: true),
                  DataColumn(label: Text('Used'), numeric: true),
                  DataColumn(label: Text('Remaining'), numeric: true),
                ],
                rows: widget.employee.leaveBalances
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.name)),
                          DataCell(Text('${item.credited}')),
                          DataCell(Text('${item.used}')),
                          DataCell(Text('${item.balance}')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (widget.editable) ...[
            FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(busy ? 'Saving…' : 'Save payroll changes'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _rollback,
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Return employee payroll to draft'),
            ),
          ] else
            FilledButton.icon(
              onPressed: _showSlip,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Open released salary slip'),
            ),
        ],
      ),
    ),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          enabled: widget.editable && !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.currency_rupee),
          ),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            final amount = double.tryParse(value?.trim() ?? '');
            return amount == null || amount < 0
                ? 'Enter a valid non-negative amount.'
                : null;
          },
        ),
      );

  Widget _componentEditor(int index) {
    final item = components[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: item.name,
              enabled: widget.editable && !busy,
              decoration: const InputDecoration(labelText: 'Component name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a component name.'
                  : null,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Earning',
                        child: Text('Earning'),
                      ),
                      DropdownMenuItem(
                        value: 'Deduction',
                        child: Text('Deduction'),
                      ),
                      DropdownMenuItem(
                        value: 'Reimbursement',
                        child: Text('Reimbursement'),
                      ),
                    ],
                    onChanged: !widget.editable || busy
                        ? null
                        : (value) =>
                              setState(() => item.type = value ?? item.type),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextFormField(
                    controller: item.amount,
                    enabled: widget.editable && !busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Monthly'),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      return amount == null || amount < 0 ? 'Invalid' : null;
                    },
                  ),
                ),
                if (widget.editable)
                  IconButton(
                    tooltip: 'Remove component',
                    onPressed: busy ? null : () => _removeComponent(index),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: VistoraColors.pink,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _smallMetric(String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Text(
          '$label $value',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      );
}

class _ComponentDraft {
  _ComponentDraft({
    required this.name,
    required this.amount,
    required this.type,
  });

  factory _ComponentDraft.fromComponent(PayrollComponent value) =>
      _ComponentDraft(
        name: TextEditingController(text: value.name),
        amount: TextEditingController(text: value.amount.toStringAsFixed(2)),
        type: value.type,
      );

  final TextEditingController name;
  final TextEditingController amount;
  String type;

  PayrollComponent get value => PayrollComponent(
    name: name.text.trim(),
    type: type,
    amount: double.tryParse(amount.text.trim()) ?? 0,
  );

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _PayrollMetric extends StatelessWidget {
  const _PayrollMetric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 135,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _EmployeePayrollCard extends StatelessWidget {
  const _EmployeePayrollCard({
    required this.item,
    required this.enabled,
    required this.released,
    required this.view,
    required this.rollbackEmployee,
    required this.viewSlip,
    required this.calculate,
    required this.rollback,
    required this.addArrears,
    required this.mrEnabled,
    required this.includeMrExpense,
    required this.rollbackMrExpense,
  });
  final PayrollEmployeeSummary item;
  final bool enabled;
  final bool released;
  final VoidCallback view;
  final VoidCallback rollbackEmployee;
  final VoidCallback viewSlip;
  final VoidCallback calculate;
  final VoidCallback rollback;
  final VoidCallback addArrears;
  final bool mrEnabled;
  final VoidCallback includeMrExpense;
  final VoidCallback rollbackMrExpense;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: VistoraColors.orange.withValues(alpha: .14),
                child: Text(
                  item.employeeName
                      .split(RegExp(r'\s+'))
                      .where((part) => part.isNotEmpty)
                      .take(2)
                      .map((part) => part[0].toUpperCase())
                      .join(),
                  style: const TextStyle(
                    color: VistoraColors.orange,
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
                      item.employeeName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${item.employeeCode} • ${item.status.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                _money(item.netPayable),
                style: const TextStyle(
                  color: VistoraColors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Deduct ${item.deductionDays} days • ${_money(item.attendanceDeduction)}',
          ),
          Text(
            'Paid leave ${item.paidLeaveDays} • Pending leave ${item.pendingLeaveDays} • Missing check-in ${item.missingAttendanceDays} • Holidays ${item.holidayDays}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (mrEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Approved field expenses: ${_money(item.mrExpense)}',
                style: const TextStyle(
                  color: VistoraColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                onPressed: view,
                icon: Icon(released ? Icons.visibility : Icons.edit_outlined),
                label: Text(released ? 'View' : 'View & edit'),
              ),
              TextButton.icon(
                onPressed: enabled ? calculate : null,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Recalculate'),
              ),
              TextButton.icon(
                onPressed: enabled ? rollback : null,
                icon: const Icon(Icons.undo),
                label: const Text('Undo deduction'),
              ),
              TextButton.icon(
                onPressed: enabled ? addArrears : null,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Add arrears'),
              ),
              if (mrEnabled)
                TextButton.icon(
                  onPressed: enabled ? includeMrExpense : null,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Add field expense'),
                ),
              if (mrEnabled && item.mrExpense > 0)
                TextButton.icon(
                  onPressed: enabled ? rollbackMrExpense : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo field expense'),
                ),
              if (enabled)
                TextButton.icon(
                  onPressed: rollbackEmployee,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('Draft'),
                ),
              if (released)
                FilledButton.icon(
                  onPressed: viewSlip,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Salary slip'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
