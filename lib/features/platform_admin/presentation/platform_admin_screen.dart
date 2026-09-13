import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/platform_admin/data/platform_repository.dart';
import 'package:vistora_mobile/features/platform_admin/domain/platform_models.dart';
import 'package:vistora_mobile/features/tax_invoices/presentation/tax_invoice_view.dart';

final platformRepositoryProvider = Provider<PlatformRepository>(
  (ref) => PlatformRepository(ref.watch(apiClientProvider)),
);

class PlatformAdminScreen extends ConsumerStatefulWidget {
  const PlatformAdminScreen({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  ConsumerState<PlatformAdminScreen> createState() =>
      _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends ConsumerState<PlatformAdminScreen> {
  late int _index;

  static const _routes = [
    '/platform',
    '/platform/companies',
    '/platform/payments',
    '/platform/onboarding',
    '/platform/settings',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
  }

  @override
  void didUpdateWidget(covariant PlatformAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _index = widget.initialIndex.clamp(0, 4);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Platform Administration'),
          Text(
            'Vistora control centre',
            style: TextStyle(fontSize: 12, color: VistoraColors.muted),
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.space_dashboard_outlined),
                label: Text('Overview'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.apartment_outlined),
                label: Text('Companies'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.receipt_long_outlined),
                label: Text('Payments'),
              ),
              ButtonSegment(
                value: 3,
                icon: Icon(Icons.how_to_reg_outlined),
                label: Text('Onboarding'),
              ),
              ButtonSegment(
                value: 4,
                icon: Icon(Icons.tune_outlined),
                label: Text('Settings'),
              ),
            ],
            selected: {_index},
            onSelectionChanged: (selected) =>
                context.go(_routes[selected.single]),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [
              _OverviewView(),
              _CompaniesView(),
              _PaymentsView(),
              _OnboardingView(),
              _BillingSettingsView(),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OverviewView extends ConsumerStatefulWidget {
  const _OverviewView();

  @override
  ConsumerState<_OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends ConsumerState<_OverviewView> {
  late Future<PlatformOverview> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(platformRepositoryProvider).overview();
  }

  Future<void> _refresh() async {
    setState(() => _future = ref.read(platformRepositoryProvider).overview());
    await _future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<PlatformOverview>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingList();
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _refresh);
        }
        final overview = snapshot.requireData;
        final payments = overview.recentPayments;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _SectionHeader(
              eyebrow: 'PLATFORM HEALTH',
              title: 'Your Vistora network',
              subtitle: 'Live company and subscription activity.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Active companies',
                    value: '${overview.activeTenants}',
                    icon: Icons.check_circle_outline,
                    color: VistoraColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Inactive companies',
                    value: '${overview.inactiveTenants}',
                    icon: Icons.pause_circle_outline,
                    color: VistoraColors.pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TitleAction(
              title: 'Recent payments',
              action: 'View all',
              onTap: () => context.go('/platform/payments'),
            ),
            const SizedBox(height: 10),
            if (payments.isEmpty)
              const _EmptyCard(message: 'No subscription payments yet.')
            else
              ...payments
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => _Entrance(
                      delay: entry.key,
                      child: _PaymentCard(payment: entry.value),
                    ),
                  ),
          ],
        );
      },
    ),
  );
}

class _CreateTenantSheet extends StatefulWidget {
  const _CreateTenantSheet();

  @override
  State<_CreateTenantSheet> createState() => _CreateTenantSheetState();
}

