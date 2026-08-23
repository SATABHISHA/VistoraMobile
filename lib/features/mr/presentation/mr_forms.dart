import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/attendance/data/location_service.dart';
import 'package:vistora_mobile/features/mr/data/mr_repository.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_providers.dart';

Future<bool> showMrDoctorEditor(
  BuildContext context, {
  MrDoctor? doctor,
}) async =>
    await _showAnimatedDialog<bool>(context, _DoctorEditor(doctor: doctor)) ??
    false;

Future<bool> showMrLocationEditor(
  BuildContext context, {
  MrLocation? location,
}) async =>
    await _showAnimatedDialog<bool>(
      context,
      _LocationEditor(location: location),
    ) ??
    false;

Future<bool> showMrAssignmentEditor(
  BuildContext context, {
  MrAssignment? assignment,
}) async =>
    await _showAnimatedDialog<bool>(
      context,
      _AssignmentEditor(assignment: assignment),
    ) ??
    false;

Future<bool> showMrReportEditor(
  BuildContext context, {
  required MrAssignment assignment,
}) async =>
    await _showAnimatedDialog<bool>(
      context,
      _ReportEditor(assignment: assignment),
    ) ??
    false;

Future<String?> showMrNotesDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String actionLabel,
  String? initialValue,
}) => _showAnimatedDialog<String>(
  context,
  _NotesDialog(
    title: title,
    label: label,
    actionLabel: actionLabel,
    initialValue: initialValue,
  ),
);

