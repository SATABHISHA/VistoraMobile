import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/mr/data/mr_repository.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_forms.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_expense_claims_view.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_providers.dart';

enum _MrSection {
  myVisits,
  myReports,
  myExpenses,
  doctors,
  locations,
  assignments,
  teamReports,
  expenseApprovals,
  settings,
  audit,
}

extension on _MrSection {
  String get title => switch (this) {
    _MrSection.myVisits => 'My visits',
    _MrSection.myReports => 'My reports',
    _MrSection.myExpenses => 'My expenses',
    _MrSection.doctors => 'Doctors',
    _MrSection.locations => 'Locations',
    _MrSection.assignments => 'Assignments',
    _MrSection.teamReports => 'Visit reports',
    _MrSection.expenseApprovals => 'Expense approvals',
    _MrSection.settings => 'Settings',
    _MrSection.audit => 'Audit log',
  };

  IconData get icon => switch (this) {
    _MrSection.myVisits => Icons.event_available_outlined,
    _MrSection.myReports => Icons.description_outlined,
    _MrSection.myExpenses => Icons.receipt_long_outlined,
    _MrSection.doctors => Icons.medical_services_outlined,
    _MrSection.locations => Icons.location_on_outlined,
    _MrSection.assignments => Icons.assignment_outlined,
    _MrSection.teamReports => Icons.fact_check_outlined,
    _MrSection.expenseApprovals => Icons.price_check_outlined,
    _MrSection.settings => Icons.tune,
    _MrSection.audit => Icons.history,
  };
}

class MrScreen extends ConsumerWidget {
  const MrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session!;
    final role = session.user.normalizedRole;
    final selfService = const {'employee', 'supervisor'}.contains(role);
    final manager = const {
      'admin',
      'hr',
      'supervisor',
      'superadmin',
    }.contains(role);
    final sections = <_MrSection>[
      if (selfService) _MrSection.myVisits,
      if (selfService) _MrSection.myReports,
      if (selfService) _MrSection.myExpenses,
      if (manager) _MrSection.doctors,
      if (manager) _MrSection.locations,
      if (manager) _MrSection.assignments,
      if (manager) _MrSection.teamReports,
      if (manager) _MrSection.expenseApprovals,
      if (manager) _MrSection.settings,
      if (manager) _MrSection.audit,
    ];

