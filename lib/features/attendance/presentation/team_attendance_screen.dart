import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/features/attendance/domain/attendance_models.dart';
import 'package:vistora_mobile/features/attendance/presentation/attendance_providers.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class TeamAttendanceScreen extends ConsumerStatefulWidget {
  const TeamAttendanceScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<TeamAttendanceScreen> createState() =>
      _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends ConsumerState<TeamAttendanceScreen> {
  final search = TextEditingController();
  DateTime date = DateTime.now();
  Timer? debounce;
  late Future<AttendanceRoster> result;

  @override
  void initState() {
    super.initState();
    search.text = widget.initialQuery ?? '';
    result = _load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<AttendanceRoster> _load() => ref
      .read(attendanceRepositoryProvider)
      .roster(date: date, query: search.text);

  Future<void> _refresh() async {
    setState(() => result = _load());
    await result;
  }

  void _searchChanged(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session!;
    final supervisor = session.user.normalizedRole == 'supervisor';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          supervisor ? 'Subordinate Attendance' : 'Employee Attendance',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh attendance',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsiveCenter(
          maxWidth: 1260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AttendanceHero(
                supervisor: supervisor,
                date: date,
                pickDate: _pickDate,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onChanged: _searchChanged,
                onSubmitted: (_) => _refresh(),
                decoration: InputDecoration(
                  labelText: supervisor
                      ? 'Search subordinate attendance'
                      : 'Search employee attendance',
                  hintText: 'Start typing an employee name or ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            search.clear();
                            _refresh();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<AttendanceRoster>(
                future: result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(55),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return AsyncErrorCard(
                      error: snapshot.error!,
                      onRetry: _refresh,
                    );
                  }
                  final currentId = session.employeeId;
                  final roster = snapshot.data!;
                  final items = supervisor
                      ? roster.items
                            .where((item) => item.employeeId != currentId)
                            .toList()
                      : roster.items;
                  return _RosterContent(
                    items: items,
                    supervisor: supervisor,
                    onOpen: _details,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (value != null) {
      setState(() {
        date = value;
        result = _load();
      });
    }
  }

  void _details(AttendanceRosterItem item) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _AttendanceDetails(item: item, initialMonth: date),
    );
  }
}

class _AttendanceHero extends StatelessWidget {
  const _AttendanceHero({
    required this.supervisor,
    required this.date,
    required this.pickDate,
  });

  final bool supervisor;
  final DateTime date;
  final VoidCallback pickDate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B201D), Color(0xFF082C43)],
      ),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .22)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 27,
          backgroundColor: Color(0x2200D2FF),
          child: Icon(Icons.groups_outlined, color: VistoraColors.cyan),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                supervisor ? 'Your team today' : 'Company attendance',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat.yMMMMEEEEd().format(date),
                style: const TextStyle(color: VistoraColors.muted),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Choose date',
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      ],
    ),
  );
}

class _RosterContent extends StatelessWidget {
  const _RosterContent({
    required this.items,
    required this.supervisor,
    required this.onOpen,
  });