Future<T?> _showAnimatedDialog<T>(BuildContext context, Widget child) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close dialog',
      barrierColor: Colors.black.withValues(alpha: .72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => child,
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x33FF6A00), Color(0x2200D2FF)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: VistoraColors.orange.withValues(
                      alpha: .16,
                    ),
                    child: Icon(icon, color: VistoraColors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(color: VistoraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DoctorEditor extends ConsumerStatefulWidget {
  const _DoctorEditor({this.doctor});
  final MrDoctor? doctor;

  @override
  ConsumerState<_DoctorEditor> createState() => _DoctorEditorState();
}

class _DoctorEditorState extends ConsumerState<_DoctorEditor> {
  final _formKey = GlobalKey<FormState>();
  final _search = TextEditingController();
  late final TextEditingController _name;
  late final TextEditingController _specialization;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final Set<int> _selectedIds;
  late Future<_DoctorChoices> _choices;
  String _status = 'active';
  bool _saving = false;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    final doctor = widget.doctor;
    _name = TextEditingController(text: doctor?.name);
    _specialization = TextEditingController(text: doctor?.specialization);
    _phone = TextEditingController(text: doctor?.phone);
    _email = TextEditingController(text: doctor?.email);
    _status = doctor?.status ?? 'active';
    _selectedIds = doctor?.locations.map((item) => item.id).toSet() ?? <int>{};
    _choices = _loadChoices();
  }

  Future<_DoctorChoices> _loadChoices() async {
    final repository = ref.read(mrRepositoryProvider);
    final results = await Future.wait<Object>([
      repository.locations(perPage: 100),
      repository.settings(),
    ]);
    return _DoctorChoices(
      locations: (results[0] as MrPage<MrLocation>).items,
      settings: results[1] as MrSettings,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _specialization.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _createLocation() async {
    final created = await showMrLocationEditor(context);
    if (!created || !mounted) return;
    setState(() => _choices = _loadChoices());
  }

  Future<void> _save(int limit) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIds.isEmpty) {
      setState(
        () => _selectionError = 'Map at least one location to this doctor.',
      );
      return;
    }
    if (_selectedIds.length > limit) {
      setState(
        () => _selectionError =
            'Only $limit location(s) can be mapped under the current MR setting.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _selectionError = null;
    });
    try {
      await ref
          .read(mrRepositoryProvider)
          .saveDoctor(
            id: widget.doctor?.id,
            data: {
              'doctor_name': _name.text.trim(),
              'specialization': _nullable(_specialization.text),
              'phone': _nullable(_phone.text),
              'email': _nullable(_email.text),
              'status': _status,
              'location_ids': _selectedIds.toList(),
            },
          );
      if (!mounted) return;
      invalidateMr(ref);
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    title: widget.doctor == null ? 'Add doctor' : 'Edit doctor',
    subtitle: 'Doctor profile and mapped visit locations',
    icon: Icons.medical_services_outlined,
    child: FutureBuilder<_DoctorChoices>(
      future: _choices,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _InlineError(
            error: snapshot.error!,
            onRetry: () => setState(() => _choices = _loadChoices()),
          );
        }
        final choices = snapshot.requireData;
        final query = _search.text.trim().toLowerCase();
        final locations = choices.locations.where((location) {
          if (query.isEmpty) return true;
          return '${location.address} ${location.city ?? ''} ${location.stateName ?? ''}'
              .toLowerCase()
              .contains(query);
        }).toList();
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _responsiveFields([
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Doctor name *'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _specialization,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                  ),
                ),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'active'),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mapped locations',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${_selectedIds.length} of ${choices.settings.maxLocationsPerDoctor} selected',
                          style: const TextStyle(color: VistoraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _createLocation,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('New location'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search available locations',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              if (locations.isEmpty)
                const _EmptyPanel(
                  message:
                      'No matching locations. Create a location, then map it here.',
                )
              else
                ...locations.map((location) {
                  final selected = _selectedIds.contains(location.id);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: selected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        location.address,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(_locationMeta(location)),
                      secondary: Icon(
                        location.hasGeofence
                            ? Icons.gps_fixed
                            : Icons.location_on_outlined,
                        color: location.hasGeofence
                            ? VistoraColors.green
                            : VistoraColors.cyan,
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (_selectedIds.length >=
                                choices.settings.maxLocationsPerDoctor) {
                              _selectionError =
                                  'The maximum is ${choices.settings.maxLocationsPerDoctor} location(s).';
                              return;
                            }
                            _selectedIds.add(location.id);
                          } else {
                            _selectedIds.remove(location.id);
                          }
                          _selectionError = null;
                        });
                      },
                    ),
                  );
                }),
              if (_selectionError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _selectionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              _DialogActions(
                saving: _saving,
                saveLabel: widget.doctor == null
                    ? 'Add doctor'
                    : 'Save changes',
                onSave: () => _save(choices.settings.maxLocationsPerDoctor),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _DoctorChoices {
  const _DoctorChoices({required this.locations, required this.settings});
  final List<MrLocation> locations;
  final MrSettings settings;
}

class _LocationEditor extends ConsumerStatefulWidget {
  const _LocationEditor({this.location});
  final MrLocation? location;

  @override
  ConsumerState<_LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends ConsumerState<_LocationEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;
  late Future<MrMetadata> _metadata;
  int? _stateId;
  int? _branchId;
  int? _businessUnitId;
  String _status = 'active';
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _address = TextEditingController(text: location?.address);
    _city = TextEditingController(text: location?.city);
    _latitude = TextEditingController(text: location?.latitude?.toString());
    _longitude = TextEditingController(text: location?.longitude?.toString());
    _radius = TextEditingController(text: location?.radiusMeters?.toString());
    _stateId = location?.stateId;
    _branchId = location?.branchId;
    _businessUnitId = location?.businessUnitId;
    _status = location?.status ?? 'active';
    _metadata = ref.read(mrRepositoryProvider).metadata();
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _captureCoordinates() async {
    setState(() => _locating = true);
    try {
      final position = await const LocationService().currentPosition();
      _latitude.text = position.latitude.toStringAsFixed(7);
      _longitude.text = position.longitude.toStringAsFixed(7);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save(MrMetadata metadata) async {
    if (!_formKey.currentState!.validate()) return;
    final lat = _number(_latitude.text);
    final lng = _number(_longitude.text);
    final radius = int.tryParse(_radius.text.trim());
    if ((lat == null) != (lng == null)) {
      _showError(context, 'Latitude and longitude must be supplied together.');
      return;
    }
    if (radius != null && (lat == null || lng == null)) {
      _showError(context, 'Set latitude and longitude before adding a radius.');
      return;
    }
    if (_stateId == null ||
        (metadata.branches.isNotEmpty && _branchId == null) ||
        (metadata.businessUnits.isNotEmpty && _businessUnitId == null)) {
      _showError(
        context,
        'Select the state, branch and business unit for this location.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(mrRepositoryProvider)
          .saveLocation(
            id: widget.location?.id,
            data: {
              'address': _address.text.trim(),
              'city': _nullable(_city.text),
              'state_id': _stateId,
              'branch_id': _branchId,
              'business_unit_id': _businessUnitId,
              'latitude': lat,
              'longitude': lng,
              'geofence_radius_meters': radius,
              'status': _status,
            },
          );
      if (!mounted) return;
      invalidateMr(ref);
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    title: widget.location == null
        ? 'Add doctor location'
        : 'Edit doctor location',
    subtitle: 'Organisation mapping and optional GPS geofence',
    icon: Icons.add_location_alt_outlined,
    child: FutureBuilder<MrMetadata>(
      future: _metadata,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _InlineError(
            error: snapshot.error!,
            onRetry: () => setState(
              () => _metadata = ref.read(mrRepositoryProvider).metadata(),
            ),
          );
        }
        final metadata = snapshot.requireData;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Location address *',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              _responsiveFields([
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                _optionDropdown(
                  label: 'State *',
                  value: _stateId,
                  options: metadata.states,
                  onChanged: (value) => setState(() => _stateId = value),
                ),
                _optionDropdown(
                  label: 'Branch *',
                  value: _branchId,
                  options: metadata.branches,
                  onChanged: (value) => setState(() => _branchId = value),
                ),
                _optionDropdown(
                  label: 'Business unit *',
                  value: _businessUnitId,
                  options: metadata.businessUnits,
                  onChanged: (value) => setState(() => _businessUnitId = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'active'),
                ),
              ]),
              const SizedBox(height: 20),
              Card(
                color: VistoraColors.cyan.withValues(alpha: .07),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Optional GPS boundary',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _locating ? null : _captureCoordinates,
                            icon: _locating
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: const Text('Use current'),
                          ),
                        ],
                      ),
                      const Text(
                        'If all three values are set, reports can only be submitted from inside this radius. Without them, GPS is recorded but not restricted.',
                        style: TextStyle(color: VistoraColors.muted),
                      ),
                      const SizedBox(height: 12),
                      _responsiveFields([
                        TextFormField(
                          controller: _latitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                        ),
                        TextFormField(
                          controller: _longitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                        ),
                        TextFormField(
                          controller: _radius,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Radius (metres)',
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _DialogActions(
                saving: _saving,
                saveLabel: widget.location == null
                    ? 'Add location'
                    : 'Save changes',
                onSave: () => _save(metadata),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _AssignmentEditor extends ConsumerStatefulWidget {
  const _AssignmentEditor({this.assignment});
  final MrAssignment? assignment;

  @override
  ConsumerState<_AssignmentEditor> createState() => _AssignmentEditorState();
}

class _AssignmentEditorState extends ConsumerState<_AssignmentEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _instructions;
  late Future<_AssignmentChoices> _choices;
  int? _employeeId;
  int? _doctorId;
  int? _locationId;
  late DateTime _visitDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignment;
    _employeeId = assignment?.employeeId;
    _doctorId = assignment?.doctorId;
    _locationId = assignment?.locationId;
    _visitDate =
        assignment?.visitDate ?? DateTime.now().add(const Duration(days: 1));
    _instructions = TextEditingController(text: assignment?.instructions);
    _choices = _loadChoices();
  }

  Future<_AssignmentChoices> _loadChoices() async {
    final repository = ref.read(mrRepositoryProvider);
    final results = await Future.wait<Object>([
      repository.metadata(),
      repository.doctors(status: 'active', perPage: 100),
    ]);
    return _AssignmentChoices(
      metadata: results[0] as MrMetadata,
      doctors: (results[1] as MrPage<MrDoctor>).items,
    );
  }

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (value != null && mounted) setState(() => _visitDate = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_employeeId == null || _doctorId == null || _locationId == null) {
      _showError(context, 'Select an employee, doctor and mapped location.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(mrRepositoryProvider)
          .saveAssignment(
            id: widget.assignment?.id,
            data: {
              'employee_id': _employeeId,
              'doctor_id': _doctorId,
              'location_id': _locationId,
              'visit_date': DateFormat('yyyy-MM-dd').format(_visitDate),
              'instructions': _nullable(_instructions.text),
            },
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    title: widget.assignment == null
        ? 'Assign doctor visit'
        : 'Edit visit assignment',
    subtitle: 'Choose a team member, doctor and one mapped location',
    icon: Icons.assignment_add,
    child: FutureBuilder<_AssignmentChoices>(
      future: _choices,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _InlineError(
            error: snapshot.error!,
            onRetry: () => setState(() => _choices = _loadChoices()),
          );
        }
        final choices = snapshot.requireData;
        final selectedDoctor = choices.doctors
            .where((item) => item.id == _doctorId)
            .firstOrNull;
        final mappedLocations =
            selectedDoctor?.locations
                .where((item) => item.status == 'active')
                .toList() ??
            const <MrLocation>[];
        if (mappedLocations.length == 1 &&
            _locationId != mappedLocations.first.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _locationId = mappedLocations.first.id);
          });
        }
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => DropdownMenu<int>(
                  width: constraints.maxWidth,
                  initialSelection: _employeeId,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.person_search_outlined),
                  label: const Text('Search employee name or ID *'),
                  dropdownMenuEntries: choices.metadata.employees
                      .map(
                        (item) => DropdownMenuEntry(
                          value: item.id,
                          label: '${item.name} (${item.code ?? 'Employee'})',
                        ),
                      )
                      .toList(),
                  onSelected: (value) => setState(() => _employeeId = value),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) => DropdownMenu<int>(
                  width: constraints.maxWidth,
                  initialSelection: _doctorId,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.medical_services_outlined),
                  label: const Text('Search doctor *'),
                  dropdownMenuEntries: choices.doctors
                      .map(
                        (item) => DropdownMenuEntry(
                          value: item.id,
                          label:
                              '${item.name}${item.specialization == null ? '' : ' • ${item.specialization}'}',
                        ),
                      )
                      .toList(),
                  onSelected: (value) => setState(() {
                    _doctorId = value;
                    final doctor = choices.doctors
                        .where((item) => item.id == value)
                        .firstOrNull;
                    final mapped =
                        doctor?.locations
                            .where((item) => item.status == 'active')
                            .toList() ??
                        const <MrLocation>[];
                    _locationId = mapped.length == 1 ? mapped.first.id : null;
                  }),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue:
                    mappedLocations.any((item) => item.id == _locationId)
                    ? _locationId
                    : null,
                decoration: InputDecoration(
                  labelText: 'Doctor location *',
                  prefixIcon: const Icon(Icons.place_outlined),
                  helperText: selectedDoctor == null
                      ? 'Select a doctor first.'
                      : mappedLocations.isEmpty
                      ? 'This doctor has no active mapped location.'
                      : mappedLocations.length == 1
                      ? 'The only mapped location is selected automatically.'
                      : 'Choose one of ${mappedLocations.length} mapped locations.',
                ),
                items: mappedLocations
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.address,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: mappedLocations.isEmpty
                    ? null
                    : (value) => setState(() => _locationId = value),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Visit date *',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(DateFormat.yMMMMd().format(_visitDate)),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _instructions,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              _DialogActions(
                saving: _saving,
                saveLabel: widget.assignment == null
                    ? 'Assign visit'
                    : 'Save assignment',
                onSave: _save,
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _AssignmentChoices {
  const _AssignmentChoices({required this.metadata, required this.doctors});
  final MrMetadata metadata;
  final List<MrDoctor> doctors;
}

class _ReportEditor extends ConsumerStatefulWidget {
  const _ReportEditor({required this.assignment});
  final MrAssignment assignment;

  @override
  ConsumerState<_ReportEditor> createState() => _ReportEditorState();
}

class _ReportEditorState extends ConsumerState<_ReportEditor> {
  late final TextEditingController _description;
  late final TextEditingController _outcome;
  late final TextEditingController _address;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.assignment.report?.notes);
    _outcome = TextEditingController(text: widget.assignment.report?.outcome);
    _address = TextEditingController(
      text: widget.assignment.report?.capturedAddress,
    );
    _latitude = widget.assignment.report?.latitude;
    _longitude = widget.assignment.report?.longitude;
    _accuracy = widget.assignment.report?.accuracyMeters;
  }

  @override
  void dispose() {
    _description.dispose();
    _outcome.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _locating = true);
    try {
      final position = await const LocationService().currentPosition();
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _accuracy = position.accuracy;
        });
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save({required bool submit}) async {
    if (submit &&
        _description.text.trim().isEmpty &&
        _outcome.text.trim().isEmpty) {
      _showError(
        context,
        'Add a visit description or outcome before submitting.',
      );
      return;
    }
    if (widget.assignment.geofenceRequired && !_hasPosition) {
      _showError(
        context,
        'Capture your current GPS location before submitting this geofenced visit.',
      );
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'visited_at': DateTime.now().toUtc().toIso8601String(),
      'check_in_source': _hasPosition ? 'gps' : 'manual',
      'captured_address': _nullable(_address.text),
      'notes': _nullable(_description.text),
      'outcome': _nullable(_outcome.text),
      if (_hasPosition) ...{
        'latitude': _latitude,
        'longitude': _longitude,
        'location_accuracy_meters': _accuracy,
      },
    };
    try {
      final repository = ref.read(mrRepositoryProvider);
      if (submit) {
        await repository.saveAndSubmitReport(
          assignmentId: widget.assignment.id,
          reportId: widget.assignment.report?.id,
          data: data,
        );
      } else {
        await repository.saveReport(
          assignmentId: widget.assignment.id,
          reportId: widget.assignment.report?.id,
          data: data,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.assignment.location;
    return _DialogFrame(
      title: 'Visit report',
      subtitle:
          '${widget.assignment.doctorName ?? 'Doctor'} • ${DateFormat.yMMMd().format(widget.assignment.visitDate)}',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color:
                (widget.assignment.geofenceRequired
                        ? VistoraColors.amber
                        : VistoraColors.cyan)
                    .withValues(alpha: .08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.address,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.assignment.geofenceRequired
                        ? 'GPS restricted • submit within ${location.radiusMeters} metres of the doctor location.'
                        : 'No geofence restriction • capture GPS when available; manual fallback is allowed.',
                    style: TextStyle(
                      color: widget.assignment.geofenceRequired
                          ? VistoraColors.amber
                          : VistoraColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _locating ? null : _capture,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              !_hasPosition
                  ? 'Capture current location'
                  : 'Location captured • ${(_accuracy ?? 0).toStringAsFixed(0)} m accuracy',
            ),
          ),
          if (_hasPosition) ...[
            const SizedBox(height: 8),
            Text(
              '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VistoraColors.green),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Captured/current address (optional)',
              prefixIcon: Icon(Icons.pin_drop_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Visit description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _outcome,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Outcome / next action',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(submit: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save draft'),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(submit: true),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Submit report'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasPosition => _latitude != null && _longitude != null;
}

class _NotesDialog extends StatefulWidget {
  const _NotesDialog({
    required this.title,
    required this.label,
    required this.actionLabel,
    this.initialValue,
  });
  final String title;
  final String label;
  final String actionLabel;
  final String? initialValue;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    title: widget.title,
    subtitle: 'This note is preserved in the MR audit trail.',
    icon: Icons.history_edu_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          decoration: InputDecoration(
            labelText: widget.label,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final value = _controller.text.trim();
                if (value.isEmpty) {
                  _showError(context, 'A note is required.');
                  return;
                }
                Navigator.pop(context, value);
              },
              child: Text(widget.actionLabel),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.saving,
    required this.saveLabel,
    required this.onSave,
  });
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 10,
    runSpacing: 10,
    children: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: saving ? null : onSave,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: Text(saveLabel),
      ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.error,
          size: 38,
        ),
        const SizedBox(height: 10),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .025),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: VistoraColors.muted),
    ),
  );
}

Widget _responsiveFields(List<Widget> children) => LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth >= 640
        ? (constraints.maxWidth - 12) / 2
        : constraints.maxWidth;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map((child) => SizedBox(width: width, child: child))
          .toList(),
    );
  },
);

Widget _optionDropdown({
  required String label,
  required int? value,
  required List<MrOption> options,
  required ValueChanged<int?> onChanged,
}) => DropdownButtonFormField<int>(
  initialValue: options.any((item) => item.id == value) ? value : null,
  decoration: InputDecoration(labelText: label),
  isExpanded: true,
  items: options
      .map(
        (item) => DropdownMenuItem(
          value: item.id,
          child: Text(item.name, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(),
  onChanged: onChanged,
);

String _locationMeta(MrLocation location) {
  final organisation = [
    location.stateName,
    location.branchName,
    location.businessUnitName,
  ].whereType<String>().where((item) => item.isNotEmpty).join(' • ');
  final geo = location.hasGeofence
      ? '${location.radiusMeters} m geofence'
      : location.hasCoordinates
      ? 'GPS point • no radius'
      : 'No GPS restriction';
  return [
    if ((location.city ?? '').isNotEmpty) location.city!,
    if (organisation.isNotEmpty) organisation,
    geo,
  ].join('\n');
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
double? _number(String value) =>
    value.trim().isEmpty ? null : double.tryParse(value.trim());

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}
