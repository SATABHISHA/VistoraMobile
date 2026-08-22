import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/core/widgets/status_badge.dart';
import 'package:vistora_mobile/features/attendance/domain/attendance_models.dart';
import 'package:vistora_mobile/features/attendance/presentation/attendance_providers.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';

class TeamAttendanceScreen extends ConsumerStatefulWidget {
  const TeamAttendanceScreen({super.key});

  @override
  ConsumerState<TeamAttendanceScreen> createState() =>
      _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends ConsumerState<TeamAttendanceScreen> {
  final _search = TextEditingController();
  DateTime _date = DateTime.now();
  late Future<AttendanceRoster> _result;

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<AttendanceRoster> _load() => ref
      .read(attendanceRepositoryProvider)
      .roster(date: _date, query: _search.text);

  Future<void> _refresh() async {
    setState(() => _result = _load());
    await _result;
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
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _refresh(),
                decoration: InputDecoration(
                  labelText: supervisor
                      ? 'Search subordinates'
                      : 'Search employees',
                  hintText: 'Employee name or ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat.yMMMMd().format(_date)),
              ),
              const SizedBox(height: 14),
              FutureBuilder<AttendanceRoster>(
                future: _result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
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
                  final summary = <String, int>{};
                  for (final item in items) {
                    summary.update(
                      item.status,
                      (value) => value + 1,
                      ifAbsent: () => 1,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: summary.entries
                            .map(
                              (entry) => Chip(
                                label: Text(
                                  '${_label(entry.key)} ${entry.value}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        EmptyState(
                          title: supervisor
                              ? 'No subordinate attendance'
                              : 'No employee attendance',
                          message:
                              'No employees match the selected date and search.',
                          icon: Icons.groups_outlined,
                        )
                      else
                        ...items.map(
                          (item) => _RosterCard(
                            item: item,
                            onTap: () => _details(item),
                          ),
                        ),
                    ],
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
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (value != null) {
      setState(() {
        _date = value;
        _result = _load();
      });
    }
  }

  void _details(AttendanceRosterItem item) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _AttendanceDetails(item: item, month: _date),
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.item, required this.onTap});
  final AttendanceRosterItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        backgroundColor: VistoraColors.cyan.withValues(alpha: .14),
        child: Text(_initials(item.employeeName)),
      ),
      title: Text(
        item.employeeName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${item.employeeCode} • ${_time(item.checkInAt)} – ${_time(item.checkOutAt)} • ${_duration(item.workedMinutes)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatusBadge(item.status),
          if (item.isLive)
            const Text(
              'LIVE',
              style: TextStyle(color: VistoraColors.green, fontSize: 10),
            ),
        ],
      ),
    ),
  );
}

class _AttendanceDetails extends ConsumerWidget {
  const _AttendanceDetails({required this.item, required this.month});
  final AttendanceRosterItem item;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .86,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          item.employeeName,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          '${item.employeeCode} • ${item.employeeEmail ?? item.employeeMobile ?? 'No contact details'}',
          style: const TextStyle(color: VistoraColors.muted),
        ),
        const Divider(height: 28),
        _row('Status', _label(item.status)),
        _row('Clock in', _time(item.checkInAt)),
        _row('Clock out', _time(item.checkOutAt)),
        _row('Worked', _duration(item.workedMinutes)),
        _row(
          'Location',
          item.locationAddress ??
              (item.latitude == null
                  ? 'Not available'
                  : '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}'),
        ),
        const SizedBox(height: 20),
        Text(
          '${DateFormat.yMMMM().format(month)} attendance',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        FutureBuilder<AttendanceCalendar>(
          future: ref
              .read(attendanceRepositoryProvider)
              .calendar(
                employeeId: item.employeeId,
                month: month.month,
                year: month.year,
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Text(snapshot.error.toString());
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.data!.days
                  .where((day) => day.status != null)
                  .map(
                    (day) =>
                        Chip(label: Text('${day.day} ${_label(day.status!)}')),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  static Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: VistoraColors.muted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
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
