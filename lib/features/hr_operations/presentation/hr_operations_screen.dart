import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/hr_operations/data/hr_operations_repository.dart';
import 'package:vistora_mobile/features/hr_operations/domain/hr_operations_models.dart';

final hrOperationsRepositoryProvider = Provider<HrOperationsRepository>(
  (ref) => HrOperationsRepository(ref.watch(apiClientProvider)),
);

class HrOperationsScreen extends StatelessWidget {
  const HrOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HR Operations',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              'Recruit • Offer • Appoint • Settle',
              style: TextStyle(fontSize: 11, color: VistoraColors.muted),
            ),
          ],
        ),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: Icon(Icons.person_search_outlined), text: 'Recruitment'),
            Tab(
              icon: Icon(Icons.mark_email_read_outlined),
              text: 'Offer letters',
            ),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Appointments'),
            Tab(icon: Icon(Icons.handshake_outlined), text: 'F&F'),
          ],
        ),
      ),
      body: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1300D2FF), Colors.transparent, Color(0x10FF2D78)],
          ),
        ),
        child: TabBarView(
          children: [
            _RecruitmentTab(),
            _OffersTab(),
            _AppointmentsTab(),
            _SettlementsTab(),
          ],
        ),
      ),
    ),
  );
}

class _RecruitmentTab extends ConsumerStatefulWidget {
  const _RecruitmentTab();
  @override
  ConsumerState<_RecruitmentTab> createState() => _RecruitmentTabState();
}

