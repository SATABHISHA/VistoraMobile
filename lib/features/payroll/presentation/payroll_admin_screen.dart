import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/payroll/data/payroll_repository.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';

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
  late Future<PayrollCollection> result;

  @override
  void initState() {
    super.initState();
    result = _load();
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
              Text(
                collection.companyName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: month,
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
                      initialValue: year,
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
                              OutlinedButton.icon(
                                onPressed: mutating || cycle.status == 'on_hold'
                                    ? null
                                    : () => mutate(
                                        () => repository.putOnHold(cycle.id),
                                      ),
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
                ...cycle.employees.map(
                  (item) => _EmployeePayrollCard(
                    item: item,
                    enabled: !mutating && cycle.status != 'released',
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
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  Future<void> _confirmRollbackDeductions(PayrollCycleSummary cycle) async {
    final yes = await _confirm(
      'Rollback deductions?',
      'This removes attendance and leave deductions for the selected cycle. They can be calculated again.',
    );
    if (yes) await mutate(() => repository.rollbackDeductions(cycle.id));
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

class _EmployeePayrollCard extends StatelessWidget {
  const _EmployeePayrollCard({
    required this.item,
    required this.enabled,
    required this.calculate,
    required this.rollback,
    required this.addArrears,
  });
  final PayrollEmployeeSummary item;
  final bool enabled;
  final VoidCallback calculate;
  final VoidCallback rollback;
  final VoidCallback addArrears;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.employeeName} (${item.employeeCode})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
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
            ],
          ),
        ],
      ),
    ),
  );
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
