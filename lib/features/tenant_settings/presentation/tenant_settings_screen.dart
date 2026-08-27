import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/tenant_settings/data/tenant_settings_repository.dart';
import 'package:vistora_mobile/features/tenant_settings/domain/tenant_settings_models.dart';

final tenantSettingsRepositoryProvider = Provider<TenantSettingsRepository>(
  (ref) => TenantSettingsRepository(ref.watch(apiClientProvider)),
);

class TenantSettingsScreen extends ConsumerStatefulWidget {
  const TenantSettingsScreen({super.key});

  @override
  ConsumerState<TenantSettingsScreen> createState() =>
      _TenantSettingsScreenState();
}

class _TenantSettingsScreenState extends ConsumerState<TenantSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<TenantSettings> _future;
  bool _initialized = false;
  bool _busy = false;

  final _company = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  final _timezone = TextEditingController();
  final _prefix = TextEditingController();
  final _nextCode = TextEditingController();
  final _padding = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController();
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController();
  final _smtpUser = TextEditingController();
  final _smtpPassword = TextEditingController();
  final _smtpFromEmail = TextEditingController();
  final _smtpFromName = TextEditingController();
  final _smtpTest = TextEditingController();

  int _fiscalMonth = 4;
  bool _geofence = false;
  String _encryption = 'tls';
  String _masterType = 'branches';
  late Future<List<MasterItem>> _masters;

  TenantSettingsRepository get repository =>
      ref.read(tenantSettingsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _future = repository.settings();
    _masters = repository.masters(_masterType);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in [
      _company,
      _address,
      _gstin,
      _timezone,
      _prefix,
      _nextCode,
      _padding,
      _latitude,
      _longitude,
      _radius,
      _smtpHost,
      _smtpPort,
      _smtpUser,
      _smtpPassword,
      _smtpFromEmail,
      _smtpFromName,
      _smtpTest,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(TenantSettings value) {
    if (_initialized) return;
    _initialized = true;
    _company.text = value.companyName;
    _address.text = value.registeredAddress;
    _gstin.text = value.gstin;
    _timezone.text = value.timezone;
    _prefix.text = value.employeeCodePrefix;
    _nextCode.text = '${value.employeeCodeNext}';
    _padding.text = '${value.employeeCodePadding}';
    _latitude.text = value.officeLatitude?.toString() ?? '';
    _longitude.text = value.officeLongitude?.toString() ?? '';
    _radius.text = '${value.geofenceRadiusMeters}';
    _smtpHost.text = value.smtpHost;
    _smtpPort.text = '${value.smtpPort}';
    _smtpUser.text = value.smtpUsername;
    _smtpFromEmail.text = value.smtpFromEmail;
    _smtpFromName.text = value.smtpFromName;
    _fiscalMonth = value.fiscalYearStartMonth;
    _geofence = value.geofenceEnabled;
    _encryption = value.smtpEncryption;
  }

  Future<void> _save(Map<String, dynamic> data, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await repository.update(data);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      backgroundColor: const Color(0xFF5A182B),
    ),
  );

  Future<void> _refreshMasters() async {
    setState(() => _masters = repository.masters(_masterType));
    await _masters;
  }

  Future<void> _addMaster() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.add_circle_outline),
        title: Text('Add ${_masterLabel(_masterType)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            if (_masterType != 'states') ...[
              const SizedBox(height: 12),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final itemName = name.text.trim();
    final itemCode = code.text.trim();
    name.dispose();
    code.dispose();
    if (accepted != true || itemName.isEmpty) return;
    try {
      await repository.createMaster(
        type: _masterType,
        name: itemName,
        code: itemCode,
      );
      await _refreshMasters();
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _deleteMaster(MasterItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: const Text(
          'This is allowed only when no protected tenant record depends on it.',
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
    if (confirmed != true) return;
    try {
      await repository.deleteMaster(_masterType, item.id);
      await _refreshMasters();
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Company Settings'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const [
          Tab(icon: Icon(Icons.apartment_outlined), text: 'Company'),
          Tab(icon: Icon(Icons.account_tree_outlined), text: 'Organisation'),
          Tab(icon: Icon(Icons.location_on_outlined), text: 'Attendance'),
          Tab(icon: Icon(Icons.mail_outline), text: 'SMTP'),
        ],
      ),
    ),
    body: FutureBuilder<TenantSettings>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SettingsError(
            error: snapshot.error,
            retry: () => setState(() {
              _initialized = false;
              _future = repository.settings();
            }),
          );
        }
        _populate(snapshot.requireData);
        return TabBarView(
          controller: _tabs,
          children: [
            _companyTab(snapshot.requireData),
            _organisationTab(),
            _attendanceTab(),
            _smtpTab(),
          ],
        );
      },
    ),
  );

  Widget _companyTab(TenantSettings settings) => _SettingsList(
    children: [
      _HeroCard(
        icon: Icons.apartment_outlined,
        title: settings.companyName,
        subtitle: 'Corporate ID ${settings.corpId}',
        color: VistoraColors.orange,
      ),
      _field(_company, 'Company name'),
      _field(_address, 'Registered address', lines: 3),
      _field(_gstin, 'GSTIN'),
      _field(_timezone, 'Timezone'),
      DropdownButtonFormField<int>(
        value: _fiscalMonth,
        decoration: const InputDecoration(labelText: 'Financial year starts'),
        items: [
          for (var month = 1; month <= 12; month++)
            DropdownMenuItem(value: month, child: Text(_month(month))),
        ],
        onChanged: (value) => _fiscalMonth = value ?? 4,
      ),
      Row(
        children: [
          Expanded(child: _field(_prefix, 'Employee prefix')),
          const SizedBox(width: 10),
          Expanded(child: _field(_nextCode, 'Next number', number: true)),
          const SizedBox(width: 10),
          Expanded(child: _field(_padding, 'Padding', number: true)),
        ],
      ),
      _saveButton(
        () => _save({
          'company_name': _company.text.trim(),
          'registered_address': _address.text.trim().isEmpty
              ? null
              : _address.text.trim(),
          'gstin': _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
          'timezone': _timezone.text.trim(),
          'fiscal_year_start_month': _fiscalMonth,
          'employee_code_prefix': _prefix.text.trim(),
          'employee_code_next': int.tryParse(_nextCode.text) ?? 1,
          'employee_code_padding': int.tryParse(_padding.text) ?? 3,
        }, 'Company settings saved.'),
      ),
    ],
  );

  Widget _organisationTab() => _SettingsList(
    children: [
      const _HeroCard(
        icon: Icons.account_tree_outlined,
        title: 'Organisation masters',
        subtitle: 'Branches, units, teams, roles and states.',
        color: VistoraColors.cyan,
      ),
      DropdownButtonFormField<String>(
        value: _masterType,
        decoration: const InputDecoration(labelText: 'Master type'),
        items: const [
          DropdownMenuItem(value: 'branches', child: Text('Branches')),
          DropdownMenuItem(
            value: 'business_units',
            child: Text('Business units'),
          ),
          DropdownMenuItem(value: 'departments', child: Text('Departments')),
          DropdownMenuItem(value: 'designations', child: Text('Designations')),
          DropdownMenuItem(value: 'states', child: Text('States')),
        ],
        onChanged: (value) {
          if (value == null) return;
          _masterType = value;
          _refreshMasters();
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _addMaster,
          icon: const Icon(Icons.add),
          label: Text('Add ${_masterLabel(_masterType)}'),
        ),
      ),
      FutureBuilder<List<MasterItem>>(
        future: _masters,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _SettingsError(
              error: snapshot.error,
              retry: _refreshMasters,
            );
          }
          if (snapshot.requireData.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No records configured.')),
              ),
            );
          }
          return Column(
            children: snapshot.requireData
                .map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.hub_outlined,
                        color: VistoraColors.cyan,
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: item.code == null ? null : Text(item.code!),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _deleteMaster(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );

  Widget _attendanceTab() => _SettingsList(
    children: [
      const _HeroCard(
        icon: Icons.my_location_outlined,
        title: 'Attendance geofence',
        subtitle: 'Laravel validates the authoritative office boundary.',
        color: VistoraColors.green,
      ),
      SwitchListTile.adaptive(
        value: _geofence,
        contentPadding: EdgeInsets.zero,
        title: const Text('Require office geofence'),
        subtitle: const Text('Employees must check in within this boundary.'),
        onChanged: (value) => setState(() => _geofence = value),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: !_geofence
            ? const SizedBox.shrink()
            : Column(
                children: [
                  _field(_latitude, 'Office latitude', decimal: true),
                  _field(_longitude, 'Office longitude', decimal: true),
                  _field(_radius, 'Radius in metres', number: true),
                ],
              ),
      ),
      _saveButton(
        () => _save({
          'geofence_enabled': _geofence,
          'office_latitude': _latitude.text.trim().isEmpty
              ? null
              : double.tryParse(_latitude.text),
          'office_longitude': _longitude.text.trim().isEmpty
              ? null
              : double.tryParse(_longitude.text),
          'geofence_radius_meters': int.tryParse(_radius.text) ?? 200,
        }, 'Attendance boundary saved.'),
      ),
    ],
  );

  Widget _smtpTab() => _SettingsList(
    children: [
      const _HeroCard(
        icon: Icons.mark_email_read_outlined,
        title: 'Company email delivery',
        subtitle: 'Secure tenant SMTP configuration and test delivery.',
        color: VistoraColors.pink,
      ),
      _field(_smtpHost, 'SMTP host'),
      _field(_smtpPort, 'Port', number: true),
      _field(_smtpUser, 'Username'),
      TextField(
        controller: _smtpPassword,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password / app password',
          helperText: 'Leave blank to keep the saved password.',
        ),
      ),
      DropdownButtonFormField<String>(
        value: _encryption,
        decoration: const InputDecoration(labelText: 'Encryption'),
        items: const [
          DropdownMenuItem(value: 'tls', child: Text('TLS')),
          DropdownMenuItem(value: 'ssl', child: Text('SSL')),
        ],
        onChanged: (value) => _encryption = value ?? 'tls',
      ),
      _field(_smtpFromEmail, 'From email'),
      _field(_smtpFromName, 'From name'),
      _saveButton(
        () => _save({
          'smtp_host': _nullable(_smtpHost.text),
          'smtp_port': int.tryParse(_smtpPort.text),
          'smtp_username': _nullable(_smtpUser.text),
          if (_smtpPassword.text.isNotEmpty)
            'smtp_password': _smtpPassword.text,
          'smtp_encryption': _encryption,
          'smtp_from_email': _nullable(_smtpFromEmail.text),
          'smtp_from_name': _nullable(_smtpFromName.text),
        }, 'SMTP settings saved.'),
      ),
      const Divider(height: 32),
      _field(_smtpTest, 'Send test email to'),
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                if (_smtpTest.text.trim().isEmpty) return;
                setState(() => _busy = true);
                try {
                  await repository.testSmtp(_smtpTest.text);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMTP test email sent.')),
                  );
                } catch (error) {
                  if (mounted) _error(error);
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        icon: const Icon(Icons.send_outlined),
        label: const Text('Send test email'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool number = false,
    bool decimal = false,
  }) => TextField(
    controller: controller,
    minLines: lines,
    maxLines: lines,
    keyboardType: number || decimal
        ? TextInputType.numberWithOptions(decimal: decimal, signed: decimal)
        : null,
    decoration: InputDecoration(labelText: label),
  );

  Widget _saveButton(VoidCallback action) => FilledButton.icon(
    onPressed: _busy ? null : action,
    icon: _busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.save_outlined),
    label: const Text('Save changes'),
  );

  static String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _masterLabel(String value) => switch (value) {
    'branches' => 'branch',
    'business_units' => 'business unit',
    'departments' => 'department',
    'designations' => 'designation',
    _ => 'state',
  };

  static String _month(int value) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][value - 1];
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
    itemCount: children.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, index) => children[index],
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.15), VistoraColors.surface],
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: VistoraColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: VistoraColors.pink, size: 40),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