class _RecruitmentTabState extends ConsumerState<_RecruitmentTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _status;
  int _page = 1;
  bool _busy = false;
  late Future<HrPage<RecruitmentCandidate>> _future;
  HrOperationsRepository get repository =>
      ref.read(hrOperationsRepositoryProvider);

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

  Future<HrPage<RecruitmentCandidate>> _load() => repository.candidates(
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    status: _status,
    page: _page,
  );
  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _refresh(reset: true);
    });
  }

  Future<void> _mutate(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (mounted) _toast(message);
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFF8B2635) : null,
        ),
      );

  Future<void> _addCandidate() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CandidateEditor(),
    );
    if (result != null && mounted) {
      await _mutate(
        () => repository.createCandidate(result),
        'Candidate added to the recruitment pipeline.',
      );
    }
  }

  Future<void> _schedule(RecruitmentCandidate candidate) async {
    final employees = await repository.employees();
    if (!mounted) return;
    final result = await showModalBottomSheet<_InterviewInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InterviewEditor(
        candidate: candidate,
        employees: employees.where((item) => item.userId != null).toList(),
      ),
    );
    if (result != null && mounted) {
      await _mutate(
        () => repository.scheduleInterview(
          candidateId: candidate.id,
          scheduledAt: result.scheduledAt,
          panelistUserIds: result.panelistUserIds,
          mode: result.mode,
          notes: result.notes,
        ),
        'Interview scheduled and panelists notified.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const _FeatureHero(
          icon: Icons.person_search_outlined,
          title: 'Talent pipeline',
          subtitle:
              'Manage candidates, stage movement and interview schedules from one mobile workspace.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: _changed,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search candidate name or email',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Pipeline stage',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All stages')),
                    DropdownMenuItem(value: 'applied', child: Text('Applied')),
                    DropdownMenuItem(
                      value: 'screening',
                      child: Text('Screening'),
                    ),
                    DropdownMenuItem(
                      value: 'interview',
                      child: Text('Interview'),
                    ),
                    DropdownMenuItem(value: 'hold', child: Text('On hold')),
                    DropdownMenuItem(
                      value: 'selected',
                      child: Text('Selected'),
                    ),
                    DropdownMenuItem(value: 'offered', child: Text('Offered')),
                    DropdownMenuItem(value: 'joined', child: Text('Joined')),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) {
                    _status = value;
                    _refresh(reset: true);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _addCandidate,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add candidate'),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<HrPage<RecruitmentCandidate>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingBlock();
            }
            if (snapshot.hasError) {
              return _ErrorBlock(snapshot.error.toString(), _refresh);
            }
            final result = snapshot.data!;
            if (result.items.isEmpty) {
              return const _EmptyBlock(
                icon: Icons.person_search_outlined,
                title: 'No candidates found',
                message: 'New applicants will appear here.',
              );
            }
            return Column(
              children: [
                for (var index = 0; index < result.items.length; index++)
                  _AnimatedCard(
                    index: index,
                    child: _candidateCard(result.items[index]),
                  ),
                _PageControls(
                  page: result.page,
                  lastPage: result.lastPage,
                  total: result.total,
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
            );
          },
        ),
      ],
    ),
  );

  Widget _candidateCard(RecruitmentCandidate item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: VistoraColors.pink.withValues(alpha: .17),
                child: Text(
                  _initials(item.name),
                  style: const TextStyle(
                    color: VistoraColors.pink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      item.email,
                      style: const TextStyle(color: VistoraColors.muted),
                    ),
                  ],
                ),
              ),
              _Status(item.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.position ?? 'Position not specified',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${item.source ?? 'Direct'} • ${item.phone ?? 'No phone'} • ${item.interviewCount} interview(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (item.status == 'applied')
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _mutate(
                          () => repository.pipelineAction(item.id, 'screening'),
                          'Candidate moved to screening.',
                        ),
                  child: const Text('Accept for screening'),
                ),
              if (const {
                'screening',
                'interview',
                'hold',
              }.contains(item.status))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _schedule(item),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    item.status == 'interview'
                        ? 'Reschedule'
                        : 'Schedule interview',
                  ),
                ),
              if (item.status == 'interview')
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _mutate(
                          () => repository.pipelineAction(item.id, 'selected'),
                          'Candidate selected.',
                        ),
                  child: const Text('Select'),
                ),
              if (!const {'hold', 'joined', 'rejected'}.contains(item.status))
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _mutate(
                          () => repository.pipelineAction(item.id, 'hold'),
                          'Candidate placed on hold.',
                        ),
                  child: const Text('Hold'),
                ),
              if (!const {'joined', 'rejected'}.contains(item.status))
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _mutate(
                          () => repository.pipelineAction(item.id, 'rejected'),
                          'Candidate rejected.',
                        ),
                  child: const Text('Reject'),
                ),
              if (item.status == 'hold')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _mutate(
                          () => repository.pipelineAction(item.id, 'back'),
                          'Candidate returned to screening.',
                        ),
                  child: const Text('Resume pipeline'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OffersTab extends ConsumerStatefulWidget {
  const _OffersTab();
  @override
  ConsumerState<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends ConsumerState<_OffersTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  int? _month;
  int? _year = DateTime.now().year;
  bool _busy = false;
  late Future<HrPage<RecruitmentOffer>> _future;
  HrOperationsRepository get repository =>
      ref.read(hrOperationsRepositoryProvider);
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

  Future<HrPage<RecruitmentOffer>> _load() => repository.offers(
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

  Future<void> _generate() async {
    final values = await Future.wait([
      repository.candidates(perPage: 100),
      repository.offerTemplates(),
    ]);
    if (!mounted) return;
    final result = await showModalBottomSheet<_OfferInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OfferEditor(
        candidates: (values[0] as HrPage<RecruitmentCandidate>).items,
        templates: values[1] as List<LetterTemplate>,
      ),
    );
    if (result == null) return;
    await _action(
      () => repository.generateOffer(
        candidateId: result.candidateId,
        templateId: result.templateId,
        position: result.position,
        startDate: result.startDate,
        ctc: result.ctc,
      ),
      'Tenant-branded offer letter generated.',
    );
  }

  Future<void> _template() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TemplateEditor(type: 'offer'),
    );
    if (result != null) {
      await _action(
        () => repository.saveOfferTemplate(
          name: result['name']!,
          bodyHtml: result['body']!,
        ),
        'Offer template saved.',
      );
    }
  }

  Future<void> _action(Future<void> Function() fn, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      await _refresh();
      if (mounted) _snack(context, message);
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const _FeatureHero(
          icon: Icons.mark_email_read_outlined,
          title: 'Offer-letter studio',
          subtitle:
              'Generate persistent, tenant-branded offers from controlled templates.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 320), () {
                      if (mounted) _refresh(reset: true);
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search candidate, email or position',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _monthDropdown(_month, (value) {
                        _month = value;
                        _refresh(reset: true);
                      }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _yearDropdown(_year, (value) {
                        _year = value;
                        _refresh(reset: true);
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate offer'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _template,
              icon: const Icon(Icons.edit_note),
              label: const Text('New template'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<HrPage<RecruitmentOffer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingBlock();
            }
            if (snapshot.hasError) {
              return _ErrorBlock(snapshot.error.toString(), _refresh);
            }
            final result = snapshot.data!;
            if (result.items.isEmpty) {
              return const _EmptyBlock(
                icon: Icons.drafts_outlined,
                title: 'No offers generated',
                message:
                    'Select a candidate and template to generate the first offer.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < result.items.length; i++)
                  _AnimatedCard(index: i, child: _offerCard(result.items[i])),
                _PageControls(
                  page: result.page,
                  lastPage: result.lastPage,
                  total: result.total,
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
            );
          },
        ),
      ],
    ),
  );
  Widget _offerCard(RecruitmentOffer item) => Card(
    child: InkWell(
      onTap: () => _showDocument(
        context,
        'Offer letter • ${item.candidateName}',
        item.renderedHtml,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.mail_outline)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.candidateName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        item.candidateEmail,
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                    ],
                  ),
                ),
                _Status(item.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.position,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Starts ${DateFormat.yMMMd().format(item.startDate)} • ${item.templateName ?? 'Template'}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _money(item.offeredCtc),
                  style: const TextStyle(
                    color: VistoraColors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (status) => _action(
                    () => repository.updateOfferStatus(item.id, status),
                    'Offer marked $status.',
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'sent', child: Text('Mark sent')),
                    PopupMenuItem(
                      value: 'accepted',
                      child: Text('Mark accepted'),
                    ),
                    PopupMenuItem(
                      value: 'declined',
                      child: Text('Mark declined'),
                    ),
                    PopupMenuItem(
                      value: 'revoked',
                      child: Text('Revoke offer'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AppointmentsTab extends ConsumerStatefulWidget {
  const _AppointmentsTab();
  @override
  ConsumerState<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<_AppointmentsTab> {
  int _page = 1;
  bool _busy = false;
  late Future<HrPage<EmployeeLetter>> _future;
  HrOperationsRepository get repository =>
      ref.read(hrOperationsRepositoryProvider);
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HrPage<EmployeeLetter>> _load() =>
      repository.appointmentLetters(page: _page);
  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _generate() async {
    final values = await Future.wait([
      repository.employees(),
      repository.appointmentTemplates(),
    ]);
    if (!mounted) return;
    final input = await showModalBottomSheet<_AppointmentInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AppointmentEditor(
        employees: values[0] as List<HrEmployee>,
        templates: values[1] as List<LetterTemplate>,
      ),
    );
    if (input == null) return;
    setState(() => _busy = true);
    try {
      await repository.generateAppointment(
        employeeId: input.employeeId,
        templateId: input.templateId,
        designation: input.designation,
        joiningDate: input.joiningDate,
        place: input.place,
      );
      await _refresh();
      if (mounted) _snack(context, 'Appointment letter generated.');
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const _FeatureHero(
          icon: Icons.badge_outlined,
          title: 'Appointment letters',
          subtitle:
              'Generate company-branded appointment documents from employee and salary records.',
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: const Icon(Icons.add),
            label: const Text('Generate appointment'),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<HrPage<EmployeeLetter>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingBlock();
            }
            if (snapshot.hasError) {
              return _ErrorBlock(snapshot.error.toString(), _refresh);
            }
            final result = snapshot.data!;
            if (result.items.isEmpty) {
              return const _EmptyBlock(
                icon: Icons.badge_outlined,
                title: 'No appointment letters',
                message:
                    'Generated employee appointment letters will appear here.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < result.items.length; i++)
                  _AnimatedCard(
                    index: i,
                    child: Card(
                      child: ListTile(
                        onTap: () => _showDocument(
                          context,
                          'Appointment • ${result.items[i].employeeName}',
                          result.items[i].renderedHtml,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.description_outlined),
                        ),
                        title: Text(
                          result.items[i].employeeName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${result.items[i].employeeCode} • ${result.items[i].templateName ?? 'Template'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                _PageControls(
                  page: result.page,
                  lastPage: result.lastPage,
                  total: result.total,
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
            );
          },
        ),
      ],
    ),
  );
}

class _SettlementsTab extends ConsumerStatefulWidget {
  const _SettlementsTab();
  @override
  ConsumerState<_SettlementsTab> createState() => _SettlementsTabState();
}

class _SettlementsTabState extends ConsumerState<_SettlementsTab> {
  int _page = 1;
  bool _busy = false;
  late Future<HrPage<FinalSettlementItem>> _future;
  HrOperationsRepository get repository =>
      ref.read(hrOperationsRepositoryProvider);
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HrPage<FinalSettlementItem>> _load() =>
      repository.settlements(page: _page);
  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _create() async {
    final employees = await repository.employees();
    if (!mounted) return;
    final base = await showModalBottomSheet<_SettlementDates>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SettlementDateEditor(employees: employees),
    );
    if (base == null) return;
    setState(() => _busy = true);
    try {
      final calculation = await repository.calculateSettlement(
        employeeId: base.employeeId,
        resignationDate: base.resignationDate,
        lastWorkingDate: base.lastWorkingDate,
      );
      if (!mounted) return;
      final values = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) =>
            _SettlementAmounts(calculation: calculation, dates: base),
      );
      if (values != null) {
        await repository.saveSettlement(
          employeeId: base.employeeId,
          data: values,
        );
        await _refresh();
        if (mounted) _snack(context, 'Full and final settlement saved.');
      }
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(Future<void> Function() fn, String text) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      await _refresh();
      if (mounted) _snack(context, text);
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const _FeatureHero(
          icon: Icons.handshake_outlined,
          title: 'Full & final settlements',
          subtitle:
              'Calculate, review, approve, revoke and disburse final employee settlements.',
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calculate settlement'),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<HrPage<FinalSettlementItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingBlock();
            }
            if (snapshot.hasError) {
              return _ErrorBlock(snapshot.error.toString(), _refresh);
            }
            final result = snapshot.data!;
            if (result.items.isEmpty) {
              return const _EmptyBlock(
                icon: Icons.handshake_outlined,
                title: 'No settlements',
                message:
                    'Calculated full and final settlements will appear here.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < result.items.length; i++)
                  _AnimatedCard(
                    index: i,
                    child: _settlementCard(result.items[i]),
                  ),
                _PageControls(
                  page: result.page,
                  lastPage: result.lastPage,
                  total: result.total,
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
            );
          },
        ),
      ],
    ),
  );
  Widget _settlementCard(FinalSettlementItem item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(_initials(item.employeeName))),
              const SizedBox(width: 10),
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
                    Text(item.employeeCode),
                  ],
                ),
              ),
              _Status(item.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Last working day • ${DateFormat.yMMMd().format(item.lastWorkingDate)}',
          ),
          const SizedBox(height: 6),
          Text(
            _money(item.netSettlement),
            style: const TextStyle(
              color: VistoraColors.green,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          Text(
            'Salary ${_money(item.salaryDue)} + Leave ${_money(item.leaveEncashment)} + Gratuity ${_money(item.gratuity)} + Bonus ${_money(item.bonus)} − Deductions ${_money(item.deductions)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (item.status == 'draft')
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => repository.updateSettlementStatus(
                            item.id,
                            'reviewed',
                          ),
                          'Settlement marked reviewed.',
                        ),
                  child: const Text('Mark reviewed'),
                ),
              if (item.status == 'reviewed')
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => repository.updateSettlementStatus(
                            item.id,
                            'approved',
                          ),
                          'Settlement approved.',
                        ),
                  child: const Text('Approve'),
                ),
              if (const {'reviewed', 'approved'}.contains(item.status))
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => repository.disburseSettlements([item.id]),
                          'Settlement disbursed and slip generated.',
                        ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Disburse'),
                ),
              if (!const {'paid', 'cancelled'}.contains(item.status))
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => repository.revokeSettlement(item.id),
                          'Settlement revoked.',
                        ),
                  child: const Text('Revoke'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CandidateEditor extends StatefulWidget {
  const _CandidateEditor();
  @override
  State<_CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<_CandidateEditor> {
  final _form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      position = TextEditingController(),
      source = TextEditingController();
  @override
  void dispose() {
    for (final c in [first, last, email, phone, position, source]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Add candidate',
    formKey: _form,
    children: [
      _required(first, 'First name'),
      TextFormField(
        controller: last,
        decoration: const InputDecoration(labelText: 'Last name'),
      ),
      _required(email, 'Email', email: true),
      TextFormField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone'),
      ),
      TextFormField(
        controller: position,
        decoration: const InputDecoration(labelText: 'Position'),
      ),
      TextFormField(
        controller: source,
        decoration: const InputDecoration(labelText: 'Source'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, {
            'first_name': first.text.trim(),
            'last_name': last.text.trim(),
            'email': email.text.trim(),
            'phone': phone.text.trim(),
            'position': position.text.trim(),
            'source': source.text.trim(),
          });
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add candidate'),
      ),
    ],
  );
}

class _InterviewInput {
  const _InterviewInput(
    this.scheduledAt,
    this.panelistUserIds,
    this.mode,
    this.notes,
  );
  final DateTime scheduledAt;
  final List<int> panelistUserIds;
  final String mode;
  final String notes;
}

class _InterviewEditor extends StatefulWidget {
  const _InterviewEditor({required this.candidate, required this.employees});
  final RecruitmentCandidate candidate;
  final List<HrEmployee> employees;
  @override
  State<_InterviewEditor> createState() => _InterviewEditorState();
}

class _InterviewEditorState extends State<_InterviewEditor> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);
  String mode = 'in_person';
  final selected = <int>{};
  final notes = TextEditingController();
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Schedule • ${widget.candidate.name}',
    children: [
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 730)),
          );
          if (value != null) setState(() => date = value);
        },
        icon: const Icon(Icons.calendar_month),
        label: Text(DateFormat.yMMMd().format(date)),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (value != null) setState(() => time = value);
        },
        icon: const Icon(Icons.schedule),
        label: Text(time.format(context)),
      ),
      DropdownButtonFormField<String>(
        value: mode,
        decoration: const InputDecoration(labelText: 'Mode'),
        items: const [
          DropdownMenuItem(value: 'in_person', child: Text('In person')),
          DropdownMenuItem(value: 'virtual', child: Text('Virtual')),
          DropdownMenuItem(value: 'phone', child: Text('Phone')),
        ],
        onChanged: (value) => setState(() => mode = value ?? mode),
      ),
      const Text('Panelists', style: TextStyle(fontWeight: FontWeight.w900)),
      for (final employee in widget.employees)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: selected.contains(employee.userId),
          title: Text('${employee.name} (${employee.code})'),
          onChanged: (checked) => setState(
            () => checked == true
                ? selected.add(employee.userId!)
                : selected.remove(employee.userId),
          ),
        ),
      TextField(
        controller: notes,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Notes'),
      ),
      FilledButton.icon(
        onPressed: selected.isEmpty
            ? null
            : () {
                final scheduled = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                Navigator.pop(
                  context,
                  _InterviewInput(
                    scheduled,
                    selected.toList(),
                    mode,
                    notes.text,
                  ),
                );
              },
        icon: const Icon(Icons.event_available),
        label: const Text('Schedule & notify'),
      ),
    ],
  );
}

