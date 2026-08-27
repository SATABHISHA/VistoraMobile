import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/employees/data/employee_management_repository.dart';
import 'package:vistora_mobile/features/employees/domain/employee_models.dart';

final employeeManagementRepositoryProvider =
    Provider<EmployeeManagementRepository>(
      (ref) => EmployeeManagementRepository(ref.watch(apiClientProvider)),
    );

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  ConsumerState<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends ConsumerState<EmployeeManagementScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _status = 'all';
  int _page = 1;
  bool _busy = false;
  late Future<EmployeePage> _future;

  EmployeeManagementRepository get repository =>
      ref.read(employeeManagementRepositoryProvider);

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

  Future<EmployeePage> _load() => repository.employees(
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    status: _status == 'all' ? null : _status,
    page: _page,
  );

  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _action(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: const Color(0xFF5A182B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([ManagedEmployee? employee]) async {
    final first = TextEditingController(text: employee?.firstName);
    final last = TextEditingController(text: employee?.lastName);
    final email = TextEditingController(text: employee?.workEmail);
    final mobile = TextEditingController(text: employee?.mobile);
    var role = employee?.role == 'Supervisor' ? 'Supervisor' : 'Employee';
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  employee == null ? 'Add employee' : 'Edit employee',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: first,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: last,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Employee',
                      child: Text('Employee'),
                    ),
                    DropdownMenuItem(
                      value: 'Supervisor',
                      child: Text('Supervisor'),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => role = value ?? role),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(employee == null ? 'Create employee' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final firstName = first.text.trim();
    final lastName = last.text.trim();
    final workEmail = email.text.trim();
    final phone = mobile.text.trim();
    first.dispose();
    last.dispose();
    email.dispose();
    mobile.dispose();
    if (accepted != true || firstName.isEmpty || lastName.isEmpty) return;
    await _action(
      () => employee == null
          ? repository.create(
              firstName: firstName,
              lastName: lastName,
              role: role,
              workEmail: workEmail,
              mobile: phone,
            )
          : repository.update(
              id: employee.id,
              firstName: firstName,
              lastName: lastName,
              role: role,
              workEmail: workEmail,
              mobile: phone,
            ),
      employee == null ? 'Employee created.' : 'Employee updated.',
    );
  }

  Future<void> _credentials(ManagedEmployee employee) async {
    final username = TextEditingController(text: employee.username);
    final email = TextEditingController(text: employee.workEmail);
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.password_outlined),
        title: Text('${employee.hasCredentials ? 'Reset' : 'Create'} login'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Login email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'Minimum 8 characters',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save login'),
          ),
        ],
      ),
    );
    final login = username.text.trim();
    final loginEmail = email.text.trim();
    final secret = password.text;
    username.dispose();
    email.dispose();
    password.dispose();
    if (accepted != true ||
        login.isEmpty ||
        loginEmail.isEmpty ||
        secret.length < 8) {
      return;
    }
    await _action(
      () => repository.credentials(
        employeeId: employee.id,
        username: login,
        email: loginEmail,
        password: secret,
      ),
      'Login credentials saved for ${employee.name}.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Employee Directory'),
      actions: [
        IconButton(
          tooltip: 'Add employee',
          onPressed: _busy ? null : _edit,
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<EmployeePage>(
        future: _future,
        builder: (context, snapshot) {
          final page = snapshot.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF351B22), Color(0xFF092941)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.groups_2_outlined,
                      size: 38,
                      color: VistoraColors.cyan,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            page == null
                                ? 'Your workforce'
                                : '${page.total} employee profiles',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Identity, access, salary snapshot and attendance.',
                            style: TextStyle(color: VistoraColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search name or employee ID',
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 300),
                    () => mounted ? _refresh(reset: true) : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All employees')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  _status = value ?? 'all';
                  _refresh(reset: true);
                },
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                _EmployeeError(error: snapshot.error, retry: _refresh)
              else if (page == null || page.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: Text('No employee profiles found.')),
                  ),
                )
              else ...[
                ...page.items.asMap().entries.map(
                  (entry) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 260 + entry.key * 35),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: _EmployeeCard(
                      employee: entry.value,
                      busy: _busy,
                      edit: () => _edit(entry.value),
                      credentials: () => _credentials(entry.value),
                      toggle: () => _action(
                        () => repository.setActive(
                          entry.value,
                          entry.value.status != 'active',
                        ),
                        '${entry.value.name} status updated.',
                      ),
                      attendance: () => context.go(
                        '/team-attendance?q=${Uri.encodeQueryComponent(entry.value.code)}',
                      ),
                      salary: () => context.go(
                        '/salary-structures?q=${Uri.encodeQueryComponent(entry.value.code)}',
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Page ${page.page} of ${page.lastPage}',
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: page.page > 1
                          ? () {
                              _page--;
                              _refresh();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: page.hasMore
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

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.busy,
    required this.edit,
    required this.credentials,
    required this.toggle,
    required this.attendance,
    required this.salary,
  });

  final ManagedEmployee employee;
  final bool busy;
  final VoidCallback edit;
  final VoidCallback credentials;
  final VoidCallback toggle;
  final VoidCallback attendance;
  final VoidCallback salary;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: VistoraColors.orange.withValues(alpha: .14),
                  child: Text(
                    _initials(employee.name),
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
                        employee.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${employee.code} · ${employee.role}',
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (employee.status == 'active'
                                ? VistoraColors.green
                                : VistoraColors.pink)
                            .withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    employee.status.toUpperCase(),
                    style: TextStyle(
                      color: employee.status == 'active'
                          ? VistoraColors.green
                          : VistoraColors.pink,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (employee.designation != null)
                  _Tag(Icons.badge_outlined, employee.designation!),
                if (employee.department != null)
                  _Tag(Icons.account_tree_outlined, employee.department!),
                if (employee.branch != null)
                  _Tag(Icons.apartment_outlined, employee.branch!),
                _Tag(
                  employee.hasCredentials
                      ? Icons.verified_user_outlined
                      : Icons.person_off_outlined,
                  employee.hasCredentials ? employee.username! : 'No login',
                ),
              ],
            ),
            if (employee.netMonthly != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VistoraColors.green.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: VistoraColors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Net / month ${money.format(employee.netMonthly)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (employee.ctcAnnual != null)
                      Text(
                        'CTC ${money.format(employee.ctcAnnual)}',
                        style: const TextStyle(
                          color: VistoraColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: attendance,
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Attendance'),
                ),
                TextButton.icon(
                  onPressed: salary,
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: const Text('Salary'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : edit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : credentials,
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: Text(
                    employee.hasCredentials ? 'Reset login' : 'Login',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : toggle,
                  icon: Icon(
                    employee.status == 'active'
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 18,
                  ),
                  label: Text(
                    employee.status == 'active' ? 'Deactivate' : 'Activate',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: VistoraColors.cyan),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _EmployeeError extends StatelessWidget {
  const _EmployeeError({required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: VistoraColors.pink, size: 38),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
