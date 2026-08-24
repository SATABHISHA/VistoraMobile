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
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 360),
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  VistoraColors.cyan.withValues(alpha: .08),
                ),
                dataRowMinHeight: 68,
                dataRowMaxHeight: 78,
                columns: const [
                  DataColumn(label: Text('EMPLOYEE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('CLOCK IN')),
                  DataColumn(label: Text('CLOCK OUT')),
                  DataColumn(label: Text('WORKED')),
                  DataColumn(label: Text('LOCATION')),
                  DataColumn(label: Text('DETAILS')),
                ],
                rows: items.map((item) => _row(context, item)).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, AttendanceRosterItem item) => DataRow(
    onSelectChanged: (_) => onOpen(item),
    cells: [
      DataCell(
        SizedBox(
          width: 210,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: VistoraColors.cyan.withValues(alpha: .12),
                child: Text(
                  _initials(item.employeeName),
                  style: const TextStyle(
                    color: VistoraColors.cyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      item.employeeCode,
                      style: const TextStyle(
                        color: VistoraColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      DataCell(_StatusPill(item.status, live: item.isLive)),
      DataCell(Text(_time(item.checkInAt))),
      DataCell(Text(_time(item.checkOutAt))),
      DataCell(
        Text(
          _duration(item.workedMinutes),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      DataCell(
        SizedBox(
          width: 220,
          child: Text(
            _location(item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      DataCell(
        IconButton.filledTonal(
          tooltip: 'Open monthly attendance',
          onPressed: () => onOpen(item),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
    ],
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
              _DetailMetric('Worked', _duration(widget.item.workedMinutes)),
              SizedBox(
                width: 280,
                child: _DetailMetric('Location', _location(widget.item)),
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
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        VistoraColors.orange.withValues(alpha: .09),
                      ),
                      columns: const [
                        DataColumn(label: Text('DATE')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('CLOCK IN')),
                        DataColumn(label: Text('CLOCK OUT')),
                        DataColumn(label: Text('TOTAL HOURS')),
                      ],
                      rows: calendar.days
                          .map(
                            (day) => DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 115,
                                    child: Text(
                                      DateFormat(
                                        'dd MMM, EEE',
                                      ).format(day.date),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _StatusPill(day.status ?? 'not recorded'),
                                ),
                                DataCell(Text(_time(day.checkInAt))),
                                DataCell(Text(_time(day.checkOutAt))),
                                DataCell(
                                  Text(
                                    _duration(day.workedMinutes),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
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

Color _statusColor(String value) => switch (value.toLowerCase()) {
  'present' || 'working' || 'completed' => VistoraColors.green,
  'absent' || 'not recorded' => VistoraColors.pink,
  'half_day' || 'half day' || 'pending' => VistoraColors.amber,
  'weekoff' || 'week off' || 'holiday' => VistoraColors.cyan,
  'approved' || 'paid_leave' || 'paid leave' => VistoraColors.green,
  _ => VistoraColors.muted,
};

String _location(AttendanceRosterItem item) =>
    item.locationAddress ??
    (item.latitude == null
        ? 'Not available'
        : '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}');

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