class _OfferInput {
  const _OfferInput(
    this.candidateId,
    this.templateId,
    this.position,
    this.startDate,
    this.ctc,
  );
  final int candidateId, templateId;
  final String position;
  final DateTime startDate;
  final double ctc;
}

class _OfferEditor extends StatefulWidget {
  const _OfferEditor({required this.candidates, required this.templates});
  final List<RecruitmentCandidate> candidates;
  final List<LetterTemplate> templates;
  @override
  State<_OfferEditor> createState() => _OfferEditorState();
}

class _OfferEditorState extends State<_OfferEditor> {
  int? candidateId, templateId;
  DateTime start = DateTime.now().add(const Duration(days: 14));
  final position = TextEditingController(), ctc = TextEditingController();
  @override
  void dispose() {
    position.dispose();
    ctc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Generate offer letter',
    children: [
      DropdownButtonFormField<int>(
        value: candidateId,
        decoration: const InputDecoration(labelText: 'Candidate *'),
        items: [
          for (final c in widget.candidates)
            DropdownMenuItem(value: c.id, child: Text(c.name)),
        ],
        onChanged: (value) {
          final candidate = widget.candidates
              .where((c) => c.id == value)
              .firstOrNull;
          setState(() {
            candidateId = value;
            position.text = candidate?.position ?? '';
          });
        },
      ),
      DropdownButtonFormField<int>(
        value: templateId,
        decoration: const InputDecoration(labelText: 'Template *'),
        items: [
          for (final t in widget.templates.where((t) => t.status == 'active'))
            DropdownMenuItem(value: t.id, child: Text(t.name)),
        ],
        onChanged: (value) => setState(() => templateId = value),
      ),
      _required(position, 'Position', onChanged: (_) => setState(() {})),
      TextField(
        controller: ctc,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Annual CTC *'),
        onChanged: (_) => setState(() {}),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDatePicker(
            context: context,
            initialDate: start,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 730)),
          );
          if (value != null) setState(() => start = value);
        },
        icon: const Icon(Icons.calendar_month),
        label: Text('Joining ${DateFormat.yMMMd().format(start)}'),
      ),
      FilledButton.icon(
        onPressed:
            candidateId == null ||
                templateId == null ||
                position.text.trim().isEmpty ||
                double.tryParse(ctc.text) == null
            ? null
            : () => Navigator.pop(
                context,
                _OfferInput(
                  candidateId!,
                  templateId!,
                  position.text.trim(),
                  start,
                  double.parse(ctc.text),
                ),
              ),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate offer'),
      ),
    ],
  );
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.type});
  final String type;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  final name = TextEditingController(), body = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'New ${widget.type} template',
    children: [
      _required(name, 'Template name', onChanged: (_) => setState(() {})),
      TextField(
        controller: body,
        minLines: 9,
        maxLines: 18,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Letter body *',
          helperText:
              'Merge fields: [CAND_NAME], [POSITION], [START_DATE], [CTC_ANNUAL], [COMPANY_NAME], [DATE]',
        ),
      ),
      FilledButton(
        onPressed: name.text.trim().isEmpty || body.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, {
                'name': name.text.trim(),
                'body': body.text.trim(),
              }),
        child: const Text('Save template'),
      ),
    ],
  );
}

