import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/features/attendance/data/location_service.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/mr/data/mr_repository.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_providers.dart';

enum _MrSection {
  myVisits,
  doctors,
  locations,
  territories,
  assignments,
  reports,
}

class MrScreen extends ConsumerWidget {
  const MrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session!;
    final role = session.user.normalizedRole;
    final manager = const {
      'admin',
      'hr',
      'superadmin',
      'supervisor',
    }.contains(role);
    final masterManager = const {
      'admin',
      'hr',
      'superadmin',
      'supervisor',
    }.contains(role);
    final selfService = const {'employee', 'supervisor'}.contains(role);
    final sections = <_MrSection>[
      if (selfService) _MrSection.myVisits,
      if (masterManager) ...[
        _MrSection.doctors,
        _MrSection.locations,
        _MrSection.territories,
        _MrSection.assignments,
      ],
      _MrSection.reports,
    ];
    return DefaultTabController(
      length: sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medical Representative'),
          bottom: TabBar(
            isScrollable: true,
            tabs: sections.map((item) => Tab(text: _title(item))).toList(),
          ),
        ),
        body: TabBarView(
          children: sections
              .map(
                (section) => _MrSectionView(
                  section: section,
                  canManage: manager,
                  canManageMasters: masterManager,
                  role: role,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  static String _title(_MrSection section) => switch (section) {
    _MrSection.myVisits => 'My visits',
    _MrSection.doctors => 'Doctors',
    _MrSection.locations => 'Locations',
    _MrSection.territories => 'Territories',
    _MrSection.assignments => 'Assignments',
    _MrSection.reports => 'Visit reports',
  };
}

class _MrSectionView extends ConsumerStatefulWidget {
  const _MrSectionView({
    required this.section,
    required this.canManage,
    required this.canManageMasters,
    required this.role,
  });
  final _MrSection section;
  final bool canManage;
  final bool canManageMasters;
  final String role;

  @override
  ConsumerState<_MrSectionView> createState() => _MrSectionViewState();
}

class _MrSectionViewState extends ConsumerState<_MrSectionView> {
  final _search = TextEditingController();
  String? _status;
  late Future<MrPage<Object>> _items;

  MrRepository get _repository => ref.read(mrRepositoryProvider);
  bool get _mine =>
      widget.section == _MrSection.myVisits ||
      (widget.section == _MrSection.reports && widget.role == 'employee');

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<MrPage<Object>> _load({int page = 1}) async =>
      switch (widget.section) {
        _MrSection.myVisits => _asObjects(
          await _repository.assignments(
            query: _search.text,
            status: _status,
            mine: true,
            page: page,
          ),
        ),
        _MrSection.doctors => _asObjects(
          await _repository.doctors(
            query: _search.text,
            status: _status,
            page: page,
          ),
        ),
        _MrSection.locations => _asObjects(
          await _repository.locations(
            query: _search.text,
            status: _status,
            page: page,
          ),
        ),
        _MrSection.territories => _asObjects(
          await _repository.territories(query: _search.text, page: page),
        ),
        _MrSection.assignments => _asObjects(
          await _repository.assignments(
            query: _search.text,
            status: _status,
            page: page,
          ),
        ),
        _MrSection.reports => _asObjects(
          await _repository.reports(
            query: _search.text,
            status: _status,
            mine: _mine,
            page: page,
          ),
        ),
      };

  MrPage<Object> _asObjects<T>(MrPage<T> page) => MrPage<Object>(
    items: page.items.cast<Object>(),
    currentPage: page.currentPage,
    lastPage: page.lastPage,
  );

  void _loadMore(MrPage<Object> current) {
    if (!current.hasMore) return;
    setState(() {
      _items = () async {
        final next = await _load(page: current.currentPage + 1);
        return MrPage<Object>(
          items: [...current.items, ...next.items],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
        );
      }();
    });
  }

  Future<void> _refresh() async {
    setState(() => _items = _load());
    await _items;
  }

  @override
  Widget build(BuildContext context) {
    final canAdd =
        widget.canManageMasters &&
        const {
          _MrSection.doctors,
          _MrSection.locations,
          _MrSection.territories,
          _MrSection.assignments,
        }.contains(widget.section);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search',
                  ),
                  onSubmitted: (_) => _refresh(),
                ),
              ),
              if (_supportsStatus) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  tooltip: 'Filter by status',
                  initialValue: _status,
                  icon: const Icon(Icons.filter_alt_outlined),
                  onSelected: (value) {
                    _status = value;
                    _refresh();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ..._statuses.map(
                      (value) => PopupMenuItem(
                        value: value,
                        child: Text(_label(value)),
                      ),
                    ),
                  ],
                ),
              ],
              if (canAdd)
                IconButton.filled(
                  tooltip: 'Add ${MrScreen._title(widget.section)}',
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<MrPage<Object>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      _Message(
                        icon: Icons.cloud_off,
                        text: snapshot.error.toString(),
                      ),
                    ],
                  );
                }
                final page = snapshot.data!;
                final items = page.items;
                if (items.isEmpty) {
                  return ListView(
                    children: const [
                      _Message(
                        icon: Icons.inbox_outlined,
                        text: 'No matching records.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length + (page.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => index == items.length
                      ? Center(
                          child: OutlinedButton.icon(
                            onPressed: () => _loadMore(page),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Load more'),
                          ),
                        )
                      : _card(items[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool get _supportsStatus => widget.section != _MrSection.territories;
  List<String> get _statuses => switch (widget.section) {
    _MrSection.doctors || _MrSection.locations => const ['active', 'inactive'],
    _MrSection.myVisits ||
    _MrSection.assignments => const ['planned', 'cancelled', 'completed'],
    _MrSection.reports => const ['draft', 'submitted', 'approved', 'rejected'],
    _ => const [],
  };

  Widget _card(Object item) {
    if (item is MrDoctor) return _doctorCard(item);
    if (item is MrLocation) return _locationCard(item);
    if (item is MrTerritory) return _territoryCard(item);
    if (item is MrAssignment) return _assignmentCard(item);
    return _reportCard(item as MrVisitReport);
  }

  Widget _doctorCard(MrDoctor item) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
      title: Text(
        item.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          item.specialization,
          item.phone,
          item.email,
        ].whereType<String>().join(' • '),
      ),
      trailing: _actions(
        status: item.status,
        edit: () => _doctorForm(item),
        delete: () =>
            _delete('doctor', () => _repository.deleteDoctor(item.id)),
      ),
    ),
  );

  Widget _locationCard(MrLocation item) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.place_outlined)),
      title: Text(
        item.address,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${[item.city, item.stateName].whereType<String>().join(', ')}\nGeofence: ${item.radiusMeters} m',
      ),
      isThreeLine: true,
      trailing: _actions(
        status: item.status,
        edit: () => _locationForm(item),
        delete: () =>
            _delete('location', () => _repository.deleteLocation(item.id)),
      ),
    ),
  );

  Widget _territoryCard(MrTerritory item) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.map_outlined)),
      title: Text(
        item.doctorName ?? 'Doctor territory',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          item.stateName,
          item.branchName,
          item.businessUnitName,
        ].whereType<String>().join(' • '),
      ),
      trailing: _actions(
        status: item.isActive ? 'active' : 'inactive',
        edit: () => _territoryForm(item),
        delete: () =>
            _delete('territory', () => _repository.deleteTerritory(item.id)),
      ),
    ),
  );

  Widget _assignmentCard(MrAssignment item) {
    final mine = widget.section == _MrSection.myVisits;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.doctorName ?? 'Doctor visit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                _Status(item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat.yMMMd().format(item.visitDate)} • ${item.locationAddress ?? 'Location'}',
            ),
            if (!mine && item.employeeName != null)
              Text('${item.employeeName} (${item.employeeCode ?? 'employee'})'),
            if (item.instructions != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(item.instructions!),
              ),
            const SizedBox(height: 8),
            Text(
              _label(item.visitingStatus),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              children: [
                if (mine &&
                    item.status == 'planned' &&
                    !{'submitted', 'approved'}.contains(item.report?.status))
                  FilledButton.icon(
                    onPressed: () => _reportForm(item),
                    icon: const Icon(Icons.pin_drop_outlined),
                    label: Text(
                      item.report == null ? 'Record visit' : 'Resubmit visit',
                    ),
                  ),
                if (!mine && widget.canManage && item.status == 'planned') ...[
                  TextButton(
                    onPressed: () => _assignmentForm(item),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () => _delete(
                      'assignment',
                      () => _repository.cancelAssignment(item.id),
                      verb: 'cancel',
                    ),
                    child: const Text('Cancel'),
                  ),
                  IconButton(
                    onPressed: () => _delete(
                      'assignment',
                      () => _repository.deleteAssignment(item.id),
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(MrVisitReport item) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.doctorName ?? 'Visit report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _Status(item.status),
            ],
          ),
          const SizedBox(height: 8),
          if (!_mine && item.employeeName != null) Text(item.employeeName!),
          Text(
            '${item.visitedAt == null ? 'Visit time unavailable' : DateFormat.yMMMd().add_jm().format(item.visitedAt!)} • ${item.locationAddress ?? 'Location'}',
          ),
          if (item.checkInSource != null)
            Text(
              'Check-in: ${_label(item.checkInSource!)}${item.distanceMeters == null ? '' : ' • ${item.distanceMeters!.round()} m'}',
            ),
          if (item.outcome != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Outcome: ${item.outcome}'),
            ),
          if (item.notes != null) Text('Notes: ${item.notes}'),
          if (item.reviewNotes != null)
            Text(
              'Review: ${item.reviewNotes}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          if (!_mine && widget.canManage)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              children: [
                if (item.status == 'submitted') ...[
                  FilledButton(
                    onPressed: () => _review(item, true),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: () => _review(item, false),
                    child: const Text('Reject'),
                  ),
                ],
                if (const {'approved', 'rejected'}.contains(item.status))
                  TextButton(
                    onPressed: () =>
                        _mutate(() => _repository.revertReport(item.id)),
                    child: const Text('Revert decision'),
                  ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _actions({
    required String status,
    required VoidCallback edit,
    required VoidCallback delete,
  }) => SizedBox(
    width: 120,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Status(status),
        PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? edit() : delete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );

  Future<void> _add() async => switch (widget.section) {
    _MrSection.doctors => _doctorForm(null),
    _MrSection.locations => _locationForm(null),
    _MrSection.territories => _territoryForm(null),
    _MrSection.assignments => _assignmentForm(null),
    _ => Future.value(),
  };

  Future<void> _doctorForm(MrDoctor? item) async {
    final name = TextEditingController(text: item?.name);
    final specialty = TextEditingController(text: item?.specialization);
    final phone = TextEditingController(text: item?.phone);
    final email = TextEditingController(text: item?.email);
    var status = item?.status ?? 'active';
    await _formSheet(
      title: item == null ? 'Add doctor' : 'Edit doctor',
      content: (setLocal) => [
        _field(name, 'Doctor name', required: true),
        _field(specialty, 'Specialization'),
        _field(phone, 'Phone', keyboard: TextInputType.phone),
        _field(email, 'Email', keyboard: TextInputType.emailAddress),
        _dropdown<String>('Status', status, const [
          'active',
          'inactive',
        ], (value) => setLocal(() => status = value!)),
      ],
      save: () => _repository.saveDoctor(
        id: item?.id,
        data: {
          'doctor_name': name.text.trim(),
          'specialization': specialty.text.trim(),
          'phone': phone.text.trim(),
          'email': email.text.trim(),
          'status': status,
        },
      ),
    );
  }

  Future<void> _locationForm(MrLocation? item) async {
    final metadata = await ref.read(mrMetadataProvider.future);
    final address = TextEditingController(text: item?.address);
    final city = TextEditingController(text: item?.city);
    final latitude = TextEditingController(text: item?.latitude?.toString());
    final longitude = TextEditingController(text: item?.longitude?.toString());
    final radius = TextEditingController(
      text: (item?.radiusMeters ?? 100).toString(),
    );
    var stateId = item?.stateId ?? _firstId(metadata.states);
    var status = item?.status ?? 'active';
    await _formSheet(
      title: item == null ? 'Add location' : 'Edit location',
      content: (setLocal) => [
        _field(address, 'Address', required: true, lines: 2),
        _field(city, 'City'),
        _optionDropdown(
          'State',
          stateId,
          metadata.states,
          (value) => setLocal(() => stateId = value!),
        ),
        _field(
          latitude,
          'Latitude',
          keyboard: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        _field(
          longitude,
          'Longitude',
          keyboard: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        _field(
          radius,
          'Geofence radius (meters)',
          keyboard: TextInputType.number,
        ),
        _dropdown<String>('Status', status, const [
          'active',
          'inactive',
        ], (value) => setLocal(() => status = value!)),
      ],
      save: () => _repository.saveLocation(
        id: item?.id,
        data: {
          'address': address.text.trim(),
          'city': city.text.trim(),
          'state_id': stateId,
          'latitude': double.tryParse(latitude.text),
          'longitude': double.tryParse(longitude.text),
          'geofence_radius_meters': int.tryParse(radius.text),
          'status': status,
        },
      ),
    );
  }

  Future<void> _territoryForm(MrTerritory? item) async {
    final values = await Future.wait([
      ref.read(mrMetadataProvider.future),
      ref.read(mrDoctorsProvider.future),
    ]);
    final metadata = values[0] as MrMetadata;
    final doctors = (values[1] as List<MrDoctor>)
        .map((e) => MrOption(id: e.id, name: e.name))
        .toList();
    var doctorId = item?.doctorId ?? _firstId(doctors);
    var stateId = item?.stateId ?? _firstId(metadata.states);
    var branchId = item?.branchId ?? _firstId(metadata.branches);
    var unitId = item?.businessUnitId ?? _firstId(metadata.businessUnits);
    var active = item?.isActive ?? true;
    await _formSheet(
      title: item == null ? 'Add territory' : 'Edit territory',
      content: (setLocal) => [
        _optionDropdown(
          'Doctor',
          doctorId,
          doctors,
          (value) => setLocal(() => doctorId = value!),
        ),
        _optionDropdown(
          'State',
          stateId,
          metadata.states,
          (value) => setLocal(() => stateId = value!),
        ),
        _optionDropdown(
          'Branch',
          branchId,
          metadata.branches,
          (value) => setLocal(() => branchId = value!),
        ),
        _optionDropdown(
          'Business unit',
          unitId,
          metadata.businessUnits,
          (value) => setLocal(() => unitId = value!),
        ),
        SwitchListTile(
          value: active,
          title: const Text('Active'),
          onChanged: (value) => setLocal(() => active = value),
        ),
      ],
      save: () => _repository.saveTerritory(
        id: item?.id,
        data: {
          'doctor_id': doctorId,
          'state_id': stateId,
          'branch_id': branchId,
          'business_unit_id': unitId,
          'is_active': active,
        },
      ),
    );
  }

  Future<void> _assignmentForm(MrAssignment? item) async {
    final values = await Future.wait([
      ref.read(mrMetadataProvider.future),
      ref.read(mrDoctorsProvider.future),
      ref.read(mrLocationsProvider.future),
      ref.read(mrTerritoriesProvider.future),
    ]);
    final metadata = values[0] as MrMetadata;
    final doctors = (values[1] as List<MrDoctor>)
        .map((e) => MrOption(id: e.id, name: e.name))
        .toList();
    final locations = (values[2] as List<MrLocation>)
        .map((e) => MrOption(id: e.id, name: e.address))
        .toList();
    final territories = (values[3] as List<MrTerritory>)
        .map(
          (e) => MrOption(
            id: e.id,
            name: '${e.doctorName ?? 'Doctor'} • ${e.stateName ?? 'Territory'}',
          ),
        )
        .toList();
    var employeeId = item?.employeeId ?? _firstId(metadata.employees);
    var doctorId = item?.doctorId ?? _firstId(doctors);
    var locationId = item?.locationId ?? _firstId(locations);
    var territoryId = item?.territoryId ?? _firstId(territories);
    var visitDate = item?.visitDate ?? DateTime.now();
    final instructions = TextEditingController(text: item?.instructions);
    await _formSheet(
      title: item == null ? 'Create assignment' : 'Edit assignment',
      content: (setLocal) => [
        _employeeTerritoryDropdown(
          employeeId: employeeId,
          territoryId: territoryId,
          employees: metadata.employees,
          territories: values[3] as List<MrTerritory>,
          changed: (value) => setLocal(() => employeeId = value!),
        ),
        _optionDropdown(
          'Doctor',
          doctorId,
          doctors,
          (value) => setLocal(() => doctorId = value!),
        ),
        _optionDropdown(
          'Location',
          locationId,
          locations,
          (value) => setLocal(() => locationId = value!),
        ),
        _optionDropdown(
          'Territory',
          territoryId,
          territories,
          (value) => setLocal(() => territoryId = value!),
        ),
        ListTile(
          title: const Text('Visit date'),
          subtitle: Text(DateFormat.yMMMMd().format(visitDate)),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: visitDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (selected != null) {
              setLocal(() => visitDate = selected);
            }
          },
        ),
        _field(instructions, 'Instructions', lines: 3),
      ],
      save: () => _repository.saveAssignment(
        id: item?.id,
        data: {
          'employee_id': employeeId,
          'doctor_id': doctorId,
          'location_id': locationId,
          'doctor_territory_id': territoryId,
          'visit_date': DateFormat('yyyy-MM-dd').format(visitDate),
          'instructions': instructions.text.trim(),
        },
      ),
    );
  }

  Future<void> _reportForm(MrAssignment assignment) async {
    final notes = TextEditingController(text: assignment.report?.notes);
    final outcome = TextEditingController(text: assignment.report?.outcome);
    var source = assignment.report?.checkInSource ?? 'gps';
    double? latitude;
    double? longitude;
    double? accuracy;
    String? locationMessage;
    await _formSheet(
      title: 'Visit report • ${assignment.doctorName ?? 'Doctor'}',
      submitLabel: 'Save and submit',
      content: (setLocal) => [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'gps',
              icon: Icon(Icons.gps_fixed),
              label: Text('GPS'),
            ),
            ButtonSegment(
              value: 'manual',
              icon: Icon(Icons.edit_location_alt_outlined),
              label: Text('Manual fallback'),
            ),
          ],
          selected: {source},
          onSelectionChanged: (value) => setLocal(() {
            source = value.first;
            locationMessage = null;
          }),
        ),
        if (source == 'gps')
          ListTile(
            title: const Text('Device location'),
            subtitle: Text(
              locationMessage ?? 'Capture coordinates at the doctor location.',
            ),
            trailing: FilledButton.tonal(
              onPressed: () async {
                try {
                  final position = await const LocationService()
                      .currentPosition();
                  setLocal(() {
                    latitude = position.latitude;
                    longitude = position.longitude;
                    accuracy = position.accuracy;
                    locationMessage =
                        'Captured with ${position.accuracy.round()} m accuracy';
                  });
                } catch (error) {
                  setLocal(() => locationMessage = error.toString());
                }
              },
              child: const Text('Capture'),
            ),
          ),
        if (source == 'manual')
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Manual fallback records no client coordinates. Laravel will apply the configured approval rules.',
            ),
          ),
        _field(outcome, 'Outcome', lines: 3),
        _field(notes, 'Notes', lines: 3),
      ],
      validate: () => source == 'gps' && (latitude == null || longitude == null)
          ? 'Capture your GPS location before submitting.'
          : null,
      save: () => _repository.saveAndSubmitReport(
        assignmentId: assignment.id,
        reportId: assignment.report?.id,
        data: {
          'visited_at': DateTime.now().toUtc().toIso8601String(),
          'check_in_source': source,
          if (source == 'gps') ...{
            'latitude': latitude,
            'longitude': longitude,
            'location_accuracy_meters': accuracy,
          },
          'outcome': outcome.text.trim(),
          'notes': notes.text.trim(),
        },
      ),
    );
  }

  Future<void> _review(MrVisitReport report, bool approve) async {
    if (approve) return _mutate(() => _repository.approveReport(report.id));
    final notes = TextEditingController();
    await _formSheet(
      title: 'Reject visit report',
      submitLabel: 'Reject',
      content: (_) => [_field(notes, 'Review notes', required: true, lines: 3)],
      save: () => _repository.rejectReport(report.id, notes.text.trim()),
    );
  }

  Widget _employeeTerritoryDropdown({
    required int? employeeId,
    required int? territoryId,
    required List<MrEmployeeOption> employees,
    required List<MrTerritory> territories,
    required ValueChanged<int?> changed,
  }) {
    final matchingTerritories = territories.where(
      (item) => item.id == territoryId,
    );
    final territory = matchingTerritories.isEmpty
        ? null
        : matchingTerritories.first;
    bool differs(MrEmployeeOption employee) =>
        territory != null &&
        employee.stateId != null &&
        employee.branchId != null &&
        employee.businessUnitId != null &&
        (employee.stateId != territory.stateId ||
            employee.branchId != territory.branchId ||
            employee.businessUnitId != territory.businessUnitId);

    final matchingEmployees = employees.where((item) => item.id == employeeId);
    final selected = matchingEmployees.isEmpty ? null : matchingEmployees.first;
    final warning = selected != null && differs(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: employees.any((item) => item.id == employeeId)
              ? employeeId
              : null,
          decoration: const InputDecoration(labelText: 'Employee'),
          items: employees
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.code == null
                              ? item.name
                              : '${item.name} (${item.code})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (differs(item))
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: _TerritoryWarningChip(compact: true),
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: changed,
          validator: (value) => value == null ? 'Employee is required.' : null,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: warning
              ? const Padding(
                  key: ValueKey('different-territory'),
                  padding: EdgeInsets.only(top: 8),
                  child: _TerritoryWarningChip(),
                )
              : const SizedBox(key: ValueKey('same-territory')),
        ),
      ],
    );
  }

  Future<void> _delete(
    String name,
    Future<void> Function() action, {
    String verb = 'delete',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${_label(verb)} ${_label(name)}?'),
        content: Text(
          'Laravel will block this action if the $name is already in use.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_label(verb)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _mutate(action);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MR data updated.')));
      await _refresh();
      invalidateMr(ref);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _formSheet({
    required String title,
    required List<Widget> Function(StateSetter) content,
    required Future<void> Function() save,
    String submitLabel = 'Save',
    String? Function()? validate,
  }) async {
    final key = GlobalKey<FormState>();
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
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
                  const SizedBox(height: 10),
                  ...content(
                    setLocal,
                  ).expand((widget) => [widget, const SizedBox(height: 12)]),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (key.currentState?.validate() != true) return;
                            final issue = validate?.call();
                            if (issue != null) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(issue)));
                              return;
                            }
                            setLocal(() => saving = true);
                            try {
                              await save();
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              await _refresh();
                              invalidateMr(ref);
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('MR data updated.'),
                                  ),
                                );
                              }
                            } catch (error) {
                              setLocal(() => saving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving ? 'Saving…' : submitLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? '$label is required.'
              : null
        : null,
  );

  static DropdownButtonFormField<T> _dropdown<T>(
    String label,
    T? value,
    List<T> values,
    ValueChanged<T?> changed,
  ) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(_label(item.toString())),
          ),
        )
        .toList(),
    onChanged: changed,
  );

  static DropdownButtonFormField<int> _optionDropdown(
    String label,
    int? value,
    List<MrOption> values,
    ValueChanged<int?> changed,
  ) => DropdownButtonFormField<int>(
    initialValue: values.any((item) => item.id == value) ? value : null,
    decoration: InputDecoration(labelText: label),
    items: values
        .map(
          (item) => DropdownMenuItem(
            value: item.id,
            child: Text(
              item.code == null ? item.name : '${item.name} (${item.code})',
            ),
          ),
        )
        .toList(),
    onChanged: changed,
    validator: (selected) => selected == null ? '$label is required.' : null,
  );

  static int? _firstId(List<MrOption> values) =>
      values.isEmpty ? null : values.first.id;
}

class _TerritoryWarningChip extends StatelessWidget {
  const _TerritoryWarningChip({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 10,
      vertical: compact ? 3 : 7,
    ),
    decoration: BoxDecoration(
      color: Colors.amber.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.amber.withValues(alpha: .45)),
    ),
    child: Text(
      compact
          ? 'Different territory'
          : 'Different territory · assignment allowed',
      style: TextStyle(
        color: Colors.amber.shade300,
        fontSize: compact ? 10 : 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'active' || 'approved' || 'completed' => Colors.green,
      'rejected' || 'cancelled' || 'inactive' => Colors.red,
      'submitted' => Colors.orange,
      _ => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(value),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(48),
    child: Column(
      children: [
        Icon(icon, size: 44),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _label(String value) => value
    .replaceAll('/', ' / ')
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
