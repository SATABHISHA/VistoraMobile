import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/core/widgets/status_badge.dart';
import 'package:vistora_mobile/features/payslips/domain/payslip.dart';
import 'package:vistora_mobile/features/payslips/presentation/payslip_document.dart';
import 'package:vistora_mobile/features/payslips/presentation/payslip_providers.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';

class PayslipsScreen extends ConsumerStatefulWidget {
  const PayslipsScreen({super.key});

  @override
  ConsumerState<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends ConsumerState<PayslipsScreen> {
  int _year = DateTime.now().year;
  int? _month;
  int _page = 1;
  static const _pageSize = 8;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).session?.user.normalizedRole;
    if (const {'admin', 'hr'}.contains(role)) {
      return const _AdminPayslipsView();
    }
    final result = ref.watch(payslipsProvider(_year));
    return Scaffold(
      appBar: AppBar(title: const Text('Payslips')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(payslipsProvider(_year));
          await ref.read(payslipsProvider(_year).future);
        },
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Salary statements',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _year,
                    items: List.generate(
                      6,
                      (index) => DropdownMenuItem(
                        value: DateTime.now().year - index,
                        child: Text('${DateTime.now().year - index}'),
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      _year = value ?? _year;
                      _page = 1;
                    }),
                  ),
                ],
              ),
              DropdownButtonFormField<int?>(
                value: _month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All months'),
                  ),
                  ...List.generate(
                    12,
                    (index) => DropdownMenuItem<int?>(
                      value: index + 1,
                      child: Text(
                        DateFormat.MMMM().format(DateTime(2026, index + 1)),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _month = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 14),
              result.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AsyncErrorCard(
                  error: error,
                  onRetry: () => ref.invalidate(payslipsProvider(_year)),
                ),
                data: (collection) {
                  final filtered = collection.items
                      .where((item) => _month == null || item.month == _month)
                      .toList();
                  final pages = (filtered.length / _pageSize).ceil().clamp(
                    1,
                    999,
                  );
                  final page = _page.clamp(1, pages);
                  final visible = filtered
                      .skip((page - 1) * _pageSize)
                      .take(_pageSize)
                      .toList();
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      title: 'No released payslips',
                      message:
                          'Released salary statements for this period will appear here.',
                      icon: Icons.receipt_long_outlined,
                    );
                  }
                  return Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 850
                              ? 3
                              : constraints.maxWidth >= 540
                              ? 2
                              : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visible.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: columns == 1 ? 2.0 : 1.25,
                                ),
                            itemBuilder: (context, index) => _PayslipCard(
                              item: visible[index],
                              onOpen: () => _showPayslip(
                                context,
                                visible[index],
                                collection.companyName,
                              ),
                            ),
                          );
                        },
                      ),
                      if (pages > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: page > 1
                                  ? () => setState(() => _page = page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Page $page of $pages'),
                            IconButton(
                              onPressed: page < pages
                                  ? () => setState(() => _page = page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayslip(BuildContext context, Payslip item, String companyName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PayslipSheet(item: item, companyName: companyName),
    );
  }
}

class _AdminPayslipsView extends ConsumerStatefulWidget {
  const _AdminPayslipsView();

  @override
  ConsumerState<_AdminPayslipsView> createState() => _AdminPayslipsViewState();
}

class _AdminPayslipsViewState extends ConsumerState<_AdminPayslipsView> {
  final _searchController = TextEditingController();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _search = '';
  int _page = 1;
  static const _pageSize = 10;

  String get _period => '$_year-${_month.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(adminPayrollProvider(_period));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Payslips'),
        actions: [
          IconButton(
            tooltip: 'Refresh payslips',
            onPressed: () => ref.invalidate(adminPayrollProvider(_period)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminPayrollProvider(_period));
          await ref.read(adminPayrollProvider(_period).future);
        },
        child: ResponsiveCenter(
          child: result.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorCard(
              error: error,
              onRetry: () => ref.invalidate(adminPayrollProvider(_period)),
            ),
            data: (collection) => _adminContent(context, collection),
          ),
        ),
      ),
    );
  }

  Widget _adminContent(BuildContext context, PayrollCollection collection) {
    final cycle = collection.cycles.firstOrNull;
    final employees =
        cycle?.employees.where((item) => _matches(item, _search)).toList() ??
        const <PayrollEmployeeSummary>[];
    final pages = (employees.length / _pageSize).ceil().clamp(1, 999);
    final page = _page.clamp(1, pages);
    final visibleEmployees = employees
        .skip((page - 1) * _pageSize)
        .take(_pageSize)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          collection.companyName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Review released salary statements by employee',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: VistoraColors.muted),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _month,
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
                  onChanged: (value) => setState(() {
                    _month = value ?? _month;
                    _page = 1;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: constraints.maxWidth < 460 ? 118 : 150,
                child: DropdownButtonFormField<int>(
                  value: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: List.generate(
                    6,
                    (index) => DropdownMenuItem(
                      value: DateTime.now().year - index,
                      child: Text('${DateTime.now().year - index}'),
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _year = value ?? _year;
                    _page = 1;
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {
            _search = value.trim().toLowerCase();
            _page = 1;
          }),
          decoration: const InputDecoration(
            labelText: 'Search employees',
            hintText: 'Name, employee code, email or mobile',
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.manage_search),
          ),
        ),
        const SizedBox(height: 16),
        if (cycle == null || cycle.status != 'released')
          const EmptyState(
            title: 'No released payslips for this period',
            message: 'Release payroll to publish employee salary statements.',
            icon: Icons.receipt_long_outlined,
          )
        else ...[
          _PayrollOverview(cycle: cycle),
          const SizedBox(height: 16),
          Text(
            '${employees.length} employee${employees.length == 1 ? '' : 's'}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (employees.isEmpty)
            const EmptyState(
              title: 'No matching employees',
              message: 'Try a different name, code, email or mobile number.',
              icon: Icons.person_search_outlined,
            )
          else
            ...visibleEmployees.map(
              (item) => _AdminPayslipCard(
                item: item,
                cycle: cycle,
                companyName: collection.companyName,
              ),
            ),
          if (pages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: page > 1
                      ? () => setState(() => _page = page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page $page of $pages'),
                IconButton(
                  onPressed: page < pages
                      ? () => setState(() => _page = page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ],
    );
  }

  bool _matches(PayrollEmployeeSummary item, String search) {
    if (search.isEmpty) return true;
    return [
      item.employeeName,
      item.employeeCode,
      item.employeeEmail ?? '',
      item.employeeMobile ?? '',
    ].any((value) => value.toLowerCase().contains(search));
  }
}

class _PayrollOverview extends StatelessWidget {
  const _PayrollOverview({required this.cycle});
  final PayrollCycleSummary cycle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        children: [
          _metric(
            'Period',
            '${DateFormat.MMMM().format(DateTime(2026, cycle.month))} ${cycle.year}',
          ),
          _metric('Employees', '${cycle.employees.length}'),
          _metric(
            'Total payroll',
            _money(cycle.totalPayroll),
            accent: VistoraColors.green,
          ),
          Chip(
            avatar: Icon(
              cycle.status == 'released' ? Icons.check_circle : Icons.pending,
              color: cycle.status == 'released'
                  ? VistoraColors.green
                  : VistoraColors.amber,
              size: 18,
            ),
            label: Text(cycle.status.toUpperCase()),
          ),
        ],
      ),
    ),
  );

  static Widget _metric(String label, String value, {Color? accent}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: VistoraColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 17,
          color: accent,
        ),
      ),
    ],
  );
}