class _AppointmentInput {
  const _AppointmentInput(
    this.employeeId,
    this.templateId,
    this.designation,
    this.joiningDate,
    this.place,
  );
  final int employeeId, templateId;
  final String designation, place;
  final DateTime? joiningDate;
}

class _AppointmentEditor extends StatefulWidget {
  const _AppointmentEditor({required this.employees, required this.templates});
  final List<HrEmployee> employees;
  final List<LetterTemplate> templates;
  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  int? employeeId, templateId;
  DateTime? date;
  final designation = TextEditingController(), place = TextEditingController();
  @override
  void dispose() {
    designation.dispose();
    place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Generate appointment letter',
    children: [
      DropdownButtonFormField<int>(
        value: employeeId,
        decoration: const InputDecoration(labelText: 'Employee *'),
        items: [
          for (final e in widget.employees)
            DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.code})')),
        ],
        onChanged: (value) {
          final employee = widget.employees
              .where((e) => e.id == value)
              .firstOrNull;
          setState(() {
            employeeId = value;
            designation.text = employee?.designation ?? '';
            date = employee?.joiningDate;
          });
        },
      ),
      DropdownButtonFormField<int>(
        value: templateId,
        decoration: const InputDecoration(labelText: 'Template *'),
        items: [
          for (final t in widget.templates.where((t) => t.status == 'active'))
            DropdownMenuItem(value: t.id, child: Text(t.name)),
        ],
        onChanged: (value) => setState(() => templateId = value),
      ),
      TextField(
        controller: designation,
        decoration: const InputDecoration(labelText: 'Designation'),
      ),
      TextField(
        controller: place,
        decoration: const InputDecoration(labelText: 'Place'),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 730)),
          );
          if (value != null) setState(() => date = value);
        },
        icon: const Icon(Icons.calendar_month),
        label: Text(
          date == null
              ? 'Select joining date'
              : DateFormat.yMMMd().format(date!),
        ),
      ),
      FilledButton.icon(
        onPressed: employeeId == null || templateId == null
            ? null
            : () => Navigator.pop(
                context,
                _AppointmentInput(
                  employeeId!,
                  templateId!,
                  designation.text,
                  date,
                  place.text,
                ),
              ),
        icon: const Icon(Icons.description_outlined),
        label: const Text('Generate appointment'),
      ),
    ],
  );
}

