import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/platform_admin/data/platform_repository.dart';
import 'package:vistora_mobile/features/platform_admin/domain/platform_models.dart';

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
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
  }

  @override
  void didUpdateWidget(covariant PlatformAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _index = widget.initialIndex.clamp(0, 3);
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
    final corp = TextEditingController();
    final company = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.apartment_outlined),
        title: const Text('Create company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: corp,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Corporate ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: company,
              decoration: const InputDecoration(labelText: 'Company name'),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final corpId = corp.text.trim();
    final companyName = company.text.trim();
    corp.dispose();
    company.dispose();
    if (accepted == true && corpId.isNotEmpty && companyName.isNotEmpty) {
      await _action(
        () => repository.createTenant(corpId: corpId, companyName: companyName),
        '$companyName created.',
      );
    }
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
              initialValue: _status,
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

  Future<void> _record() async {
    final tenants = await repository.tenants(perPage: 100);
    if (!mounted || tenants.items.isEmpty) return;
    var corpId = tenants.items.first.corpId;
    var period = 'monthly';
    var gst = true;
    var date = DateTime.now();
    final amount = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.payments_outlined),
          title: const Text('Record subscription payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: corpId,
                  decoration: const InputDecoration(labelText: 'Company'),
                  items: tenants.items
                      .map(
                        (tenant) => DropdownMenuItem(
                          value: tenant.corpId,
                          child: Text(
                            '${tenant.companyName} · ${tenant.corpId}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => corpId = value ?? corpId,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Base amount'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                      value: 'quarterly',
                      child: Text('Quarterly'),
                    ),
                    DropdownMenuItem(
                      value: 'half-yearly',
                      child: Text('Half-yearly'),
                    ),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) => period = value ?? period,
                ),
                SwitchListTile.adaptive(
                  value: gst,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include GST at 18%'),
                  onChanged: (value) => setDialogState(() => gst = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Payment date'),
                  subtitle: Text(DateFormat.yMMMd().format(date)),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: date,
                    );
                    if (selected != null) {
                      setDialogState(() => date = selected);
                    }
                  },
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
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    final value = double.tryParse(amount.text.trim());
    amount.dispose();
    if (accepted != true || value == null || value <= 0) return;
    setState(() => _busy = true);
    try {
      await repository.recordPayment(
        corpId: corpId,
        amount: value,
        periodType: period,
        paymentDate: date,
        gstEnabled: gst,
      );
      await _refresh(reset: true);
      if (mounted) _toast(context, 'Payment and tax invoice recorded.');
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
              title: 'Subscription payments',
              action: 'Record',
              icon: Icons.add_card_outlined,
              onTap: _busy ? null : _record,
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
                    initialValue: _month,
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
                    initialValue: _year,
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
                  child: _PaymentCard(payment: entry.value),
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
            const SizedBox(height: 14),
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

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.busy,
    required this.onToggleStatus,
    required this.onFeature,
  });

  final PlatformTenant tenant;
  final bool busy;
  final VoidCallback onToggleStatus;
  final void Function(String field, bool enabled) onFeature;

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
            ],
          ),
        ],
      ),
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final PlatformPayment payment;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
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
                    payment.corpId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${payment.periodType.replaceAll('-', ' ')} · '
                    '${payment.paymentDate == null ? 'Date unavailable' : DateFormat.yMMMd().format(payment.paymentDate!)}',
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
                ],
              ),
            ),
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
      ),
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