class _CreateTenantSheetState extends State<_CreateTenantSheet> {
  final _formKey = GlobalKey<FormState>();
  final _corpId = TextEditingController();
  final _company = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _corpId,
      _company,
      _username,
      _email,
      _password,
      _confirmation,
      _phone,
      _gstin,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'corp_id': _corpId.text.trim().toUpperCase(),
      'company_name': _company.text.trim(),
      'admin_username': _username.text.trim(),
      'admin_email': _email.text.trim(),
      'admin_password': _password.text,
      'phone': _phone.text.trim(),
      'gstin': _gstin.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(
              eyebrow: 'NEW VISTORA WORKSPACE',
              title: 'Add a client',
              subtitle:
                  'Create the company and its primary tenant administrator in one secure step.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _corpId,
              textCapitalization: TextCapitalization.characters,
              validator: _required,
              decoration: const InputDecoration(
                labelText: 'Corporate ID *',
                hintText: 'AHN001',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _company,
              validator: _required,
              decoration: const InputDecoration(
                labelText: 'Company name *',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const _FormSectionLabel(title: 'PRIMARY ADMINISTRATOR'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _username,
              validator: _required,
              decoration: const InputDecoration(
                labelText: 'Admin username *',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Admin email is required.';
                }
                if (!value.contains('@') ||
                    !value.split('@').last.contains('.')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Admin email *',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              validator: (value) => (value?.length ?? 0) < 10
                  ? 'Use at least 10 characters.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Admin password *',
                helperText: 'Minimum 10 characters.',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match.' : null,
              decoration: const InputDecoration(
                labelText: 'Confirm password *',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const _FormSectionLabel(title: 'OPTIONAL COMPANY DETAILS'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gstin,
              textCapitalization: TextCapitalization.characters,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'GSTIN',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Create client workspace'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: VistoraColors.cyan,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );
}

class _CompaniesView extends ConsumerStatefulWidget {
  const _CompaniesView();

  @override
  ConsumerState<_CompaniesView> createState() => _CompaniesViewState();
}

class _CompaniesViewState extends ConsumerState<_CompaniesView> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _status = 'all';
  int _page = 1;
  bool _busy = false;
  late Future<PlatformPage<PlatformTenant>> _future;

  PlatformRepository get repository => ref.read(platformRepositoryProvider);

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

  Future<PlatformPage<PlatformTenant>> _load() => repository.tenants(
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
      _toast(context, message);
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final details = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VistoraColors.background,
      builder: (context) => const _CreateTenantSheet(),
    );
    if (details == null) return;
    final companyName = details['company_name']!;
    await _action(
      () => repository.createTenant(
        corpId: details['corp_id']!,
        companyName: companyName,
        adminUsername: details['admin_username']!,
        adminEmail: details['admin_email']!,
        adminPassword: details['admin_password']!,
        phone: details['phone'],
        gstin: details['gstin'],
      ),
      '$companyName and its primary administrator created.',
    );
  }

  Future<void> _manageAdmins(PlatformTenant tenant) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VistoraColors.background,
      builder: (context) => _TenantAdminsSheet(tenant: tenant),
    );
    if (mounted) await _refresh();
  }

  Future<void> _editBilling(PlatformTenant tenant) async {
    final values = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VistoraColors.background,
      builder: (context) => _TenantBillingSheet(tenant: tenant),
    );
    if (values == null) return;
    await _action(() async {
      await repository.updateTenantBillingProfile(
        tenantId: tenant.id,
        gstin: values['gstin'],
        phone: values['phone'],
      );
    }, '${tenant.companyName} billing details updated.');
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<PlatformPage<PlatformTenant>>(
      future: _future,
      builder: (context, snapshot) {
        final page = snapshot.data;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _TitleAction(
              title: 'Companies',
              action: 'Add company',
              icon: Icons.add_business_outlined,
              onTap: _busy ? null : _create,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search company or corporate ID',
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 320),
                  () => mounted ? _refresh(reset: true) : null,
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Company status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
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
              const _LoadingList()
            else if (snapshot.hasError)
              _ErrorState(error: snapshot.error, onRetry: _refresh)
            else if (page == null || page.items.isEmpty)
              const _EmptyCard(message: 'No companies match these filters.')
            else ...[
              ...page.items.asMap().entries.map(
                (entry) => _Entrance(
                  delay: entry.key,
                  child: _TenantCard(
                    tenant: entry.value,
                    busy: _busy,
                    onToggleStatus: () => _action(
                      () => repository.toggleTenantStatus(entry.value.id),
                      '${entry.value.companyName} status updated.',
                    ),
                    onFeature: (field, enabled) => _action(
                      () => repository.updateTenant(entry.value.id, {
                        field: enabled,
                      }),
                      '${entry.value.companyName} settings updated.',
                    ),
                    onViewDetails: () => _editBilling(entry.value),
                    onManageAdmins: () => _manageAdmins(entry.value),
                  ),
                ),
              ),
              _Pager(
                page: page.page,
                lastPage: page.lastPage,
                total: page.total,
                previous: page.page > 1
                    ? () {
                        _page--;
                        _refresh();
                      }
                    : null,
                next: page.hasMore
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
  );
}

class _PaymentsView extends ConsumerStatefulWidget {
  const _PaymentsView();

  @override
  ConsumerState<_PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends ConsumerState<_PaymentsView> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  int? _month;
  int? _year;
  bool _busy = false;
  late Future<PlatformPage<PlatformPayment>> _future;

  PlatformRepository get repository => ref.read(platformRepositoryProvider);

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

  Future<PlatformPage<PlatformPayment>> _load() => repository.payments(
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    month: _month,
    year: _year,
    page: _page,
  );

  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _edit([PlatformPayment? payment]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        repository.tenants(perPage: 100),
        repository.billingSettings(),
      ]);
      if (!mounted) return;
      final tenants = results[0] as PlatformPage<PlatformTenant>;
      final settings = results[1] as PlatformBillingSettings;
      if (tenants.items.isEmpty) {
        _toast(context, 'Create a company before recording a payment.');
        return;
      }
      final draft = await showModalBottomSheet<PlatformPaymentDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: VistoraColors.background,
        builder: (context) => _PaymentEditorSheet(
          tenants: tenants.items,
          settings: settings,
          payment: payment,
        ),
      );
      if (draft == null) return;
      await repository.savePayment(draft, paymentId: payment?.id);
      await _refresh(reset: payment == null);
      if (mounted) {
        _toast(
          context,
          payment == null
              ? 'Payment recorded and tax invoice generated.'
              : 'Payment and tax invoice updated.',
        );
      }
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(PlatformPayment payment) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final detail = await repository.paymentInvoice(payment.id);
      if (!mounted) return;
      await showTaxInvoicePreview(context, detail);
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(PlatformPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: VistoraColors.pink),
        title: const Text('Delete tax invoice?'),
        content: Text(
          'This removes ${payment.invoiceNo ?? 'this invoice'} and its payment record. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep invoice'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: VistoraColors.pink),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await repository.deletePayment(payment.id);
      await _refresh(reset: true);
      if (mounted) _toast(context, 'Payment and tax invoice deleted.');
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<PlatformPage<PlatformPayment>>(
      future: _future,
      builder: (context, snapshot) {
        final page = snapshot.data;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _TitleAction(
              title: 'Payments & tax invoices',
              action: 'Record',
              icon: Icons.add_card_outlined,
              onTap: _busy ? null : () => _edit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search corporate ID',
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 320),
                  () => mounted ? _refresh(reset: true) : null,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
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
                      _refresh(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      for (
                        var year = DateTime.now().year;
                        year >= DateTime.now().year - 5;
                        year--
                      )
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) {
                      _year = value;
                      _refresh(reset: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _LoadingList()
            else if (snapshot.hasError)
              _ErrorState(error: snapshot.error, onRetry: _refresh)
            else if (page == null || page.items.isEmpty)
              const _EmptyCard(message: 'No payments match these filters.')
            else ...[
              ...page.items.asMap().entries.map(
                (entry) => _Entrance(
                  delay: entry.key,
                  child: _PaymentCard(
                    payment: entry.value,
                    busy: _busy,
                    onView: () => _view(entry.value),
                    onEdit: () => _edit(entry.value),
                    onDelete: () => _delete(entry.value),
                  ),
                ),
              ),
              _Pager(
                page: page.page,
                lastPage: page.lastPage,
                total: page.total,
                previous: page.page > 1
                    ? () {
                        _page--;
                        _refresh();
                      }
                    : null,
                next: page.hasMore
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
  );
}

class _OnboardingView extends ConsumerStatefulWidget {
  const _OnboardingView();

  @override
  ConsumerState<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<_OnboardingView> {
  String _status = 'pending';
  int _page = 1;
  bool _busy = false;
  late Future<PlatformPage<PlatformOnboardingItem>> _future;

  PlatformRepository get repository => ref.read(platformRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PlatformPage<PlatformOnboardingItem>> _load() =>
      repository.onboarding(status: _status, page: _page);

  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _createRegistrationLink() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: VistoraColors.background,
    builder: (context) => const _ClientRegistrationLinkSheet(),
  );

  Future<void> _review(PlatformOnboardingItem item) async {
    var decision = 'approve';
    final notes = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.fact_check_outlined),
          title: Text('Review submission #${item.submissionId}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'approve',
                    icon: Icon(Icons.check),
                    label: Text('Approve'),
                  ),
                  ButtonSegment(
                    value: 'reject',
                    icon: Icon(Icons.close),
                    label: Text('Reject'),
                  ),
                ],
                selected: {decision},
                onSelectionChanged: (value) =>
                    setDialogState(() => decision = value.single),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Review notes'),
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
              child: const Text('Submit decision'),
            ),
          ],
        ),
      ),
    );
    final reviewNotes = notes.text;
    notes.dispose();
    if (accepted != true) return;
    setState(() => _busy = true);
    try {
      await repository.reviewOnboarding(
        id: item.id,
        decision: decision,
        notes: reviewNotes,
      );
      await _refresh();
      if (mounted) _toast(context, 'Onboarding decision saved.');
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<PlatformPage<PlatformOnboardingItem>>(
      future: _future,
      builder: (context, snapshot) {
        final page = snapshot.data;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _SectionHeader(
              eyebrow: 'CLIENT ONBOARDING',
              title: 'Registration queue',
              subtitle: 'Review new company applications securely.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VistoraColors.orange.withValues(alpha: .16),
                    VistoraColors.cyan.withValues(alpha: .09),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: VistoraColors.cyan.withValues(alpha: .22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _IconBadge(
                        icon: Icons.link_rounded,
                        color: VistoraColors.cyan,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Invite a new company',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a branded registration link to copy or email to the client.',
                    style: TextStyle(color: VistoraColors.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _createRegistrationLink,
                      icon: const Icon(Icons.add_link),
                      label: const Text('Create onboarding link'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                _status = value.single;
                _refresh(reset: true);
              },
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _LoadingList()
            else if (snapshot.hasError)
              _ErrorState(error: snapshot.error, onRetry: _refresh)
            else if (page == null || page.items.isEmpty)
              _EmptyCard(message: 'No $_status onboarding applications.')
            else ...[
              ...page.items.asMap().entries.map(
                (entry) => _Entrance(
                  delay: entry.key,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          _IconBadge(
                            icon: entry.value.status == 'pending'
                                ? Icons.hourglass_top
                                : entry.value.status == 'approved'
                                ? Icons.check
                                : Icons.close,
                            color: _statusColor(entry.value.status),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Submission #${entry.value.submissionId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value.createdAt == null
                                      ? 'Queue item #${entry.value.id}'
                                      : DateFormat.yMMMd().add_jm().format(
                                          entry.value.createdAt!,
                                        ),
                                  style: const TextStyle(
                                    color: VistoraColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (entry.value.status == 'pending')
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _review(entry.value),
                              child: const Text('Review'),
                            )
                          else
                            _StatusPill(status: entry.value.status),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _Pager(
                page: page.page,
                lastPage: page.lastPage,
                total: page.total,
                previous: page.page > 1
                    ? () {
                        _page--;
                        _refresh();
                      }
                    : null,
                next: page.hasMore
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
  );
}

class _ClientRegistrationLinkSheet extends ConsumerStatefulWidget {
  const _ClientRegistrationLinkSheet();

  @override
  ConsumerState<_ClientRegistrationLinkSheet> createState() =>
      _ClientRegistrationLinkSheetState();
}

class _ClientRegistrationLinkSheetState
    extends ConsumerState<_ClientRegistrationLinkSheet> {
  final _corpId = TextEditingController();
  final _hours = TextEditingController(text: '48');
  final _email = TextEditingController();
  String _validityType = 'one-time';
  PlatformRegistrationLink? _link;
  bool _busy = false;
  bool _sending = false;
  String? _sendMessage;
  bool? _sendSucceeded;

  PlatformRepository get repository => ref.read(platformRepositoryProvider);

  @override
  void dispose() {
    _corpId.dispose();
    _hours.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final hours = int.tryParse(_hours.text.trim());
    if (hours == null || hours < 1 || hours > 720) {
      _toast(context, 'Validity must be between 1 and 720 hours.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _link = null;
      _sendMessage = null;
      _sendSucceeded = null;
    });
    try {
      final link = await repository.createClientRegistrationLink(
        proposedCorpId: _corpId.text,
        validityType: _validityType,
        validHours: hours,
      );
      if (!mounted) return;
      setState(() => _link = link);
      _toast(context, 'Registration link created.');
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    final link = _link;
    if (link == null || link.url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    if (mounted) _toast(context, 'Registration link copied.');
  }

  Future<void> _sendLink() async {
    final link = _link;
    final email = _email.text.trim();
    if (link == null) return;
    if (!email.contains('@') || !email.split('@').last.contains('.')) {
      _toast(context, 'Enter a valid recipient email address.', error: true);
      return;
    }
    setState(() {
      _sending = true;
      _sendMessage = null;
    });
    try {
      await repository.sendClientRegistrationLink(
        linkId: link.id,
        email: email,
      );
      if (!mounted) return;
      setState(() {
        _sendSucceeded = true;
        _sendMessage = 'Invitation sent to $email.';
      });
      _toast(context, 'Invitation email sent.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sendSucceeded = false;
        _sendMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            eyebrow: 'SECURE CLIENT INVITATION',
            title: 'Create onboarding link',
            subtitle:
                'Generate a Vistora company registration link. Copy it or send it using your configured Superadmin SMTP.',
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _corpId,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Proposed Corporate ID (optional)',
                      hintText: 'Auto-generated if left blank',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _validityType,
                    decoration: const InputDecoration(
                      labelText: 'Link validity',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'one-time',
                        child: Text('One-time registration'),
                      ),
                      DropdownMenuItem(
                        value: 'limited',
                        child: Text('Limited validity'),
                      ),
                      DropdownMenuItem(
                        value: 'unlimited',
                        child: Text('Unlimited validity'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _validityType = value ?? 'one-time'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valid for (hours)',
                      helperText: 'Enter between 1 and 720 hours.',
                      prefixIcon: Icon(Icons.hourglass_bottom_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _generate,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_busy ? 'Generating…' : 'Generate link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _link == null
                ? const SizedBox.shrink(key: ValueKey('no-registration-link'))
                : _RegistrationLinkResult(
                    key: ValueKey(_link!.url),
                    link: _link!,
                    emailController: _email,
                    sending: _sending,
                    sendMessage: _sendMessage,
                    sendSucceeded: _sendSucceeded,
                    onCopy: _copyLink,
                    onSend: _sendLink,
                  ),
          ),
        ],
      ),
    ),
  );
}

class _RegistrationLinkResult extends StatelessWidget {
  const _RegistrationLinkResult({
    super.key,
    required this.link,
    required this.emailController,
    required this.sending,
    required this.sendMessage,
    required this.sendSucceeded,
    required this.onCopy,
    required this.onSend,
  });

  final PlatformRegistrationLink link;
  final TextEditingController emailController;
  final bool sending;
  final String? sendMessage;
  final bool? sendSucceeded;
  final VoidCallback onCopy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          VistoraColors.green.withValues(alpha: .12),
          VistoraColors.cyan.withValues(alpha: .08),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: VistoraColors.green.withValues(alpha: .27)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.verified_rounded, color: VistoraColors.green),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Your registration link is ready',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          link.url,
          style: const TextStyle(color: VistoraColors.cyan, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy link'),
            ),
            if (link.smtpConfigured)
              FilledButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mail_outline),
                label: Text(sending ? 'Sending…' : 'Send email'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (link.smtpConfigured) ...[
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Recipient email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Email uses the configured Superadmin SMTP settings.',
            style: TextStyle(color: VistoraColors.muted, fontSize: 12),
          ),
        ] else
          const Text(
            'Superadmin SMTP is not configured. Copy and share this link, or configure SMTP in Settings to email it from Vistora.',
            style: TextStyle(color: VistoraColors.amber, fontSize: 12),
          ),
        if (sendMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            sendMessage!,
            style: TextStyle(
              color: sendSucceeded == true
                  ? VistoraColors.green
                  : VistoraColors.pink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.busy,
    required this.onToggleStatus,
    required this.onFeature,
    required this.onViewDetails,
    required this.onManageAdmins,
  });

  final PlatformTenant tenant;
  final bool busy;
  final VoidCallback onToggleStatus;
  final void Function(String field, bool enabled) onFeature;
  final VoidCallback onViewDetails;
  final VoidCallback onManageAdmins;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: Icons.apartment_outlined,
                color: tenant.status == 'active'
                    ? VistoraColors.cyan
                    : VistoraColors.pink,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.companyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      tenant.corpId,
                      style: const TextStyle(color: VistoraColors.muted),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: tenant.status),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetric(
                icon: Icons.groups_outlined,
                label: '${tenant.employeeCount} employees',
              ),
              _MiniMetric(
                icon: Icons.admin_panel_settings_outlined,
                label: '${tenant.adminCount} admins',
              ),
              _MiniMetric(
                icon: Icons.storage_outlined,
                label: tenant.storageQuotaMb > 0
                    ? '${(tenant.storageUsedBytes / 1048576).toStringAsFixed(1)} / ${tenant.storageQuotaMb} MB'
                    : '${(tenant.storageUsedBytes / 1048576).toStringAsFixed(1)} MB',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: tenant.mrEnabled,
                label: const Text('MR'),
                onSelected: busy
                    ? null
                    : (value) => onFeature('mr_enabled', value),
              ),
              FilterChip(
                selected: tenant.projectsEnabled,
                label: const Text('Projects'),
                onSelected: busy
                    ? null
                    : (value) => onFeature('project_management_enabled', value),
              ),
              FilterChip(
                selected: tenant.fileManagerEnabled,
                label: const Text('Secure files'),
                onSelected: busy
                    ? null
                    : (value) => onFeature('file_manager_enabled', value),
              ),
              FilterChip(
                selected: tenant.financeHubEnabled,
                label: const Text('Finance Hub'),
                onSelected: busy
                    ? null
                    : (value) => onFeature('finance_hub_enabled', value),
              ),
              ActionChip(
                avatar: Icon(
                  tenant.status == 'active' ? Icons.pause : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(
                  tenant.status == 'active' ? 'Deactivate' : 'Activate',
                ),
                onPressed: busy ? null : onToggleStatus,
              ),
              ActionChip(
                avatar: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View details'),
                onPressed: busy ? null : onViewDetails,
              ),
              ActionChip(
                avatar: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: const Text('Manage admins'),
                onPressed: busy ? null : onManageAdmins,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TenantAdminsSheet extends ConsumerStatefulWidget {
  const _TenantAdminsSheet({required this.tenant});
  final PlatformTenant tenant;

  @override
  ConsumerState<_TenantAdminsSheet> createState() => _TenantAdminsSheetState();
}

class _TenantAdminsSheetState extends ConsumerState<_TenantAdminsSheet> {
  late Future<List<PlatformTenantAdmin>> _future;
  bool _busy = false;

  PlatformRepository get repository => ref.read(platformRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = repository.tenantAdmins(widget.tenant.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = repository.tenantAdmins(widget.tenant.id));
    await _future;
  }

  Future<void> _edit([PlatformTenantAdmin? admin]) async {
    if (_busy) return;
    final details = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VistoraColors.background,
      builder: (context) =>
          _TenantAdminEditorSheet(tenant: widget.tenant, admin: admin),
    );
    if (details == null) return;
    setState(() => _busy = true);
    try {
      if (admin == null) {
        await repository.createTenantAdmin(
          tenantId: widget.tenant.id,
          name: details['name']!,
          roleType: details['role_type']!,
          username: details['username']!,
          email: details['email']!,
          password: details['password']!,
        );
      } else {
        final body = <String, dynamic>{
          'name': details['name'],
          'role_type': details['role_type'],
          'username': details['username'],
          'email': details['email'],
          'status': details['status'],
        };
        if (details['password']?.isNotEmpty == true) {
          body['password'] = details['password'];
        }
        await repository.updateTenantAdmin(
          tenantId: widget.tenant.id,
          adminId: admin.id,
          data: body,
        );
      }
      if (!mounted) return;
      setState(() => _future = repository.tenantAdmins(widget.tenant.id));
      await _future;
      if (mounted) {
        _toast(
          context,
          admin == null
              ? 'Administrator added successfully.'
              : 'Administrator details updated.',
        );
      }
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              eyebrow: 'CLIENT ACCESS',
              title: 'Company admins',
              subtitle:
                  '${widget.tenant.companyName} · ${widget.tenant.corpId}',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add administrator'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<PlatformTenantAdmin>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _LoadingList();
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      error: snapshot.error,
                      onRetry: _refresh,
                    );
                  }
                  final admins = snapshot.data ?? const <PlatformTenantAdmin>[];
                  if (admins.isEmpty) {
                    return const _EmptyCard(
                      message: 'No Admin or HR accounts are registered.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: admins.length,
                    itemBuilder: (context, index) {
                      final admin = admins[index];
                      return _Entrance(
                        delay: index,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                _IconBadge(
                                  icon: Icons.manage_accounts_outlined,
                                  color: admin.status == 'active'
                                      ? VistoraColors.cyan
                                      : VistoraColors.pink,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        admin.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '${admin.email} · @${admin.username}',
                                        style: const TextStyle(
                                          color: VistoraColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 7,
                                        children: [
                                          _StatusPill(status: admin.status),
                                          _MiniMetric(
                                            icon: Icons.shield_outlined,
                                            label: admin.roleType,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        admin.lastLoginAt == null
                                            ? 'Last login: Never'
                                            : 'Last login: ${DateFormat.yMMMd().add_jm().format(admin.lastLoginAt!)}',
                                        style: const TextStyle(
                                          color: VistoraColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'Edit or reset password',
                                  onPressed: _busy ? null : () => _edit(admin),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TenantAdminEditorSheet extends StatefulWidget {
  const _TenantAdminEditorSheet({required this.tenant, this.admin});
  final PlatformTenant tenant;
  final PlatformTenantAdmin? admin;

  @override
  State<_TenantAdminEditorSheet> createState() =>
      _TenantAdminEditorSheetState();
}

class _TenantAdminEditorSheetState extends State<_TenantAdminEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _email;
  final _password = TextEditingController();
  late String _role;
  late String _status;

  @override
  void initState() {
    super.initState();
    final admin = widget.admin;
    _name = TextEditingController(text: admin?.name ?? '');
    _username = TextEditingController(text: admin?.username ?? '');
    _email = TextEditingController(text: admin?.email ?? '');
    _role = admin?.roleType ?? 'Admin';
    _status = admin?.status ?? 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'role_type': _role,
      'status': _status,
      'password': _password.text,
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              eyebrow: widget.admin == null
                  ? 'NEW COMPANY ACCOUNT'
                  : 'ACCOUNT MANAGEMENT',
              title: widget.admin == null ? 'Add administrator' : 'Edit admin',
              subtitle: widget.tenant.companyName,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the administrator name.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'HR', child: Text('HR')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'Admin'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a username.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Username *',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) =>
                  value == null ||
                      !value.contains('@') ||
                      !value.split('@').last.contains('.')
                  ? 'Enter a valid email address.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            if (widget.admin != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Account status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? 'active'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              validator: (value) {
                final password = value ?? '';
                if (widget.admin == null && password.isEmpty) {
                  return 'Set a temporary password.';
                }
                if (password.isNotEmpty && password.length < 10) {
                  return 'Use at least 10 characters.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: widget.admin == null
                    ? 'Temporary password *'
                    : 'New password (optional)',
                helperText: widget.admin == null
                    ? 'Minimum 10 characters.'
                    : 'Leave blank to keep the existing password.',
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  widget.admin == null
                      ? 'Create administrator'
                      : 'Save administrator',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    this.busy = false,
    this.onView,
    this.onEdit,
    this.onDelete,
  });
  final PlatformPayment payment;
  final bool busy;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconBadge(
                  icon: Icons.receipt_long_outlined,
                  color: VistoraColors.green,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.companyName ?? payment.corpId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${payment.invoiceNo ?? payment.corpId} · ${_humanize(payment.paymentType)}',
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money.format(payment.totalAmount),
                      style: const TextStyle(
                        color: VistoraColors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(status: payment.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_humanize(payment.periodType)} · '
              '${payment.paymentDate == null ? 'Date unavailable' : DateFormat.yMMMd().format(payment.paymentDate!)} · '
              '${_humanize(payment.paymentMode)}',
              style: const TextStyle(color: VistoraColors.muted),
            ),
            if (payment.gstAmount > 0)
              Text(
                'GST ${money.format(payment.gstAmount)}',
                style: const TextStyle(
                  color: VistoraColors.amber,
                  fontSize: 12,
                ),
              ),
            if (onView != null || onEdit != null || onDelete != null) ...[
              const SizedBox(height: 13),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onView != null)
                    ActionChip(
                      avatar: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View invoice'),
                      onPressed: busy ? null : onView,
                    ),
                  if (onEdit != null)
                    ActionChip(
                      avatar: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: busy ? null : onEdit,
                    ),
                  if (onDelete != null)
                    ActionChip(
                      avatar: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: VistoraColors.pink,
                      ),
                      label: const Text('Delete'),
                      onPressed: busy ? null : onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TenantBillingSheet extends StatefulWidget {
  const _TenantBillingSheet({required this.tenant});
  final PlatformTenant tenant;

  @override
  State<_TenantBillingSheet> createState() => _TenantBillingSheetState();
}

class _TenantBillingSheetState extends State<_TenantBillingSheet> {
  late final TextEditingController _gstin;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _gstin = TextEditingController(text: widget.tenant.gstin);
    _phone = TextEditingController(text: widget.tenant.phone);
  }

  @override
  void dispose() {
    _gstin.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Company details',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Only GSTIN and phone number can be changed here.',
            style: TextStyle(color: VistoraColors.muted),
          ),
          const SizedBox(height: 18),
          _ReadOnlyDetail(label: 'Company', value: widget.tenant.companyName),
          _ReadOnlyDetail(label: 'Corporate ID', value: widget.tenant.corpId),
          _ReadOnlyDetail(
            label: 'Status',
            value: _humanize(widget.tenant.status),
          ),
          _ReadOnlyDetail(
            label: 'Registered address',
            value: widget.tenant.registeredAddress ?? 'Not provided',
          ),
          _ReadOnlyDetail(
            label: 'Timezone',
            value: widget.tenant.timezone ?? 'Not provided',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            decoration: const InputDecoration(
              labelText: 'GSTIN',
              prefixIcon: Icon(Icons.receipt_long_outlined),
              helperText: '15 characters, or leave blank',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final gstin = _nullable(_gstin.text)?.toUpperCase();
                    if (gstin != null &&
                        !RegExp(r'^[0-9A-Z]{15}$').hasMatch(gstin)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid 15-character GSTIN or leave it blank.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'gstin': gstin,
                      'phone': _nullable(_phone.text),
                    });
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save details'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ReadOnlyDetail extends StatelessWidget {
  const _ReadOnlyDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: VistoraColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: VistoraColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _PaymentEditorSheet extends StatefulWidget {
  const _PaymentEditorSheet({
    required this.tenants,
    required this.settings,
    this.payment,
  });

  final List<PlatformTenant> tenants;
  final PlatformBillingSettings settings;
  final PlatformPayment? payment;

  @override
  State<_PaymentEditorSheet> createState() => _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends State<_PaymentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  late String _corpId;
  late String _paymentType;
  late String _periodType;
  late String _paymentMode;
  late String _gstType;
  late DateTime _paymentDate;
  DateTime? _customStart;
  DateTime? _customEnd;
  late bool _gstEnabled;

  PlatformTenant get tenant =>
      widget.tenants.firstWhere((item) => item.corpId == _corpId);

  double get amount => double.tryParse(_amount.text.trim()) ?? 0;
  double get taxRate => _gstType == 'igst'
      ? widget.settings.igstPercent
      : widget.settings.cgstPercent + widget.settings.sgstPercent;
  double get gstAmount => _gstEnabled ? amount * taxRate / 100 : 0;
  double get total => amount + gstAmount;

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    _corpId = payment?.corpId ?? widget.tenants.first.corpId;
    _paymentType = payment?.paymentType ?? 'period';
    _periodType =
        const {
          'monthly',
          'quarterly',
          'yearly',
          'custom',
        }.contains(payment?.periodType)
        ? payment!.periodType
        : 'monthly';
    _paymentMode = payment?.paymentMode ?? 'online';
    _gstType = payment?.gstType == 'igst' ? 'igst' : widget.settings.gstMode;
    _paymentDate = payment?.paymentDate ?? DateTime.now();
    _customStart = payment?.periodStart;
    _customEnd = payment?.periodEnd;
    _gstEnabled =
        payment?.gstEnabled ??
        (widget.settings.gstEnabled && tenant.gstin != null);
    _amount = TextEditingController(
      text: payment == null ? '' : payment.packageAmount.toStringAsFixed(2),
    );
    _reference = TextEditingController(
      text: payment?.paymentMode == 'cheque'
          ? payment?.chequeNo
          : payment?.transactionReference,
    );
    _notes = TextEditingController(text: payment?.notes);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final period = _periodRange();
    final canApplyGst = widget.settings.gstEnabled && tenant.gstin != null;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.72,
      maxChildSize: 0.98,
      builder: (context, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 28,
          ),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.payment == null
                  ? 'Record payment'
                  : 'Edit payment & invoice',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'The tax invoice updates from this single authoritative record.',
              style: TextStyle(color: VistoraColors.muted),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _corpId,
              decoration: const InputDecoration(
                labelText: 'Company',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
              items: widget.tenants
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.corpId,
                      child: Text(
                        '${item.companyName} · ${item.corpId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.payment != null
                  ? null
                  : (value) => setState(() {
                      _corpId = value ?? _corpId;
                      if (tenant.gstin == null) _gstEnabled = false;
                    }),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: tenant.gstin == null
                    ? VistoraColors.amber.withValues(alpha: 0.09)
                    : VistoraColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tenant.gstin == null
                      ? VistoraColors.amber.withValues(alpha: 0.4)
                      : VistoraColors.green.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tenant.gstin == null
                        ? Icons.info_outline
                        : Icons.verified_outlined,
                    color: tenant.gstin == null
                        ? VistoraColors.amber
                        : VistoraColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tenant.gstin == null
                          ? 'No company GSTIN. This invoice must be recorded without GST.'
                          : 'Company GSTIN: ${tenant.gstin}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _FormLabel('PAYMENT PURPOSE'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                showSelectedIcon: true,
                segments: const [
                  ButtonSegment(
                    value: 'installation',
                    label: Text('Installation'),
                  ),
                  ButtonSegment(value: 'initial', label: Text('Initial')),
                  ButtonSegment(value: 'advance', label: Text('Advance')),
                  ButtonSegment(value: 'period', label: Text('Period')),
                ],
                selected: {_paymentType},
                onSelectionChanged: (values) =>
                    setState(() => _paymentType = values.single),
              ),
            ),
            if (_paymentType == 'period') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _periodType,
                decoration: const InputDecoration(
                  labelText: 'Billing frequency',
                  prefixIcon: Icon(Icons.date_range_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                    value: 'quarterly',
                    child: Text('Quarterly'),
                  ),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (value) => setState(() {
                  _periodType = value ?? _periodType;
                  if (_periodType == 'custom') {
                    _customStart ??= _paymentDate;
                    _customEnd ??= _paymentDate;
                  }
                }),
              ),
              const SizedBox(height: 10),
              if (_periodType == 'custom')
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Period starts',
                        date: _customStart!,
                        onTap: () => _pickDate(
                          _customStart!,
                          (value) => _customStart = value,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: 'Period ends',
                        date: _customEnd!,
                        onTap: () => _pickDate(
                          _customEnd!,
                          (value) => _customEnd = value,
                        ),
                      ),
                    ),
                  ],
                )
              else
                _ReadOnlyDetail(
                  label: 'Automatically selected service period',
                  value:
                      '${DateFormat.yMMMd().format(period.$1!)} – ${DateFormat.yMMMd().format(period.$2!)}',
                ),
            ],
            const SizedBox(height: 14),
            _DateButton(
              label: 'Payment date',
              date: _paymentDate,
              onTap: () =>
                  _pickDate(_paymentDate, (value) => _paymentDate = value),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Base amount',
                prefixText: '₹ ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                return parsed == null || parsed <= 0
                    ? 'Enter an amount greater than zero.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              value: _gstEnabled,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Apply GST'),
              subtitle: Text(
                !widget.settings.gstEnabled
                    ? 'GST is disabled in platform settings.'
                    : tenant.gstin == null
                    ? 'Add the company GSTIN before applying GST.'
                    : 'Calculate tax using the configured rates.',
              ),
              onChanged: canApplyGst
                  ? (value) => setState(() => _gstEnabled = value)
                  : null,
            ),
            if (_gstEnabled) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cgst_sgst', label: Text('CGST + SGST')),
                  ButtonSegment(value: 'igst', label: Text('IGST')),
                ],
                selected: {_gstType},
                onSelectionChanged: (values) =>
                    setState(() => _gstType = values.single),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF171D32), Color(0xFF102B28)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _AmountRow(label: 'Base amount', value: money.format(amount)),
                  if (_gstEnabled && _gstType == 'cgst_sgst') ...[
                    _AmountRow(
                      label: 'CGST @ ${_rate(widget.settings.cgstPercent)}%',
                      value: money.format(
                        amount * widget.settings.cgstPercent / 100,
                      ),
                    ),
                    _AmountRow(
                      label: 'SGST @ ${_rate(widget.settings.sgstPercent)}%',
                      value: money.format(
                        amount * widget.settings.sgstPercent / 100,
                      ),
                    ),
                  ],
                  if (_gstEnabled && _gstType == 'igst')
                    _AmountRow(
                      label: 'IGST @ ${_rate(widget.settings.igstPercent)}%',
                      value: money.format(gstAmount),
                    ),
                  const Divider(),
                  _AmountRow(
                    label: 'Invoice total',
                    value: money.format(total),
                    strong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment mode',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
                DropdownMenuItem(value: 'neft', child: Text('NEFT')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
              ],
              onChanged: (value) => setState(() {
                _paymentMode = value ?? _paymentMode;
                _reference.clear();
              }),
            ),
            if (_paymentMode != 'cash') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _reference,
                decoration: InputDecoration(
                  labelText: _paymentMode == 'cheque'
                      ? 'Cheque number'
                      : 'Transaction reference (optional)',
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (value) =>
                    _paymentMode == 'cheque' &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the cheque number.'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(
                widget.payment == null
                    ? 'Record & generate invoice'
                    : 'Update invoice',
              ),
            ),
          ],
        ),
      ),
    );
  }

  (DateTime?, DateTime?) _periodRange() {
    if (_paymentType != 'period') return (null, null);
    if (_periodType == 'custom') return (_customStart, _customEnd);
    if (_periodType == 'yearly') {
      return (DateTime(_paymentDate.year), DateTime(_paymentDate.year, 12, 31));
    }
    if (_periodType == 'quarterly') {
      final startMonth = ((_paymentDate.month - 1) ~/ 3) * 3 + 1;
      return (
        DateTime(_paymentDate.year, startMonth),
        DateTime(_paymentDate.year, startMonth + 3, 0),
      );
    }
    return (
      DateTime(_paymentDate.year, _paymentDate.month),
      DateTime(_paymentDate.year, _paymentDate.month + 1, 0),
    );
  }

  Future<void> _pickDate(
    DateTime initial,
    void Function(DateTime) update,
  ) async {
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => update(value));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_periodType == 'custom' &&
        (_customStart == null ||
            _customEnd == null ||
            _customEnd!.isBefore(_customStart!))) {
      _toast(context, 'Choose a valid custom service period.', error: true);
      return;
    }
    Navigator.pop(
      context,
      PlatformPaymentDraft(
        corpId: _corpId,
        amount: amount,
        paymentType: _paymentType,
        periodType: _periodType,
        paymentDate: _paymentDate,
        periodStart: _customStart,
        periodEnd: _customEnd,
        gstEnabled: _gstEnabled,
        gstType: _gstType,
        cgstPercent: widget.settings.cgstPercent,
        sgstPercent: widget.settings.sgstPercent,
        igstPercent: widget.settings.igstPercent,
        paymentMode: _paymentMode,
        chequeNo: _paymentMode == 'cheque' ? _nullable(_reference.text) : null,
        transactionReference: _paymentMode != 'cheque'
            ? _nullable(_reference.text)
            : null,
        notes: _nullable(_notes.text),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: const TextStyle(
      color: VistoraColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(DateFormat.yMMMd().format(date)),
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? null : VistoraColors.muted,
              fontWeight: strong ? FontWeight.w900 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? VistoraColors.green : null,
            fontSize: strong ? 18 : null,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _BillingSettingsView extends ConsumerStatefulWidget {
  const _BillingSettingsView();

  @override
  ConsumerState<_BillingSettingsView> createState() =>
      _BillingSettingsViewState();
}

class _BillingSettingsViewState extends ConsumerState<_BillingSettingsView> {
  final _provider = TextEditingController();
  final _product = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _cgst = TextEditingController();
  final _sgst = TextEditingController();
  final _igst = TextEditingController();
  final _accountEmail = TextEditingController();
  final _newAccountEmail = TextEditingController();
  final _currentAccountPassword = TextEditingController();
  final _newAccountPassword = TextEditingController();
  final _confirmAccountPassword = TextEditingController();
  bool _gstEnabled = true;
  String _gstMode = 'cgst_sgst';
  bool _loading = true;
  bool _saving = false;
  bool _accountSaving = false;
  String? _sealUrl;
  Object? _error;

  PlatformRepository get repository => ref.read(platformRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _provider,
      _product,
      _gstin,
      _address,
      _email,
      _phone,
      _website,
      _cgst,
      _sgst,
      _igst,
      _accountEmail,
      _newAccountEmail,
      _currentAccountPassword,
      _newAccountPassword,
      _confirmAccountPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await repository.billingSettings();
      final accountEmail = await repository.superadminAccountEmail();
      if (!mounted) return;
      _apply(settings);
      _accountEmail.text = accountEmail;
      _newAccountEmail.text = accountEmail;
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(PlatformBillingSettings value) {
    _provider.text = value.providerCompanyName;
    _product.text = value.productName;
    _gstin.text = value.providerGstin ?? '';
    _address.text = value.providerAddress ?? '';
    _email.text = value.contactEmail;
    _phone.text = value.contactPhone ?? '';
    _website.text = value.website;
    _cgst.text = _rate(value.cgstPercent);
    _sgst.text = _rate(value.sgstPercent);
    _igst.text = _rate(value.igstPercent);
    setState(() {
      _gstEnabled = value.gstEnabled;
      _gstMode = value.gstMode;
      _sealUrl = value.sealUrl;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final cgst = double.tryParse(_cgst.text.trim()) ?? 0;
    final sgst = double.tryParse(_sgst.text.trim()) ?? 0;
    final igst = double.tryParse(_igst.text.trim()) ?? 0;
    if (_provider.text.trim().isEmpty || _product.text.trim().isEmpty) {
      _toast(context, 'Provider and product names are required.', error: true);
      return;
    }
    if (_gstEnabled && _gstin.text.trim().isEmpty) {
      _toast(
        context,
        'Provider GSTIN is required while GST is enabled.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await repository.saveBillingSettings(
        PlatformBillingSettings(
          providerCompanyName: _provider.text.trim(),
          productName: _product.text.trim(),
          providerGstin: _nullable(_gstin.text)?.toUpperCase(),
          providerAddress: _nullable(_address.text),
          contactEmail: _email.text.trim(),
          contactPhone: _nullable(_phone.text),
          website: _website.text.trim(),
          gstEnabled: _gstEnabled,
          gstMode: _gstMode,
          gstPercent: _gstMode == 'igst' ? igst : cgst + sgst,
          cgstPercent: _gstMode == 'cgst_sgst' ? cgst : 0,
          sgstPercent: _gstMode == 'cgst_sgst' ? sgst : 0,
          igstPercent: _gstMode == 'igst' ? igst : 0,
          sealUrl: _sealUrl,
        ),
      );
      if (!mounted) return;
      _apply(saved);
      _toast(context, 'Platform billing settings saved.');
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAccount() async {
    if (_accountSaving) return;
    final email = _newAccountEmail.text.trim();
    final currentPassword = _currentAccountPassword.text;
    final newPassword = _newAccountPassword.text;
    if (!email.contains('@') || !email.contains('.')) {
      _toast(context, 'Enter a valid Superadmin email address.', error: true);
      return;
    }
    if (currentPassword.isEmpty) {
      _toast(
        context,
        'Enter your current password to authorize this change.',
        error: true,
      );
      return;
    }
    if (newPassword.isNotEmpty && newPassword != _confirmAccountPassword.text) {
      _toast(
        context,
        'The new password confirmation does not match.',
        error: true,
      );
      return;
    }
    if (newPassword.isNotEmpty && newPassword.length < 10) {
      _toast(
        context,
        'The new password must be at least 10 characters.',
        error: true,
      );
      return;
    }
    setState(() => _accountSaving = true);
    try {
      final savedEmail = await repository.updateSuperadminAccount(
        email: email,
        currentPassword: currentPassword,
        newPassword: newPassword.isEmpty ? null : newPassword,
      );
      if (!mounted) return;
      _accountEmail.text = savedEmail;
      _newAccountEmail.text = savedEmail;
      _currentAccountPassword.clear();
      _newAccountPassword.clear();
      _confirmAccountPassword.clear();
      _toast(context, 'Superadmin account updated.');
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _accountSaving = false);
    }
  }

  Future<void> _uploadSeal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        _toast(context, 'Unable to read selected file.', error: true);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await repository.uploadBillingSeal(
        filename: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      _apply(saved);
      _toast(context, 'Authorised seal uploaded.');
    } catch (error) {
      if (mounted) _toast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_ErrorState(error: _error, onRetry: _load)],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const _SectionHeader(
          eyebrow: 'SUPERADMIN SECURITY',
          title: 'Account access',
          subtitle:
              'Change the sign-in email or password for your Superadmin account.',
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _accountEmail,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Current sign-in email',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newAccountEmail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'New sign-in email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentAccountPassword,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Current password (required)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newAccountPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password (optional)',
                    helperText: 'Leave blank to keep the current password.',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmAccountPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _accountSaving ? null : _saveAccount,
                    icon: _accountSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.security_outlined),
                    label: const Text('Update Superadmin account'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your current password is checked before saving. This sign-in email is separate from the provider contact email below.',
                  style: TextStyle(color: VistoraColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          eyebrow: 'PLATFORM BILLING',
          title: 'Invoice identity & GST',
          subtitle:
              'These values are snapshotted into every new Vistora tax invoice.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _provider,
          decoration: const InputDecoration(
            labelText: 'Provider company name',
            prefixIcon: Icon(Icons.business_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _product,
          decoration: const InputDecoration(
            labelText: 'Product name',
            prefixIcon: Icon(Icons.auto_awesome_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gstin,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Provider GSTIN',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Provider address',
            prefixIcon: Icon(Icons.location_on_outlined),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Contact email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact phone',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _website,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Website',
            prefixIcon: Icon(Icons.language_outlined),
          ),
        ),
        const SizedBox(height: 15),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  value: _gstEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable GST billing',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'A tenant GSTIN is also required before GST can be charged.',
                  ),
                  onChanged: (value) => setState(() => _gstEnabled = value),
                ),
                if (_gstEnabled) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'cgst_sgst',
                        label: Text('CGST + SGST'),
                      ),
                      ButtonSegment(value: 'igst', label: Text('IGST')),
                    ],
                    selected: {_gstMode},
                    onSelectionChanged: (values) =>
                        setState(() => _gstMode = values.single),
                  ),
                  const SizedBox(height: 14),
                  if (_gstMode == 'cgst_sgst')
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cgst,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'CGST %',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _sgst,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'SGST %',
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    TextField(
                      controller: _igst,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'IGST %'),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: VistoraColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _sealUrl == null
                      ? const Icon(
                          Icons.approval_outlined,
                          color: VistoraColors.muted,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.network(
                            _sealUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: VistoraColors.muted,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authorised seal',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'PNG, JPG or WebP · up to 2 MB',
                        style: TextStyle(color: VistoraColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _uploadSeal,
                  icon: const Icon(Icons.upload_outlined),
                  tooltip: 'Upload seal',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save billing settings'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: VistoraColors.cyan,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: VistoraColors.muted)),
    ],
  );
}

class _TitleAction extends StatelessWidget {
  const _TitleAction({
    required this.title,
    required this.action,
    required this.onTap,
    this.icon = Icons.arrow_forward,
  });
  final String title;
  final String action;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ),
      TextButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(action)),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color.withValues(alpha: 0.28)),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.14), VistoraColors.surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 30,
          ),
        ),
        Text(label, style: const TextStyle(color: VistoraColors.muted)),
      ],
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: VistoraColors.cyan),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(icon, color: color),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.previous,
    required this.next,
  });
  final int page;
  final int lastPage;
  final int total;
  final VoidCallback? previous;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$total record(s) · Page $page of $lastPage',
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
    ),
  );
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.delay, required this.child});
  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 260 + delay.clamp(0, 8) * 45),
    tween: Tween(begin: 0, end: 1),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < 3; index++)
        Container(
          height: 112,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: VistoraColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 42,
            color: VistoraColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VistoraColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: VistoraColors.pink, size: 38),
          const SizedBox(height: 10),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: VistoraColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

Color _statusColor(String status) => switch (status.toLowerCase()) {
  'active' || 'approved' || 'recorded' => VistoraColors.green,
  'pending' => VistoraColors.amber,
  'inactive' || 'rejected' => VistoraColors.pink,
  _ => VistoraColors.cyan,
};

void _toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFF5A182B) : null,
    ),
  );
}

String _humanize(String value) => value
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _rate(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
