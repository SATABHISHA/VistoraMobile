import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/core/widgets/status_badge.dart';
import 'package:vistora_mobile/features/attendance/domain/attendance_models.dart';
import 'package:vistora_mobile/features/attendance/presentation/attendance_providers.dart';
import 'package:vistora_mobile/features/attendance/presentation/team_attendance_screen.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late DateTime _month;
  bool _punching = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  Future<void> _refresh() async {
    ref.invalidate(todayAttendanceProvider);
    ref.invalidate(
      attendanceCalendarProvider(AttendanceMonth(_month.year, _month.month)),
    );
    await ref.read(todayAttendanceProvider.future);
  }

  Future<void> _punch(TodayAttendance today) async {
    final clockIn = today.canClockIn;
    final action = clockIn ? 'clock in' : 'clock out';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${clockIn ? 'Clock In' : 'Clock Out'}'),
        content: Text(
          today.geofence.enabled
              ? 'Your current location will be sent securely to Vistora for server-side geofence validation.'
              : 'Record your attendance now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(clockIn ? 'Clock In' : 'Clock Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _punching = true);
    try {
      double? latitude;
      double? longitude;
      double? accuracy;
      if (today.geofence.enabled) {
        final position = await ref
            .read(locationServiceProvider)
            .currentPosition();
        latitude = position.latitude;
        longitude = position.longitude;
        accuracy = position.accuracy;
      }
      await ref
          .read(attendanceRepositoryProvider)
          .punch(
            clockIn: clockIn,
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: accuracy,
          );
      ref.invalidate(todayAttendanceProvider);
      ref.invalidate(
        attendanceCalendarProvider(AttendanceMonth(_month.year, _month.month)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance $action recorded successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _punching = false);
    }
  }

  Future<void> _regularize(AttendanceDay day) async {
    if (day.id == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RegularizationDialog(),
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .regularize(attendanceId: day.id!, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regularization request submitted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).session?.user.normalizedRole;
    if (const {'admin', 'hr', 'superadmin'}.contains(role)) {
      return const TeamAttendanceScreen();
    }
    final today = ref.watch(todayAttendanceProvider);
    final period = AttendanceMonth(_month.year, _month.month);
    final calendar = ref.watch(attendanceCalendarProvider(period));
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              today.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => AsyncErrorCard(
                  error: error,
                  onRetry: () => ref.invalidate(todayAttendanceProvider),
                ),
                data: (value) => _TodayCard(
                  value: value,
                  busy: _punching,
                  onPunch: value.canClockIn || value.canClockOut
                      ? () => _punch(value)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              _MonthHeader(
                month: _month,
                onPrevious: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
              const SizedBox(height: 12),
              calendar.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => AsyncErrorCard(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(attendanceCalendarProvider(period)),
                ),
                data: (value) =>
                    _Calendar(value: value, onRegularize: _regularize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegularizationDialog extends StatefulWidget {
  const _RegularizationDialog();

  @override
  State<_RegularizationDialog> createState() => _RegularizationDialogState();
}

class _RegularizationDialogState extends State<_RegularizationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request regularization'),
      content: TextField(
        controller: _controller,
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Explain what needs to be corrected',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.value, required this.busy, this.onPunch});

  final TodayAttendance value;
  final bool busy;
  final VoidCallback? onPunch;

  @override
  Widget build(BuildContext context) {
    final record = value.attendance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TODAY'S ATTENDANCE",
                    style: TextStyle(
                      color: VistoraColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    record == null
                        ? 'Not clocked in'
                        : record.checkOutAt == null
                        ? 'Working now'
                        : 'Day completed',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'In ${_time(record?.checkInAt)}  •  Out ${_time(record?.checkOutAt)}  •  Worked ${_duration(record?.workedMinutes ?? 0)}',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        value.geofence.enabled
                            ? Icons.location_on_outlined
                            : Icons.location_off_outlined,
                        size: 17,
                        color: VistoraColors.cyan,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          value.geofence.enabled
                              ? 'Company geofence validation enabled'
                              : 'Geofence validation is not required',
                          style: const TextStyle(
                            color: VistoraColors.cyan,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onPunch,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      value.canClockOut
                          ? Icons.logout_outlined
                          : Icons.login_outlined,
                    ),
              label: Text(
                value.canClockIn
                    ? 'Clock In'
                    : value.canClockOut
                    ? 'Clock Out'
                    : 'Attendance Recorded',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime? time) =>
      time == null ? '—' : DateFormat.jm().format(time);
  static String _duration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          DateFormat.yMMMM().format(month),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      IconButton(
        tooltip: 'Previous month',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.value, required this.onRegularize});
  final AttendanceCalendar value;
  final ValueChanged<AttendanceDay> onRegularize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: value.summary.entries
              .where((entry) => entry.value > 0)
              .map((entry) => StatusBadge('${entry.key}: ${entry.value}'))
              .toList(),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 7 : 2;
            final cardWidth =
                (constraints.maxWidth - ((columns - 1) * 8)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: value.days.map((day) {
                final hasTiming =
                    day.checkInAt != null ||
                    day.checkOutAt != null ||
                    day.workedMinutes > 0;
                return SizedBox(
                  width: cardWidth,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: day.id == null ? null : () => onRegularize(day),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${day.day}  ${day.weekday}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            StatusBadge(day.status ?? 'upcoming'),
                            if (day.leaveName != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                day.leaveName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                            if (hasTiming) ...[
                              const SizedBox(height: 8),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                                tween: Tween(begin: 0, end: 1),
                                builder: (context, value, child) => Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 8 * (1 - value)),
                                    child: child,
                                  ),
                                ),
                                child: _DayTiming(day: day),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _DayTiming extends StatelessWidget {
  const _DayTiming({required this.day});

  final AttendanceDay day;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: VistoraColors.cyan.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimingRow(
          icon: Icons.login_outlined,
          label: 'In',
          value: _time(day.checkInAt),
        ),
        const SizedBox(height: 3),
        _TimingRow(
          icon: Icons.logout_outlined,
          label: 'Out',
          value: _time(day.checkOutAt),
        ),
        const SizedBox(height: 4),
        Text(
          'Total ${_duration(day.workedMinutes)}',
          style: const TextStyle(
            color: VistoraColors.green,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  static String _time(DateTime? value) =>
      value == null ? '—' : DateFormat.jm().format(value.toLocal());

  static String _duration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: VistoraColors.cyan),
      const SizedBox(width: 4),
      Text(
        '$label ',
        style: const TextStyle(
          color: VistoraColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}