class _AdminPayslipCard extends StatelessWidget {
  const _AdminPayslipCard({
    required this.item,
    required this.cycle,
    required this.companyName,
  });
  final PayrollEmployeeSummary item;
  final PayrollCycleSummary cycle;
  final String companyName;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: VistoraColors.orange.withValues(alpha: .14),
                  foregroundColor: VistoraColors.orange,
                  child: Text(_initials(item.employeeName)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.employeeCode}${item.employeeEmail == null ? '' : ' • ${item.employeeEmail}'}',
                        style: const TextStyle(
                          color: VistoraColors.muted,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(item.netPayable),
                  style: const TextStyle(
                    color: VistoraColors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Gross ${_money(item.grossAmount)}'),
                _pill(
                  'Deduction ${_money(item.statutoryDeduction + item.attendanceDeduction)}',
                  color: VistoraColors.amber,
                ),
                _pill(
                  'Attendance ${item.deductionDays} days',
                  color: VistoraColors.cyan,
                ),
                _pill(
                  item.status.toUpperCase(),
                  color: item.status == 'released'
                      ? VistoraColors.green
                      : VistoraColors.amber,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'View employee details  ›',
                style: TextStyle(
                  color: VistoraColors.cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PayslipSheet(
        item: Payslip.fromPayroll(cycle: cycle, employee: item),
        companyName: companyName,
      ),
    );
  }

  static Widget _pill(String text, {Color color = VistoraColors.muted}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.item, required this.onOpen});
  final Payslip item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: VistoraColors.amber,
                ),
                const Spacer(),
                const StatusBadge('released'),
              ],
            ),
            const Spacer(),
            Text(
              item.periodLabel,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              _money(item.netPayable),
              style: const TextStyle(
                color: VistoraColors.green,
                fontWeight: FontWeight.w900,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Tap to view or export PDF',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class PayslipSheet extends StatelessWidget {
  const PayslipSheet({
    required this.item,
    required this.companyName,
    super.key,
  });
  final Payslip item;
  final String companyName;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .88,
    minChildSize: .55,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.all(22),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF3B201D), Color(0xFF082C43)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              const Text(
                'Employee Salary Statement',
                style: TextStyle(color: VistoraColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Payslip • ${item.periodLabel}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Preview or share PDF',
              onPressed: () => Printing.layoutPdf(
                name:
                    'Payslip-${item.employeeCode}-${item.year}-${item.month}.pdf',
                onLayout: (_) =>
                    buildPayslipPdf(payslip: item, companyName: companyName),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
        ),
        const Divider(height: 30),
        _detail('Employee', item.employeeName),
        _detail('Employee code', item.employeeCode),
        if (item.designation != null && item.designation!.isNotEmpty)
          _detail('Designation', item.designation!),
        if (item.department != null && item.department!.isNotEmpty)
          _detail('Department', item.department!),
        if (item.employeeEmail != null) _detail('Email', item.employeeEmail!),
        if (item.employeeMobile != null)
          _detail('Mobile', item.employeeMobile!),
        const SizedBox(height: 20),
        _section(context, 'Salary breakup'),
        const SizedBox(height: 10),
        if (item.components.isNotEmpty)
          _componentBreakup(item)
        else
          const Text(
            'No salary component breakup was recorded for this payslip.',
            style: TextStyle(color: VistoraColors.muted),
          ),
        _detail('Gross monthly', _money(item.grossAmount)),
        _detail('Statutory deductions', '- ${_money(item.statutoryDeduction)}'),
        _detail('Net salary before attendance', _money(item.baseAmount)),
        _detail(
          'Attendance / LOP (${_days(item.deductionDays)} days)',
          '- ${_money(item.attendanceDeduction)}',
        ),
        _detail('Arrears / adjustments', _money(item.arrearsAmount)),
        if (item.mrExpenseAmount > 0)
          _detail('Approved field expenses', _money(item.mrExpenseAmount)),
        const Divider(height: 30),
        Card(
          color: VistoraColors.green.withValues(alpha: .1),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Net Payable',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                Text(
                  _money(item.netPayable),
                  style: const TextStyle(
                    color: VistoraColors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _section(context, 'Attendance impact'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric('Present', '${item.presentDays}', VistoraColors.cyan),
            _metric('Absent', '${item.absentDays}', VistoraColors.pink),
            _metric('Half day', _days(item.halfDays), VistoraColors.amber),
            _metric('Paid leave', '${item.paidLeaveDays}', VistoraColors.green),
            _metric(
              'Missing check-in',
              '${item.missingAttendanceDays}',
              VistoraColors.orange,
            ),
            _metric('Holidays', '${item.holidayDays}', VistoraColors.muted),
          ],
        ),
        if (item.leaveBalances.isNotEmpty) ...[
          const SizedBox(height: 22),
          _section(context, 'Leave balance'),
          const SizedBox(height: 10),
          _leaveTable(item.leaveBalances),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final bytes = await buildPayslipPdf(
              payslip: item,
              companyName: companyName,
            );
            await Printing.sharePdf(
              bytes: bytes,
              filename:
                  'Payslip-${item.employeeCode}-${item.year}-${item.month}.pdf',
            );
          },
          icon: const Icon(Icons.ios_share),
          label: const Text('Share PDF'),
        ),
      ],
    ),
  );

  static Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: VistoraColors.muted),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  static Widget _section(BuildContext context, String value) => Text(
    value.toUpperCase(),
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: VistoraColors.orange,
      fontWeight: FontWeight.w900,
      letterSpacing: .8,
    ),
  );

  static Widget _metric(String label, String value, Color color) => Container(
    width: 126,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  static Widget _componentBreakup(Payslip payslip) {
    const types = ['Earning', 'Deduction', 'Reimbursement'];
    return Column(
      children: [
        for (final type in types)
          if (payslip.components.where((item) => item.type == type).isNotEmpty)
            _componentTable(
              payslip.components.where((item) => item.type == type).toList(),
              title: type,
            ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                VistoraColors.green.withValues(alpha: .13),
                VistoraColors.orange.withValues(alpha: .10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: VistoraColors.green.withValues(alpha: .25),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _summaryAmount(
                  'Gross salary',
                  _money(payslip.grossAmount),
                  VistoraColors.green,
                ),
              ),
              Container(width: 1, height: 34, color: VistoraColors.muted),
              Expanded(
                child: _summaryAmount(
                  'Net payable',
                  _money(payslip.netPayable),
                  VistoraColors.orange,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _summaryAmount(
    String label,
    String amount,
    Color color, {
    bool alignEnd = false,
  }) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: VistoraColors.muted, fontSize: 11),
      ),
      const SizedBox(height: 3),
      Text(
        amount,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    ],
  );

  static Widget _componentTable(
    List<PayslipComponent> components, {
    required String title,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: title == 'Deduction'
                ? VistoraColors.pink
                : title == 'Reimbursement'
                ? VistoraColors.amber
                : VistoraColors.green,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              VistoraColors.cyan.withValues(alpha: .08),
            ),
            columns: const [
              DataColumn(label: Text('Component')),
              DataColumn(label: Text('Monthly'), numeric: true),
            ],
            rows: components
                .map(
                  (item) => DataRow(
                    cells: [
                      DataCell(Text(item.name)),
                      DataCell(Text(_money(item.amount))),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  static Widget _leaveTable(List<PayslipLeaveBalance> balances) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            VistoraColors.green.withValues(alpha: .08),
          ),
          columns: const [
            DataColumn(label: Text('Leave type')),
            DataColumn(label: Text('Credited'), numeric: true),
            DataColumn(label: Text('Used'), numeric: true),
            DataColumn(label: Text('Remaining'), numeric: true),
          ],
          rows: balances
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item.name)),
                    DataCell(Text(_days(item.credited))),
                    DataCell(Text(_days(item.used))),
                    DataCell(Text(_days(item.balance))),
                  ],
                ),
              )
              .toList(),
        ),
      );

  static String _days(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