  final List<AttendanceRosterItem> items;
  final bool supervisor;
  final ValueChanged<AttendanceRosterItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        title: supervisor
            ? 'No subordinate attendance'
            : 'No employee attendance',
        message: 'No employees match the selected date and search.',
        icon: Icons.groups_outlined,
      );
    }
    final summary = <String, int>{};
    for (final item in items) {
      summary.update(item.status, (value) => value + 1, ifAbsent: () => 1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _SummaryChip(
              label: 'Employees',
              value: items.length,
              color: VistoraColors.cyan,
            ),
            for (final entry in summary.entries)
              _SummaryChip(
                label: _label(entry.key),
                value: entry.value,
                color: _statusColor(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              _RosterAttendanceCard(item: item, onTap: () => onOpen(item)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _RosterAttendanceCard extends StatelessWidget {
  const _RosterAttendanceCard({required this.item, required this.onTap});

  final AttendanceRosterItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    return Card(
      margin: EdgeInsets.zero,
      color: VistoraColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFF29334D)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF18223A),
                Color(0xFF11182B),
                VistoraColors.surface,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withValues(alpha: .14),
                    child: Text(
                      _initials(item.employeeName),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.employeeName,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (item.employeeCode.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.employeeCode,
                              style: const TextStyle(
                                color: VistoraColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(item.status, live: item.isLive),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AttendanceFact(
                    icon: Icons.login_rounded,
                    label: 'Clock in',
                    value: _time(item.checkInAt),
                    color: VistoraColors.cyan,
                  ),
                  _AttendanceFact(
                    icon: Icons.logout_rounded,
                    label: 'Clock out',
                    value: _time(item.checkOutAt),
                    color: VistoraColors.orange,
                  ),
                  if (item.canViewWorkedHours)
                    _AttendanceFact(
                      icon: Icons.timelapse_rounded,
                      label: 'Worked',
                      value: _duration(item.workedMinutes),
                      color: VistoraColors.green,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 17,
                    color: VistoraColors.muted,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Tap to view attendance details',
                      style: TextStyle(
                        color: VistoraColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: VistoraColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceFact extends StatelessWidget {
  const _AttendanceFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 104),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color.withValues(alpha: .9),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              softWrap: true,
              style: const TextStyle(
                color: VistoraColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AttendanceDetails extends ConsumerStatefulWidget {
  const _AttendanceDetails({required this.item, required this.initialMonth});
  final AttendanceRosterItem item;
  final DateTime initialMonth;

  @override
  ConsumerState<_AttendanceDetails> createState() => _AttendanceDetailsState();
}

class _AttendanceDetailsState extends ConsumerState<_AttendanceDetails> {
  late DateTime month;
  late Future<AttendanceCalendar> future;

  @override
  void initState() {
    super.initState();
    month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    future = _load();
  }

  Future<AttendanceCalendar> _load() => ref
      .read(attendanceRepositoryProvider)
      .calendar(
        employeeId: widget.item.employeeId,
        month: month.month,
        year: month.year,
      );

  void _move(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .92,
    minChildSize: .58,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: VistoraColors.orange.withValues(alpha: .14),
              child: Text(
                _initials(widget.item.employeeName),
                style: const TextStyle(
                  color: VistoraColors.orange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.employeeName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${widget.item.employeeCode} • ${widget.item.employeeEmail ?? widget.item.employeeMobile ?? 'No contact details'}',
                    style: const TextStyle(color: VistoraColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF3B201D), Color(0xFF082C43)],
            ),
          ),
          child: Wrap(
            spacing: 22,
            runSpacing: 13,
            children: [
              _DetailMetric('Status', _label(widget.item.status)),
              _DetailMetric('Clock in', _time(widget.item.checkInAt)),
              _DetailMetric('Clock out', _time(widget.item.checkOutAt)),
              if (widget.item.canViewWorkedHours)
                _DetailMetric('Worked', _duration(widget.item.workedMinutes)),
              SizedBox(
                width: 300,
                child: _PunchLocationLine(
                  label: 'Clock-in location / address',
                  latitude: widget.item.latitude,
                  longitude: widget.item.longitude,
                  address: widget.item.locationAddress,
                ),
              ),
              SizedBox(
                width: 300,
                child: _PunchLocationLine(
                  label: 'Clock-out location / address',
                  latitude: widget.item.checkOutLatitude,
                  longitude: widget.item.checkOutLongitude,
                  address: widget.item.checkOutLocationAddress,
                  muted: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${DateFormat.yMMMM().format(month)} attendance',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<AttendanceCalendar>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(45),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return AsyncErrorCard(
                error: snapshot.error!,
                onRetry: () => setState(() => future = _load()),
              );
            }
            final calendar = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: calendar.summary.entries
                      .map(
                        (entry) => _SummaryChip(
                          label: _label(entry.key),
                          value: entry.value,
                          color: _statusColor(entry.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in calendar.days) ...[
                      _AttendanceDayCard(day: day),
                      const SizedBox(height: 9),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _AttendanceDayCard extends StatelessWidget {
  const _AttendanceDayCard({required this.day});

  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final status = day.status ?? 'not recorded';
    final color = _statusColor(status);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: color.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, dd MMM yyyy').format(day.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      if (day.leaveName?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          day.leaveName!,
                          style: const TextStyle(
                            color: VistoraColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AttendanceFact(
                  icon: Icons.login_rounded,
                  label: 'Clock in',
                  value: _time(day.checkInAt),
                  color: VistoraColors.cyan,
                ),
                _AttendanceFact(
                  icon: Icons.logout_rounded,
                  label: 'Clock out',
                  value: _time(day.checkOutAt),
                  color: VistoraColors.orange,
                ),
                if (day.canViewWorkedHours)
                  _AttendanceFact(
                    icon: Icons.timelapse_rounded,
                    label: 'Worked',
                    value: _duration(day.workedMinutes),
                    color: VistoraColors.green,
                  ),
              ],
            ),
            if (day.latitude != null ||
                day.longitude != null ||
                day.locationAddress?.trim().isNotEmpty == true ||
                day.checkOutLatitude != null ||
                day.checkOutLongitude != null ||
                day.checkOutLocationAddress?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Divider(color: VistoraColors.muted.withValues(alpha: .18)),
              _PunchLocationLine(
                label: 'Clock-in location / address',
                latitude: day.latitude,
                longitude: day.longitude,
                address: day.locationAddress,
              ),
              const SizedBox(height: 8),
              _PunchLocationLine(
                label: 'Clock-out location / address',
                latitude: day.checkOutLatitude,
                longitude: day.checkOutLongitude,
                address: day.checkOutLocationAddress,
                muted: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status, {this.live = false});
  final String status;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: VistoraColors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            _label(status).toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
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
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _PunchLocationLine extends StatelessWidget {
  const _PunchLocationLine({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.muted = false,
  });

  final String label;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address?.trim().isNotEmpty == true;
    final hasCoordinates = _hasValidCoordinates(latitude, longitude);
    final color = muted ? VistoraColors.muted : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: _punchLocation(latitude, longitude, address)),
            ],
          ),
          softWrap: true,
          style: TextStyle(color: color, fontSize: muted ? 11 : 12),
        ),
        if (!hasAddress && hasCoordinates)
          TextButton.icon(
            onPressed: () =>
                _openCoordinatesInMap(context, latitude!, longitude!),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.map_outlined, size: 15),
            label: const Text('Open in map', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}

bool _hasValidCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;

Future<void> _openCoordinatesInMap(
  BuildContext context,
  double latitude,
  double longitude,
) async {
  if (!_hasValidCoordinates(latitude, longitude)) return;
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
  });

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the map for this location.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the map for this location.'),
        ),
      );
    }
  }
}

Color _statusColor(String value) => switch (value.toLowerCase()) {
  'present' || 'working' || 'completed' => VistoraColors.green,
  'absent' || 'not recorded' => VistoraColors.pink,
  'half_day' || 'half day' || 'pending' => VistoraColors.amber,
  'weekoff' || 'week off' || 'holiday' => VistoraColors.cyan,
  'approved' || 'paid_leave' || 'paid leave' => VistoraColors.green,
  _ => VistoraColors.muted,
};

String _punchLocation(double? latitude, double? longitude, String? address) {
  if (address?.trim().isNotEmpty == true) return address!.trim();
  if (latitude == null || longitude == null) return 'Not captured';
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} · address not available';
}

String _time(DateTime? value) =>
    value == null ? '—' : DateFormat.jm().format(value);
String _duration(int minutes) => '${minutes ~/ 60}h ${minutes.remainder(60)}m';
String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