class _SettlementDates {
  const _SettlementDates(
    this.employeeId,
    this.resignationDate,
    this.lastWorkingDate,
  );
  final int employeeId;
  final DateTime resignationDate, lastWorkingDate;
}

class _SettlementDateEditor extends StatefulWidget {
  const _SettlementDateEditor({required this.employees});
  final List<HrEmployee> employees;
  @override
  State<_SettlementDateEditor> createState() => _SettlementDateEditorState();
}

class _SettlementDateEditorState extends State<_SettlementDateEditor> {
  int? employeeId;
  DateTime resignation = DateTime.now(), last = DateTime.now();
  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Calculate final settlement',
    children: [
      DropdownButtonFormField<int>(
        value: employeeId,
        decoration: const InputDecoration(labelText: 'Employee *'),
        items: [
          for (final e in widget.employees)
            DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.code})')),
        ],
        onChanged: (value) => setState(() => employeeId = value),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDatePicker(
            context: context,
            initialDate: resignation,
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (value != null) {
            setState(() {
              resignation = value;
              if (last.isBefore(resignation)) last = resignation;
            });
          }
        },
        icon: const Icon(Icons.event_note),
        label: Text('Resignation ${DateFormat.yMMMd().format(resignation)}'),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await showDatePicker(
            context: context,
            initialDate: last.isBefore(resignation) ? resignation : last,
            firstDate: resignation,
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (value != null) setState(() => last = value);
        },
        icon: const Icon(Icons.event_busy),
        label: Text('Last working ${DateFormat.yMMMd().format(last)}'),
      ),
      FilledButton.icon(
        onPressed: employeeId == null
            ? null
            : () => Navigator.pop(
                context,
                _SettlementDates(employeeId!, resignation, last),
              ),
        icon: const Icon(Icons.calculate),
        label: const Text('Calculate'),
      ),
    ],
  );
}

