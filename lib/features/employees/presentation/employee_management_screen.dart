import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/employees/data/employee_management_repository.dart';
import 'package:vistora_mobile/features/employees/domain/employee_models.dart';
import 'package:vistora_mobile/features/tenant_settings/data/tenant_settings_repository.dart';
import 'package:vistora_mobile/features/tenant_settings/domain/tenant_settings_models.dart';

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
    setState(() {
      _future = _load();
    });
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
    final masterRepository = TenantSettingsRepository(
      ref.read(apiClientProvider),
    );
    late final List<List<MasterItem>> masters;
    late final List<String> employmentTypes;
    try {
      masters = await Future.wait([
        masterRepository.masters('branches'),
        masterRepository.masters('states'),
        masterRepository.masters('business_units'),
        masterRepository.masters('departments'),
        masterRepository.masters('designations'),
      ]);
      employmentTypes = await masterRepository.employmentTypes();
    } catch (error) {
      if (mounted) _snack('Unable to load employee dropdowns: $error');
      return;
    }
    if (!mounted) return;
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _EmployeeEditorSheet(
        employee: employee,
        masters: {
          'branches': masters[0],
          'states': masters[1],
          'business_units': masters[2],
          'departments': masters[3],
          'designations': masters[4],
        },
        employmentTypes: employmentTypes,
        onAddMaster: _masterCreator(masterRepository),
      ),
    );
    if (values == null) return;
    await _action(
      () => employee == null
          ? repository.create(values)
          : repository.update(id: employee.id, data: values),
      employee == null ? 'Employee created.' : 'Employee updated.',
    );
  }

  Future<void> _changeStatus(String value) async {
    setState(() => _status = value);
    await _refresh(reset: true);
  }

  Future<List<MasterItem>> Function(String, String, String?) _masterCreator(
    TenantSettingsRepository repository,
  ) => (type, name, code) async {
    await repository.createMaster(type: type, name: name, code: code);
    return repository.masters(type);
  };

  void _snack(String message, {bool success = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success
              ? const Color(0xFF176B55)
              : const Color(0xFF765019),
          duration: const Duration(seconds: 4),
        ),
      );

  void _showDetails(ManagedEmployee employee) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Employee code', employee.code),
              _detail('Role', employee.role),
              _detail('Designation', employee.designation),
              _detail('Department', employee.department),
              _detail('Branch', employee.branch),
              _detail('State', employee.state),
              _detail('Business unit', employee.businessUnit),
              _detail('Work email', employee.workEmail),
              _detail('Mobile', employee.mobile),
              _detail(
                'Date of birth',
                employee.dob == null ? null : _date(employee.dob!),
              ),
              _detail(
                'Joining date',
                employee.joiningDate == null
                    ? null
                    : _date(employee.joiningDate!),
              ),
              _detail('Username', employee.username),
              _detail(
                'Net monthly',
                employee.netMonthly == null
                    ? null
                    : _money(employee.netMonthly!),
              ),
              _detail(
                'Annual CTC',
                employee.ctcAnnual == null ? null : _money(employee.ctcAnnual!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteNewEmployee() async {
    final name = TextEditingController();
    final email = TextEditingController();
    var validity = '7-days';
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.link_outlined),
          title: const Text('New employee onboarding link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Generate a secure link to share with a new employee.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Employee name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Employee email *',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: validity,
                  decoration: const InputDecoration(labelText: 'Link validity'),
                  items: const [
                    DropdownMenuItem(
                      value: 'one-time',
                      child: Text('One time'),
                    ),
                    DropdownMenuItem(
                      value: '48-hours',
                      child: Text('48 hours'),
                    ),
                    DropdownMenuItem(value: '7-days', child: Text('7 days')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => validity = value ?? validity),
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
                'name': name.text.trim(),
                'email': email.text.trim(),
                'validity': validity,
              }),
              child: const Text('Generate link'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    email.dispose();
    if (input == null || input['email']?.isNotEmpty != true) {
      if (input != null) _snack('Enter the new employee email first.');
      return;
    }
    await _action(() async {
      final invitation = await repository.createInvitation(
        email: input['email']!,
        employeeName: input['name'],
        validityType: input['validity'] ?? '7-days',
      );
      final url = invitation.url;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Onboarding link ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (invitation.username.isNotEmpty) ...[
                const Text(
                  'Assigned login username',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                SelectableText(invitation.username),
                const SizedBox(height: 14),
              ],
              const Text(
                'Share this secure onboarding link:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SelectableText(url),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final delivery = await repository.emailInvitation(
                  token: url.split('/').last,
                  email: input['email'],
                );
                if (context.mounted) {
                  _snack(delivery.message, success: delivery.sent);
                }
              },
              child: const Text('Send company email'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) _snack('Copied.');
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri(
                  scheme: 'mailto',
                  queryParameters: {
                    'to': input['email'],
                    'subject': 'Complete your Vistora onboarding',
                    'body': 'Please complete your onboarding: $url',
                  },
                ),
              ),
              child: const Text('Open email app'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }, 'Onboarding link generated.');
  }

  Future<void> _credentials(ManagedEmployee employee) async {
    final username = TextEditingController(text: employee.username);
    final email = TextEditingController(text: employee.workEmail);
    final password = TextEditingController();
    final action = await showDialog<String>(
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
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save login'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'email'),
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Save & email'),
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
    if ((action != 'save' && action != 'email') ||
        login.isEmpty ||
        loginEmail.isEmpty ||
        secret.length < 8) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repository.credentials(
        employeeId: employee.id,
        username: login,
        email: loginEmail,
        password: secret,
      );
      await _refresh();
      if (action == 'email') {
        final delivery = await repository.emailCredentials(
          employeeId: employee.id,
          username: login,
          email: loginEmail,
          password: secret,
        );
        if (mounted) _snack(delivery.message, success: delivery.sent);
      } else if (mounted) {
        _snack('Login credentials saved for ${employee.name}.');
      }
    } catch (error) {
      if (mounted) _snack(error.toString(), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _edit,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add employee'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _inviteNewEmployee,
                      icon: const Icon(Icons.link_outlined),
                      label: const Text('Onboarding link'),
                    ),
                  ),
                ],
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
                  _changeStatus(value ?? 'all');
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
                      details: () => _showDetails(entry.value),
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

class _EmployeeEditorSheet extends StatefulWidget {
  const _EmployeeEditorSheet({
    this.employee,
    required this.masters,
    required this.employmentTypes,
    required this.onAddMaster,
  });

  final ManagedEmployee? employee;
  final Map<String, List<MasterItem>> masters;
  final List<String> employmentTypes;
  final Future<List<MasterItem>> Function(String, String, String?) onAddMaster;

  @override
  State<_EmployeeEditorSheet> createState() => _EmployeeEditorSheetState();
}

class _EmployeeEditorSheetState extends State<_EmployeeEditorSheet> {
  late final Map<String, TextEditingController> _fields;
  late final Map<String, List<MasterItem>> _masterLists;
  late final List<String> _employmentTypes;
  late String _role;
  late String _employmentStatus;
  late int? _branchId;
  late int? _stateId;
  late int? _businessUnitId;
  late int? _departmentId;
  late int? _designationId;
  late bool _sameAddress;

  ManagedEmployee? get employee => widget.employee;

  @override
  void initState() {
    super.initState();
    _masterLists = {
      for (final entry in widget.masters.entries) entry.key: [...entry.value],
    };
    final e = employee;
    _employmentTypes = [...widget.employmentTypes];
    final currentEmploymentType = e?.employmentType?.trim();
    if (currentEmploymentType != null &&
        currentEmploymentType.isNotEmpty &&
        !_employmentTypes.any(
          (item) => item.toLowerCase() == currentEmploymentType.toLowerCase(),
        )) {
      _employmentTypes.add(currentEmploymentType);
    }
    String value(String? input) => input ?? '';
    String date(DateTime? input) =>
        input == null ? '' : DateFormat('yyyy-MM-dd').format(input);
    _fields = {
      'prefix': TextEditingController(text: value(e?.prefix ?? 'Mr.')),
      'first_name': TextEditingController(text: value(e?.firstName)),
      'middle_name': TextEditingController(text: value(e?.middleName)),
      'last_name': TextEditingController(text: value(e?.lastName)),
      'dob': TextEditingController(text: date(e?.dob)),
      'gender': TextEditingController(text: value(e?.gender)),
      'marital_status': TextEditingController(text: value(e?.maritalStatus)),
      'blood_group': TextEditingController(text: value(e?.bloodGroup)),
      'nationality': TextEditingController(
        text: value(e?.nationality ?? 'Indian'),
      ),
      'personal_email': TextEditingController(text: value(e?.personalEmail)),
      'work_email': TextEditingController(text: value(e?.workEmail)),
      'mobile': TextEditingController(text: value(e?.mobile)),
      'emergency_contact_name': TextEditingController(
        text: value(e?.emergencyContactName),
      ),
      'emergency_contact_phone': TextEditingController(
        text: value(e?.emergencyContactPhone),
      ),
      'emergency_contact_relation': TextEditingController(
        text: value(e?.emergencyContactRelation),
      ),
      'pan': TextEditingController(text: value(e?.pan)),
      'aadhaar': TextEditingController(text: value(e?.aadhaar)),
      'passport_no': TextEditingController(text: value(e?.passportNo)),
      'passport_expiry': TextEditingController(text: date(e?.passportExpiry)),
      'permanent_address': TextEditingController(
        text: value(e?.permanentAddress),
      ),
      'permanent_city': TextEditingController(text: value(e?.permanentCity)),
      'permanent_state': TextEditingController(text: value(e?.permanentState)),
      'permanent_country': TextEditingController(
        text: value(e?.permanentCountry ?? 'India'),
      ),
      'permanent_pin': TextEditingController(text: value(e?.permanentPin)),
      'current_address': TextEditingController(text: value(e?.currentAddress)),
      'current_city': TextEditingController(text: value(e?.currentCity)),
      'current_state': TextEditingController(text: value(e?.currentState)),
      'current_country': TextEditingController(
        text: value(e?.currentCountry ?? 'India'),
      ),
      'current_pin': TextEditingController(text: value(e?.currentPin)),
      'emp_code': TextEditingController(text: value(e?.code)),
      'doj': TextEditingController(text: date(e?.joiningDate)),
      'employment_type': TextEditingController(text: value(e?.employmentType)),
    };
    _role = e?.role == 'Supervisor' ? 'Supervisor' : 'Employee';
    _employmentStatus = e?.employmentStatus ?? 'Probation';
    _branchId = e?.branchId;
    _stateId = e?.stateId;
    _businessUnitId = e?.businessUnitId;
    _departmentId = e?.departmentId;
    _designationId = e?.designationId;
    _sameAddress =
        e != null &&
        e.currentAddress == e.permanentAddress &&
        e.currentCity == e.permanentCity &&
        e.currentState == e.permanentState &&
        e.currentCountry == e.permanentCountry &&
        e.currentPin == e.permanentPin;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController field(String key) => _fields[key]!;

  String? nullable(String key) {
    final value = field(key).text.trim();
    return value.isEmpty ? null : value;
  }

  Widget text(
    String key,
    String label, {
    bool email = false,
    bool multiline = false,
  }) => TextField(
    controller: field(key),
    keyboardType: email
        ? TextInputType.emailAddress
        : multiline
        ? TextInputType.multiline
        : null,
    maxLines: multiline ? 3 : 1,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(labelText: label),
  );

  Widget heading(String value) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 9),
    child: Text(
      value,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: VistoraColors.orange,
      ),
    ),
  );

  Widget master(
    String key,
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) {
    final items = _masterLists[key] ?? const <MasterItem>[];
    final valid = value != null && items.any((item) => item.id == value)
        ? value
        : null;
    return DropdownButtonFormField<int>(
      value: valid,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item.id,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget masterWithAdd(
    String key,
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) => Row(
    children: [
      Expanded(child: master(key, label, value, onChanged)),
      const SizedBox(width: 4),
      IconButton.filledTonal(
        tooltip: 'Add $label',
        onPressed: () async {
          final name = TextEditingController();
          final code = TextEditingController();
          final result = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('Add $label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Code (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add'),
                ),
              ],
            ),
          );
          final nameValue = name.text.trim();
          final codeValue = code.text.trim();
          name.dispose();
          code.dispose();
          if (result != true || nameValue.isEmpty) return;
          try {
            final items = await widget.onAddMaster(
              key,
              nameValue,
              codeValue.isEmpty ? null : codeValue,
            );
            if (!mounted) return;
            setState(() => _masterLists[key] = items);
            final added = items
                .where((item) => item.name == nameValue)
                .toList();
            if (added.isNotEmpty) onChanged(added.last.id);
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to add $label: $error')),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget employmentTypeWithAdd() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: _employmentTypes.contains(field('employment_type').text)
              ? field('employment_type').text
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Employment type'),
          hint: const Text('Select employment type'),
          items: _employmentTypes
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => field('employment_type').text = value ?? ''),
        ),
      ),
      const SizedBox(width: 4),
      IconButton.filledTonal(
        tooltip: 'Add employment type',
        onPressed: () async {
          final controller = TextEditingController();
          final result = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Add employment type'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add'),
                ),
              ],
            ),
          );
          final value = controller.text.trim();
          controller.dispose();
          if (result != true || value.isEmpty) return;
          final existing = _employmentTypes.indexWhere(
            (item) => item.toLowerCase() == value.toLowerCase(),
          );
          setState(() {
            if (existing < 0) {
              _employmentTypes.add(value);
              _employmentTypes.sort();
            }
            field('employment_type').text = existing < 0
                ? value
                : _employmentTypes[existing];
          });
        },
        icon: const Icon(Icons.add),
      ),
    ],
  );

  void save() {
    final first = field('first_name').text.trim();
    final last = field('last_name').text.trim();
    if (first.isEmpty || last.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First and last name are required.')),
      );
      return;
    }
    final current = _sameAddress
        ? {
            'current_address': nullable('permanent_address'),
            'current_city': nullable('permanent_city'),
            'current_state': nullable('permanent_state'),
            'current_country': nullable('permanent_country'),
            'current_pin': nullable('permanent_pin'),
          }
        : {
            'current_address': nullable('current_address'),
            'current_city': nullable('current_city'),
            'current_state': nullable('current_state'),
            'current_country': nullable('current_country'),
            'current_pin': nullable('current_pin'),
          };
    Navigator.pop(context, <String, dynamic>{
      'prefix': nullable('prefix'),
      'first_name': first,
      'middle_name': nullable('middle_name'),
      'last_name': last,
      'dob': nullable('dob'),
      'gender': nullable('gender'),
      'marital_status': nullable('marital_status'),
      'blood_group': nullable('blood_group'),
      'nationality': nullable('nationality'),
      'personal_email': nullable('personal_email'),
      'work_email': nullable('work_email'),
      'mobile': nullable('mobile'),
      'emergency_contact_name': nullable('emergency_contact_name'),
      'emergency_contact_phone': nullable('emergency_contact_phone'),
      'emergency_contact_relation': nullable('emergency_contact_relation'),
      'pan': nullable('pan'),
      'aadhaar': nullable('aadhaar'),
      'passport_no': nullable('passport_no'),
      'passport_expiry': nullable('passport_expiry'),
      'permanent_address': nullable('permanent_address'),
      'permanent_city': nullable('permanent_city'),
      'permanent_state': nullable('permanent_state'),
      'permanent_country': nullable('permanent_country'),
      'permanent_pin': nullable('permanent_pin'),
      ...current,
      'doj': nullable('doj'),
      'role_type': _role,
      'employment_type': nullable('employment_type'),
      'employment_status': _employmentStatus,
      'branch_id': _branchId,
      'state_id': _stateId,
      'business_unit_id': _businessUnitId,
      'department_id': _departmentId,
      'designation_id': _designationId,
      'supervisor_ids': employee?.supervisorIds ?? const <int>[],
      if (field('emp_code').text.trim().isNotEmpty)
        'emp_code': field('emp_code').text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            employee == null ? 'Add employee' : 'Edit employee',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Complete employee profile, access and employment details.',
            style: TextStyle(color: VistoraColors.muted),
          ),
          heading('Personal details'),
          Row(
            children: [
              Expanded(child: text('prefix', 'Prefix')),
              const SizedBox(width: 10),
              Expanded(child: text('first_name', 'First name *')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: text('middle_name', 'Middle name')),
              const SizedBox(width: 10),
              Expanded(child: text('last_name', 'Last name *')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: text('dob', 'Date of birth')),
              const SizedBox(width: 10),
              Expanded(child: text('nationality', 'Nationality')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: text('personal_email', 'Personal email', email: true),
              ),
              const SizedBox(width: 10),
              Expanded(child: text('work_email', 'Work email', email: true)),
            ],
          ),
          const SizedBox(height: 10),
          text('mobile', 'Mobile'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: text('gender', 'Gender')),
              const SizedBox(width: 10),
              Expanded(child: text('marital_status', 'Marital status')),
            ],
          ),
          const SizedBox(height: 10),
          text('blood_group', 'Blood group'),
          heading('Emergency contact'),
          Row(
            children: [
              Expanded(child: text('emergency_contact_name', 'Name')),
              const SizedBox(width: 10),
              Expanded(child: text('emergency_contact_phone', 'Number')),
            ],
          ),
          const SizedBox(height: 10),
          text('emergency_contact_relation', 'Relation'),
          heading('Identity and statutory'),
          Row(
            children: [
              Expanded(child: text('pan', 'PAN')),
              const SizedBox(width: 10),
              Expanded(child: text('aadhaar', 'Aadhaar')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: text('passport_no', 'Passport number')),
              const SizedBox(width: 10),
              Expanded(child: text('passport_expiry', 'Passport expiry')),
            ],
          ),
          heading('Addresses'),
          text('permanent_address', 'Permanent address', multiline: true),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: text('permanent_city', 'City')),
              const SizedBox(width: 10),
              Expanded(child: text('permanent_state', 'State')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: text('permanent_country', 'Country')),
              const SizedBox(width: 10),
              Expanded(child: text('permanent_pin', 'PIN')),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Current address same as permanent'),
            value: _sameAddress,
            onChanged: (value) => setState(() => _sameAddress = value),
          ),
          if (!_sameAddress) ...[
            text('current_address', 'Current address', multiline: true),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: text('current_city', 'City')),
                const SizedBox(width: 10),
                Expanded(child: text('current_state', 'State')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: text('current_country', 'Country')),
                const SizedBox(width: 10),
                Expanded(child: text('current_pin', 'PIN')),
              ],
            ),
          ],
          heading('Employment'),
          Row(
            children: [
              Expanded(child: text('emp_code', 'Employee code')),
              const SizedBox(width: 10),
              Expanded(child: text('doj', 'Joining date')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: masterWithAdd(
                  'branches',
                  'Branch',
                  _branchId,
                  (value) => setState(() => _branchId = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: masterWithAdd(
                  'states',
                  'State',
                  _stateId,
                  (value) => setState(() => _stateId = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: masterWithAdd(
                  'business_units',
                  'Business unit',
                  _businessUnitId,
                  (value) => setState(() => _businessUnitId = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: masterWithAdd(
                  'departments',
                  'Department',
                  _departmentId,
                  (value) => setState(() => _departmentId = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: masterWithAdd(
                  'designations',
                  'Designation',
                  _designationId,
                  (value) => setState(() => _designationId = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: employmentTypeWithAdd()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _role,
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
                  onChanged: (value) => setState(() => _role = value ?? _role),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _employmentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Employment status',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Probation',
                      child: Text('Probation'),
                    ),
                    DropdownMenuItem(
                      value: 'Confirmed',
                      child: Text('Confirmed'),
                    ),
                    DropdownMenuItem(
                      value: 'Notice Period',
                      child: Text('Notice Period'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _employmentStatus = value ?? _employmentStatus,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: Text(employee == null ? 'Create employee' : 'Save employee'),
          ),
        ],
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
    required this.details,
  });

  final ManagedEmployee employee;
  final bool busy;
  final VoidCallback edit;
  final VoidCallback credentials;
  final VoidCallback toggle;
  final VoidCallback attendance;
  final VoidCallback salary;
  final VoidCallback details;

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
                TextButton.icon(
                  onPressed: details,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Full details'),
                ),
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

Widget _detail(String label, String? value) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 125,
        child: Text(label, style: const TextStyle(color: VistoraColors.muted)),
      ),
      Expanded(
        child: Text(
          value?.isNotEmpty == true ? value! : '—',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  ),
);
String _date(DateTime value) => DateFormat('dd MMM yyyy').format(value);
String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