    return DefaultTabController(
      length: sections.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to dashboard',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medical Representative',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '${session.companyName ?? 'Company'} • ${session.user.roleType}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: VistoraColors.muted),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final section in sections)
                Tab(icon: Icon(section.icon, size: 19), text: section.title),
            ],
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x1300D2FF),
                Colors.transparent,
                Color(0x10FF2D78),
              ],
            ),
          ),
          child: TabBarView(
            children: [
              for (final section in sections)
                if (section == _MrSection.settings)
                  const _SettingsView()
                else if (section == _MrSection.myExpenses)
                  const MrExpenseClaimsView(mine: true)
                else if (section == _MrSection.expenseApprovals)
                  const MrExpenseClaimsView(reviewable: true)
                else
                  _RecordsView(section: section, role: role),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsView extends ConsumerStatefulWidget {
  const _RecordsView({required this.section, required this.role});
  final _MrSection section;
  final String role;

  @override
  ConsumerState<_RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends ConsumerState<_RecordsView> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _status;
  DateTime? _date;
  int? _year;
  int _page = 1;
  int _perPage = 10;
  bool _mutating = false;
  late Future<MrPage<Object>> _future;

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

  Future<MrPage<Object>> _load() async {
    final query = _search.text.trim().isEmpty ? null : _search.text.trim();
    final date = _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!);
    return switch (widget.section) {
      _MrSection.myVisits => _objects(
        await _repository.assignments(
          query: query,
          status: _status,
          visitDate: date,
          year: _year,
          mine: true,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.myReports => _objects(
        await _repository.reports(
          query: query,
          status: _status,
          visitedDate: date,
          year: _year,
          mine: true,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.myExpenses || _MrSection.expenseApprovals => throw StateError(
        'Expense claims use their own view.',
      ),
      _MrSection.doctors => _objects(
        await _repository.doctors(
          query: query,
          status: _status,
          date: date,
          year: _year,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.locations => _objects(
        await _repository.locations(
          query: query,
          status: _status,
          date: date,
          year: _year,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.assignments => _objects(
        await _repository.assignments(
          query: query,
          status: _status,
          visitDate: date,
          year: _year,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.teamReports => _objects(
        await _repository.reports(
          query: query,
          status: _status,
          visitedDate: date,
          year: _year,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.audit => _objects(
        await _repository.auditLogs(
          query: query,
          date: date,
          year: _year,
          page: _page,
          perPage: _perPage,
        ),
      ),
      _MrSection.settings => throw StateError('Settings uses its own view.'),
    };
  }

  MrPage<Object> _objects<T>(MrPage<T> page) => MrPage<Object>(
    items: page.items.cast<Object>(),
    currentPage: page.currentPage,
    lastPage: page.lastPage,
    total: page.total,
  );

  Future<void> _refresh({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refresh(resetPage: true);
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
      _refresh(resetPage: true);
    }
  }

  bool get _canAdd => const {
    _MrSection.doctors,
    _MrSection.locations,
    _MrSection.assignments,
  }.contains(widget.section);

  List<String> get _statuses => switch (widget.section) {
    _MrSection.doctors || _MrSection.locations => const ['active', 'inactive'],
    _MrSection.myVisits ||
    _MrSection.assignments => const ['planned', 'completed', 'cancelled'],
    _MrSection.myReports || _MrSection.teamReports => const [
      'draft',
      'submitted',
      'approved',
      'rejected',
    ],
    _ => const [],
  };

  String get _searchHint => switch (widget.section) {
    _MrSection.myVisits => 'Search doctor or location',
    _MrSection.myReports => 'Search doctor',
    _MrSection.doctors => 'Search doctor, specialty or location',
    _MrSection.locations => 'Search address, city or doctor',
    _MrSection.assignments ||
    _MrSection.teamReports => 'Search employee ID, employee or doctor',
    _MrSection.audit => 'Search action, employee or actor',
    _ => 'Search',
  };

  Future<void> _add() async {
    var changed = false;
    if (widget.section == _MrSection.doctors) {
      changed = await showMrDoctorEditor(context);
    } else if (widget.section == _MrSection.locations) {
      changed = await showMrLocationEditor(context);
    } else if (widget.section == _MrSection.assignments) {
      changed = await showMrAssignmentEditor(context);
    }
    if (changed && mounted) {
      _success('${widget.section.title} updated.');
      await _refresh(resetPage: true);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _FilterPanel(
          section: widget.section,
          search: _search,
          searchHint: _searchHint,
          status: _status,
          statuses: _statuses,
          date: _date,
          year: _year,
          perPage: _perPage,
          canAdd: _canAdd,
          onSearchChanged: _searchChanged,
          onStatusChanged: (value) {
            setState(() => _status = value);
            _refresh(resetPage: true);
          },
          onDate: _pickDate,
          onClearDate: () {
            setState(() => _date = null);
            _refresh(resetPage: true);
          },
          onYearChanged: (value) {
            setState(() => _year = value);
            _refresh(resetPage: true);
          },
          onPerPageChanged: (value) {
            setState(() => _perPage = value);
            _refresh(resetPage: true);
          },
          onAdd: _add,
        ),
        FutureBuilder<MrPage<Object>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingList();
            }
            if (snapshot.hasError) {
              return _ErrorList(error: snapshot.error!, onRetry: _refresh);
            }
            final result = snapshot.requireData;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Padding(
                key: ValueKey(
                  '${widget.section.name}-${result.currentPage}-${result.total}-${_status ?? 'all'}-${_search.text}',
                ),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                child: Column(
                  children: [
                    if (result.items.isEmpty)
                      _EmptyState(
                        section: widget.section,
                        canAdd: _canAdd,
                        onAdd: _add,
                      )
                    else
                      for (var index = 0; index < result.items.length; index++)
                        _Reveal(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _recordCard(result.items[index]),
                          ),
                        ),
                    _Pager(
                      page: result.currentPage,
                      lastPage: result.lastPage,
                      total: result.total,
                      onPrevious: result.currentPage > 1
                          ? () => _goToPage(result.currentPage - 1)
                          : null,
                      onNext: result.currentPage < result.lastPage
                          ? () => _goToPage(result.currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  Widget _recordCard(Object record) {
    if (record is MrDoctor) return _doctorCard(record);
    if (record is MrLocation) return _locationCard(record);
    if (record is MrAssignment) return _assignmentCard(record);
    if (record is MrVisitReport) return _reportCard(record);
    if (record is MrAuditEvent) return _auditCard(record);
    return const SizedBox.shrink();
  }

  Widget _doctorCard(MrDoctor doctor) => _RecordCard(
    icon: Icons.medical_services_outlined,
    color: VistoraColors.cyan,
    title: doctor.name,
    subtitle: [
      doctor.specialization,
      doctor.phone,
      doctor.email,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
    status: doctor.status,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${doctor.locationCount} mapped location${doctor.locationCount == 1 ? '' : 's'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (doctor.locations.isEmpty)
          const Text(
            'No location mapped',
            style: TextStyle(color: VistoraColors.amber),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: doctor.locations
                .map(
                  (location) => Chip(
                    avatar: Icon(
                      location.hasGeofence
                          ? Icons.gps_fixed
                          : Icons.place_outlined,
                      size: 17,
                    ),
                    label: Text(location.address),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
      ],
    ),
    actions: [
      TextButton.icon(
        onPressed: _mutating ? null : () => _editDoctor(doctor),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      TextButton.icon(
        onPressed: _mutating ? null : () => _deleteDoctor(doctor),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete'),
      ),
    ],
  );

  Widget _locationCard(MrLocation location) => _RecordCard(
    icon: location.hasGeofence ? Icons.gps_fixed : Icons.location_on_outlined,
    color: location.hasGeofence ? VistoraColors.green : VistoraColors.cyan,
    title: location.address,
    subtitle: [
      location.city,
      location.stateName,
      location.branchName,
      location.businessUnitName,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' • '),
    status: location.status,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.hasGeofence
              ? 'Geofence enforced within ${location.radiusMeters} metres'
              : location.hasCoordinates
              ? 'GPS point configured • no radius restriction'
              : 'GPS capture unrestricted',
          style: TextStyle(
            color: location.hasGeofence
                ? VistoraColors.green
                : VistoraColors.muted,
          ),
        ),
        if (location.doctorNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: location.doctorNames
                .map(
                  (name) => Chip(
                    label: Text(name),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
    actions: [
      TextButton.icon(
        onPressed: _mutating ? null : () => _editLocation(location),
        icon: const Icon(Icons.edit_location_alt_outlined),
        label: const Text('Edit'),
      ),
      TextButton.icon(
        onPressed: _mutating ? null : () => _deleteLocation(location),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete'),
      ),
    ],
  );

  Widget _assignmentCard(MrAssignment assignment) {
    final mine = widget.section == _MrSection.myVisits;
    final report = assignment.report;
    return _RecordCard(
      icon: Icons.route_outlined,
      color: _statusColor(assignment.visitingStatus),
      title: assignment.doctorName ?? 'Doctor visit',
      subtitle: mine
          ? DateFormat.yMMMMEEEEd().format(assignment.visitDate)
          : '${assignment.employeeName ?? 'Employee'} (${assignment.employeeCode ?? '—'})',
      status: assignment.status,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine)
            Text(
              DateFormat.yMMMMEEEEd().format(assignment.visitDate),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          const SizedBox(height: 6),
          Text(assignment.locationAddress ?? assignment.location.address),
          if ((assignment.instructions ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              assignment.instructions!,
              style: const TextStyle(color: VistoraColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: assignment.geofenceRequired
                    ? Icons.gps_fixed
                    : Icons.gps_not_fixed,
                text: assignment.geofenceRequired
                    ? '${assignment.location.radiusMeters} m geofence'
                    : 'GPS unrestricted',
                color: assignment.geofenceRequired
                    ? VistoraColors.amber
                    : VistoraColors.cyan,
              ),
              _InfoChip(
                icon: Icons.fact_check_outlined,
                text: _label(assignment.visitingStatus),
                color: _statusColor(assignment.visitingStatus),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _showAssignmentDetails(assignment),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Details'),
        ),
        if (mine &&
            assignment.status == 'planned' &&
            (report == null ||
                const {'draft', 'rejected'}.contains(report.status)))
          FilledButton.tonalIcon(
            onPressed: _mutating ? null : () => _openReport(assignment),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(report == null ? 'Report visit' : 'Continue report'),
          ),
        if (mine && report?.status == 'submitted')
          TextButton.icon(
            onPressed: _mutating ? null : () => _rollbackReport(report!),
            icon: const Icon(Icons.undo),
            label: const Text('Rollback submission'),
          ),
        if (!mine && assignment.canEdit)
          TextButton.icon(
            onPressed: _mutating ? null : () => _editAssignment(assignment),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        if (!mine && assignment.canDelete)
          TextButton.icon(
            onPressed: _mutating ? null : () => _deleteAssignment(assignment),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
      ],
    );
  }

  Widget _reportCard(MrVisitReport report) {
    final canReview = widget.section == _MrSection.teamReports;
    return _RecordCard(
      icon: Icons.fact_check_outlined,
      color: _statusColor(report.status),
      title: report.doctorName ?? 'Visit report',
      subtitle: canReview
          ? '${report.employeeName ?? 'Employee'} (${report.employeeCode ?? '—'})'
          : DateFormat.yMMMd().add_jm().format(
              report.visitedAt?.toLocal() ?? DateTime.now(),
            ),
      status: report.status,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canReview && report.visitedAt != null)
            Text(
              DateFormat.yMMMd().add_jm().format(report.visitedAt!.toLocal()),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          if ((report.locationAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(report.locationAddress!),
          ],
          if ((report.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(report.notes!, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if ((report.outcome ?? '').isNotEmpty)
            Text(
              'Outcome: ${report.outcome}',
              style: const TextStyle(color: VistoraColors.muted),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: report.hasCoordinates
                    ? Icons.my_location
                    : Icons.edit_location_alt_outlined,
                text: report.hasCoordinates
                    ? '${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)}'
                    : 'Manual fallback',
                color: report.hasCoordinates
                    ? VistoraColors.green
                    : VistoraColors.amber,
              ),
              if (report.distanceMeters != null)
                _InfoChip(
                  icon: Icons.social_distance,
                  text:
                      '${report.distanceMeters!.toStringAsFixed(0)} m from location',
                  color: VistoraColors.cyan,
                ),
              _InfoChip(
                icon: Icons.upload_outlined,
                text:
                    '${report.submissionCount} submission${report.submissionCount == 1 ? '' : 's'}',
                color: VistoraColors.muted,
              ),
              if (report.autoConfirmed)
                const _InfoChip(
                  icon: Icons.bolt_rounded,
                  text: 'Auto-confirmed',
                  color: VistoraColors.green,
                ),
            ],
          ),
          if ((report.reviewNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Review: ${report.reviewNotes}',
              style: const TextStyle(color: VistoraColors.amber),
            ),
          ],
          if ((report.rollbackNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Rollback: ${report.rollbackNotes}',
              style: const TextStyle(color: VistoraColors.cyan),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _showReportDetails(report),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Full details'),
        ),
        if (!canReview && report.status == 'submitted')
          TextButton.icon(
            onPressed: _mutating ? null : () => _rollbackReport(report),
            icon: const Icon(Icons.undo),
            label: const Text('Rollback'),
          ),
        if (canReview && report.status == 'submitted') ...[
          FilledButton.tonalIcon(
            onPressed: _mutating ? null : () => _approveReport(report),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve'),
          ),
          TextButton.icon(
            onPressed: _mutating ? null : () => _rejectReport(report),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
          ),
        ],
        if (canReview && const {'approved', 'rejected'}.contains(report.status))
          TextButton.icon(
            onPressed: _mutating ? null : () => _revertReport(report),
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('Revert review'),
          ),
      ],
    );
  }

  Widget _auditCard(MrAuditEvent event) => _RecordCard(
    icon: Icons.history_edu_outlined,
    color: VistoraColors.amber,
    title: _label(event.action.replaceFirst('mr.', '').replaceAll('.', ' ')),
    subtitle: DateFormat.yMMMd().add_jm().format(event.occurredAt.toLocal()),
    status: event.actorRole,
    actions: const [],
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${event.entityType}${event.entityId == null ? '' : ' #${event.entityId}'}',
        ),
        const SizedBox(height: 5),
        Text(
          'By ${event.actorName ?? 'System'}${event.employeeName == null ? '' : ' • ${event.employeeName} (${event.employeeCode ?? '—'})'}',
          style: const TextStyle(color: VistoraColors.muted),
        ),
        if (event.newValues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${event.newValues.length} field change${event.newValues.length == 1 ? '' : 's'} recorded in the tamper-evident audit trail.',
            style: const TextStyle(color: VistoraColors.cyan),
          ),
        ],
      ],
    ),
  );

  Future<void> _editDoctor(MrDoctor doctor) async {
    if (await showMrDoctorEditor(context, doctor: doctor) && mounted) {
      await _refresh();
    }
  }

  Future<void> _editLocation(MrLocation location) async {
    if (await showMrLocationEditor(context, location: location) && mounted) {
      await _refresh();
    }
  }

  Future<void> _editAssignment(MrAssignment assignment) async {
    if (await showMrAssignmentEditor(context, assignment: assignment) &&
        mounted) {
      await _refresh();
    }
  }

  Future<void> _openReport(MrAssignment assignment) async {
    if (await showMrReportEditor(context, assignment: assignment) && mounted) {
      final settings = await ref.read(mrSettingsProvider.future);
      _success(
        settings.autoConfirmVisitReports
            ? 'Visit report submitted and auto-confirmed.'
            : 'Visit report submitted for review.',
      );
      await _refresh();
    }
  }

  Future<void> _deleteDoctor(MrDoctor doctor) async {
    if (!await _confirm(
      'Delete ${doctor.name}?',
      'This is only allowed when the doctor has no assignment or territory history.',
      'Delete',
    )) {
      return;
    }
    await _run(() => _repository.deleteDoctor(doctor.id), 'Doctor deleted.');
  }

  Future<void> _deleteLocation(MrLocation location) async {
    if (!await _confirm('Delete this location?', location.address, 'Delete')) {
      return;
    }
    await _run(
      () => _repository.deleteLocation(location.id),
      'Location deleted.',
    );
  }

  Future<void> _deleteAssignment(MrAssignment assignment) async {
    if (!await _confirm(
      'Delete visit assignment?',
      '${assignment.doctorName ?? 'Doctor'} • ${DateFormat.yMMMd().format(assignment.visitDate)}',
      'Delete',
    )) {
      return;
    }
    await _run(
      () => _repository.deleteAssignment(assignment.id),
      'Assignment deleted.',
    );
  }

  Future<void> _rollbackReport(MrVisitReport report) async {
    final notes = await showMrNotesDialog(
      context,
      title: 'Rollback report submission?',
      label: 'Why are you rolling this back? *',
      actionLabel: 'Rollback',
    );
    if (notes == null) return;
    await _run(
      () => _repository.rollbackSubmission(report.id, notes),
      'Submission rolled back to draft.',
    );
  }

  Future<void> _approveReport(MrVisitReport report) async {
    if (!await _confirm(
      'Approve this visit report?',
      'The visit will be marked approved.',
      'Approve',
    )) {
      return;
    }
    await _run(
      () => _repository.approveReport(report.id),
      'Visit report approved.',
    );
  }

  Future<void> _rejectReport(MrVisitReport report) async {
    final notes = await showMrNotesDialog(
      context,
      title: 'Reject visit report?',
      label: 'Review notes *',
      actionLabel: 'Reject',
    );
    if (notes == null) return;
    await _run(
      () => _repository.rejectReport(report.id, notes),
      'Visit report rejected.',
    );
  }

  Future<void> _revertReport(MrVisitReport report) async {
    if (!await _confirm(
      'Revert this review?',
      'The report returns to submitted and awaits a new decision.',
      'Revert',
    )) {
      return;
    }
    await _run(() => _repository.revertReport(report.id), 'Review reverted.');
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _mutating = true);
    try {
      await action();
      if (!mounted) return;
      _success(message);
      await _refresh();
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Confirmation',
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, _, _) => AlertDialog(
          icon: const Icon(
            Icons.help_outline,
            color: VistoraColors.orange,
            size: 34,
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
        transitionBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        ),
      ) ??
      false;

  void _showAssignmentDetails(MrAssignment assignment) => _showDetails(
    title: assignment.doctorName ?? 'Doctor visit',
    icon: Icons.route_outlined,
    children: [
      _DetailRow(
        'Employee',
        '${assignment.employeeName ?? 'Employee'} (${assignment.employeeCode ?? '—'})',
      ),
      _DetailRow(
        'Visit date',
        DateFormat.yMMMMEEEEd().format(assignment.visitDate),
      ),
      _DetailRow('Location', assignment.location.address),
      _DetailRow(
        'Geofence',
        assignment.geofenceRequired
            ? '${assignment.location.radiusMeters} metres'
            : 'Not restricted',
      ),
      _DetailRow('Visiting status', _label(assignment.visitingStatus)),
      if ((assignment.instructions ?? '').isNotEmpty)
        _DetailRow('Instructions', assignment.instructions!),
      if ((assignment.assignedByName ?? '').isNotEmpty)
        _DetailRow('Assigned by', assignment.assignedByName!),
    ],
  );

  void _showReportDetails(MrVisitReport report) => _showDetails(
    title: report.doctorName ?? 'Visit report',
    icon: Icons.fact_check_outlined,
    children: [
      _DetailRow(
        'Employee',
        '${report.employeeName ?? 'Employee'} (${report.employeeCode ?? '—'})',
      ),
      _DetailRow('Status', _label(report.status)),
      if (report.visitedAt != null)
        _DetailRow(
          'Captured at',
          DateFormat.yMMMMd().add_jm().format(report.visitedAt!.toLocal()),
        ),
      if ((report.locationAddress ?? '').isNotEmpty)
        _DetailRow('Doctor location', report.locationAddress!),
      if ((report.capturedAddress ?? '').isNotEmpty)
        _DetailRow('Captured address', report.capturedAddress!),
      if (report.hasCoordinates)
        _DetailRow(
          'Captured coordinates',
          '${report.latitude!.toStringAsFixed(7)}, ${report.longitude!.toStringAsFixed(7)}',
        ),
      if (report.accuracyMeters != null)
        _DetailRow(
          'GPS accuracy',
          '${report.accuracyMeters!.toStringAsFixed(1)} metres',
        ),
      if (report.distanceMeters != null)
        _DetailRow(
          'Distance from location',
          '${report.distanceMeters!.toStringAsFixed(1)} metres',
        ),
      if ((report.notes ?? '').isNotEmpty)
        _DetailRow('Description', report.notes!),
      if ((report.outcome ?? '').isNotEmpty)
        _DetailRow('Outcome', report.outcome!),
      if ((report.reviewNotes ?? '').isNotEmpty)
        _DetailRow('Review notes', report.reviewNotes!),
      if ((report.rollbackNotes ?? '').isNotEmpty)
        _DetailRow('Rollback notes', report.rollbackNotes!),
    ],
  );

  void _showDetails({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: .72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => SafeArea(
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Icon(icon)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .08), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
  }

  void _success(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: VistoraColors.green),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );

  void _error(Object error) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.section,
    required this.search,
    required this.searchHint,
    required this.status,
    required this.statuses,
    required this.date,
    required this.year,
    required this.perPage,
    required this.canAdd,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onDate,
    required this.onClearDate,
    required this.onYearChanged,
    required this.onPerPageChanged,
    required this.onAdd,
  });

  final _MrSection section;
  final TextEditingController search;
  final String searchHint;
  final String? status;
  final List<String> statuses;
  final DateTime? date;
  final int? year;
  final int perPage;
  final bool canAdd;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onDate;
  final VoidCallback onClearDate;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int> onPerPageChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final fieldWidth = compact ? constraints.maxWidth : 190.0;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 320,
                  child: TextField(
                    controller: search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: searchHint,
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                search.clear();
                                onSearchChanged('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                if (statuses.isNotEmpty)
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All statuses'),
                        ),
                        ...statuses.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item,
                            child: Text(_label(item)),
                          ),
                        ),
                      ],
                      onChanged: onStatusChanged,
                    ),
                  ),
                SizedBox(
                  width: fieldWidth,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText:
                            section == _MrSection.assignments ||
                                section == _MrSection.myVisits
                            ? 'Visit date'
                            : 'Date',
                        prefixIcon: const Icon(Icons.event_outlined),
                        suffixIcon: date == null
                            ? null
                            : IconButton(
                                onPressed: onClearDate,
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      child: Text(
                        date == null
                            ? 'Any date'
                            : DateFormat.yMMMd().format(date!),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: compact ? (constraints.maxWidth - 10) / 2 : 130,
                  child: DropdownButtonFormField<int?>(
                    value: year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ...List.generate(
                        8,
                        (index) => DateTime.now().year + 2 - index,
                      ).map(
                        (value) => DropdownMenuItem<int?>(
                          value: value,
                          child: Text('$value'),
                        ),
                      ),
                    ],
                    onChanged: onYearChanged,
                  ),
                ),
                SizedBox(
                  width: compact ? (constraints.maxWidth - 10) / 2 : 130,
                  child: DropdownButtonFormField<int>(
                    value: perPage,
                    decoration: const InputDecoration(labelText: 'Per page'),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (value) {
                      if (value != null) onPerPageChanged(value);
                    },
                  ),
                ),
                if (canAdd)
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(
                      section == _MrSection.assignments
                          ? 'Assign visit'
                          : 'Add ${section.title.substring(0, section.title.length - 1)}',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _SettingsView extends ConsumerStatefulWidget {
  const _SettingsView();

  @override
  ConsumerState<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<_SettingsView> {
  final _limit = TextEditingController();
  late Future<MrSettings> _future;
  bool _initialized = false;
  bool _saving = false;
  bool _autoConfirm = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(mrRepositoryProvider).settings();
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_limit.text.trim());
    if (value == null || value < 1 || value > 50) {
      _message('Enter a limit from 1 to 50.');
      return;
    }
    setState(() => _saving = true);
    try {
      final settings = await ref
          .read(mrRepositoryProvider)
          .updateSettings(
            maxLocationsPerDoctor: value,
            autoConfirmVisitReports: _autoConfirm,
          );
      if (!mounted) return;
      _limit.text = '${settings.maxLocationsPerDoctor}';
      _autoConfirm = settings.autoConfirmVisitReports;
      ref.invalidate(mrSettingsProvider);
      ref.invalidate(mrMetadataProvider);
      _message('MR settings saved.', success: true);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message, {bool success = false}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error_outline,
                  color: success
                      ? VistoraColors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );

  @override
  Widget build(BuildContext context) => FutureBuilder<MrSettings>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _ErrorList(
          error: snapshot.error!,
          onRetry: () {
            setState(() => _future = ref.read(mrRepositoryProvider).settings());
            return _future;
          },
        );
      }
      if (!_initialized) {
        _limit.text = '${snapshot.requireData.maxLocationsPerDoctor}';
        _autoConfirm = snapshot.requireData.autoConfirmVisitReports;
        _initialized = true;
      }
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0x33FF6A00), Color(0x2200D2FF)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .1),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tune, color: VistoraColors.orange, size: 34),
                        SizedBox(height: 12),
                        Text(
                          'MR module settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Configure tenant-wide doctor and location behaviour. Changes are audited and apply to Laravel and mobile clients.',
                          style: TextStyle(color: VistoraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Maximum locations per doctor',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'A doctor cannot be mapped above this limit. The limit cannot be reduced below mappings already in use.',
                            style: TextStyle(color: VistoraColors.muted),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _limit,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Location limit',
                              prefixIcon: Icon(Icons.pin_drop_outlined),
                              suffixText: 'per doctor',
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: _autoConfirm
                                    ? const [
                                        Color(0x3324E59B),
                                        Color(0x2218C8FF),
                                      ]
                                    : const [
                                        Color(0x18FFFFFF),
                                        Color(0x0DFFFFFF),
                                      ],
                              ),
                              border: Border.all(
                                color: _autoConfirm
                                    ? VistoraColors.green.withValues(alpha: .5)
                                    : Colors.white.withValues(alpha: .1),
                              ),
                            ),
                            child: SwitchListTile.adaptive(
                              value: _autoConfirm,
                              onChanged: _saving
                                  ? null
                                  : (value) =>
                                        setState(() => _autoConfirm = value),
                              secondary: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Icon(
                                  _autoConfirm
                                      ? Icons.bolt_rounded
                                      : Icons.fact_check_outlined,
                                  key: ValueKey(_autoConfirm),
                                  color: _autoConfirm
                                      ? VistoraColors.green
                                      : VistoraColors.amber,
                                ),
                              ),
                              title: const Text(
                                'Auto-confirm visit reports',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              subtitle: const Text(
                                'Immediately approves employee and supervisor reports. Authorized HR/Admin and supervisors can still revert a subordinate review.',
                                style: TextStyle(color: VistoraColors.muted),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save setting'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.actions,
    this.status,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? status;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(color: VistoraColors.muted),
                      ),
                  ],
                ),
              ),
              if ((status ?? '').isNotEmpty) _StatusPill(status!),
            ],
          ),
          const Divider(height: 24),
          content,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: actions,
            ),
          ],
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });
  final int page;
  final int lastPage;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        Text(
          'Page $page of $lastPage • $total total',
          style: const TextStyle(
            color: VistoraColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        OutlinedButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    ),
  );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(index),
    duration: Duration(milliseconds: 240 + (index.clamp(0, 5) * 45)),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        for (var index = 0; index < 3; index++)
          Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: VistoraColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.cloud_off_outlined,
          size: 58,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        const Text(
          'MR information could not be loaded',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: VistoraColors.muted),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.section,
    required this.canAdd,
    required this.onAdd,
  });
  final _MrSection section;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70),
    child: Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: VistoraColors.cyan.withValues(alpha: .1),
          child: Icon(section.icon, size: 34, color: VistoraColors.cyan),
        ),
        const SizedBox(height: 16),
        Text(
          'No matching ${section.title.toLowerCase()}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        const SizedBox(height: 6),
        const Text(
          'Adjust the filters or pull down to refresh.',
          style: TextStyle(color: VistoraColors.muted),
        ),
        if (canAdd) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(
              section == _MrSection.assignments
                  ? 'Assign a visit'
                  : 'Add ${section.title.toLowerCase()}',
            ),
          ),
        ],
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: VistoraColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );
}

Color _statusColor(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('approved') ||
      normalized.contains('completed') ||
      normalized == 'active') {
    return VistoraColors.green;
  }
  if (normalized.contains('rejected') || normalized.contains('cancelled')) {
    return const Color(0xFFFF6B7A);
  }
  if (normalized.contains('submitted') ||
      normalized.contains('pending') ||
      normalized.contains('revisit')) {
    return VistoraColors.amber;
  }
  if (normalized.contains('draft') || normalized.contains('rolled back')) {
    return VistoraColors.cyan;
  }
  return VistoraColors.muted;
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