class _SettlementAmounts extends StatefulWidget {
  const _SettlementAmounts({required this.calculation, required this.dates});
  final Map<String, dynamic> calculation;
  final _SettlementDates dates;
  @override
  State<_SettlementAmounts> createState() => _SettlementAmountsState();
}

class _SettlementAmountsState extends State<_SettlementAmounts> {
  late final Map<String, TextEditingController> fields;
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in const [
        'salary_due',
        'leave_encashment',
        'gratuity',
        'bonus',
        'deductions',
      ])
        key: TextEditingController(
          text: (widget.calculation[key] ?? 0).toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormSheet(
    title: 'Review calculated settlement',
    children: [
      for (final entry in fields.entries)
        TextField(
          controller: entry.value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: _label(entry.key)),
        ),
      TextField(
        controller: notes,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Notes'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, {
          'resignation_date': _date(widget.dates.resignationDate),
          'last_working_date': _date(widget.dates.lastWorkingDate),
          for (final entry in fields.entries)
            entry.key: double.tryParse(entry.value.text) ?? 0,
          'notes': notes.text.trim(),
        }),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save settlement'),
      ),
    ],
  );
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.children, this.formKey});
  final String title;
  final List<Widget> children;
  final GlobalKey<FormState>? formKey;
  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .45,
        maxChildSize: .98,
        builder: (context, controller) => formKey == null
            ? PrimaryScrollController(controller: controller, child: content)
            : Form(
                key: formKey,
                child: PrimaryScrollController(
                  controller: controller,
                  child: content,
                ),
              ),
      ),
    );
  }
}

class _FeatureHero extends StatelessWidget {
  const _FeatureHero({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF44231D), Color(0xFF0B2940)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: VistoraColors.orange.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: VistoraColors.orange.withValues(alpha: .16),
          child: Icon(icon, color: VistoraColors.orange),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AnimatedCard extends StatelessWidget {
  const _AnimatedCard({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 240 + index.clamp(0, 6) * 45),
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Transform.translate(
      offset: Offset(0, 14 * (1 - value)),
      child: Opacity(opacity: value, child: child),
    ),
    child: Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
  );
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Text(
        value.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.lastPage,
    required this.total,
    this.previous,
    this.next,
  });
  final int page, lastPage, total;
  final VoidCallback? previous, next;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text('$total records • Page $page of $lastPage')),
      IconButton(onPressed: previous, icon: const Icon(Icons.chevron_left)),
      IconButton(onPressed: next, icon: const Icon(Icons.chevron_right)),
    ],
  );
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(50),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(icon, size: 44, color: VistoraColors.muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock(this.error, this.retry);
  final String error;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

Widget _required(
  TextEditingController controller,
  String label, {
  bool email = false,
  ValueChanged<String>? onChanged,
}) => TextFormField(
  controller: controller,
  keyboardType: email ? TextInputType.emailAddress : null,
  decoration: InputDecoration(labelText: '$label *'),
  onChanged: onChanged,
  validator: (value) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    if (email && !value.contains('@')) return 'Enter a valid email.';
    return null;
  },
);
Widget _monthDropdown(int? value, ValueChanged<int?> changed) =>
    DropdownButtonFormField<int?>(
      value: value,
      decoration: const InputDecoration(labelText: 'Month'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All months')),
        for (var m = 1; m <= 12; m++)
          DropdownMenuItem(
            value: m,
            child: Text(DateFormat.MMMM().format(DateTime(2026, m))),
          ),
      ],
      onChanged: changed,
    );
Widget _yearDropdown(int? value, ValueChanged<int?> changed) =>
    DropdownButtonFormField<int?>(
      value: value,
      decoration: const InputDecoration(labelText: 'Year'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All years')),
        for (var y = DateTime.now().year; y >= DateTime.now().year - 5; y--)
          DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: changed,
    );
void _showDocument(BuildContext context, String title, String html) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        minChildSize: .5,
        maxChildSize: .98,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Divider(height: 28),
            SelectableText(
              _stripHtml(html),
              style: const TextStyle(height: 1.65),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
String _stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(
      RegExp(r'</p>|</div>|</h[1-6]>|</li>|</tr>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#039;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
Color _statusColor(String value) => switch (value) {
  'approved' || 'accepted' || 'joined' || 'paid' => VistoraColors.green,
  'submitted' ||
  'reviewed' ||
  'sent' ||
  'offered' ||
  'interview' => VistoraColors.orange,
  'rejected' ||
  'declined' ||
  'cancelled' ||
  'revoked' => const Color(0xFFFF6B7A),
  _ => VistoraColors.cyan,
};
String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
