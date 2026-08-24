import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/features/attendance/presentation/attendance_providers.dart';
import 'package:vistora_mobile/features/auth/domain/auth_session.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/holidays/presentation/holiday_providers.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_providers.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_providers.dart';

final dashboardPendingLeavesProvider = FutureProvider<int>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  final items = await ref
      .watch(leaveRepositoryProvider)
      .requests(perPage: 100, status: 'pending');
  if (session?.user.normalizedRole != 'supervisor') return items.length;
  return items.where((item) => item.employeeId != session?.employeeId).length;
});

final dashboardUpcomingMrProvider = FutureProvider.autoDispose
    .family<List<MrAssignment>, int>((ref, employeeId) async {
      final page = await ref
          .watch(mrRepositoryProvider)
          .assignments(
            mine: true,
            employeeId: employeeId,
            upcoming: true,
            perPage: 20,
          );
      final limit = DateTime.now().add(const Duration(days: 3));
      return page.items
          .where((item) => !item.visitDate.isAfter(limit))
          .toList();
    });

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session!;
    final role = session.user.normalizedRole;
    final companyManager = const {'admin', 'hr'}.contains(role);
    final managesLeave = companyManager || role == 'supervisor';
    final modules = _modules(session);
    final attendance = session.employeeId == null || companyManager
        ? null
        : ref.watch(todayAttendanceProvider);
    final leave = session.employeeId == null || companyManager
        ? null
        : ref.watch(leaveSummaryProvider);
    final holidays = ref.watch(upcomingHolidaysProvider);
    final pendingLeaves = managesLeave
        ? ref.watch(dashboardPendingLeavesProvider)
        : null;
    final upcomingMr =
        session.features.mr && const {'employee', 'supervisor'}.contains(role)
        ? ref.watch(dashboardUpcomingMrProvider(session.employeeId!))
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VISTORA',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.7),
            ),
            Text(
              session.companyName ?? session.user.corpId ?? 'Platform',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: () {
              ref.invalidate(todayAttendanceProvider);
              ref.invalidate(leaveSummaryProvider);
              if (session.employeeId != null) {
                ref.invalidate(
                  dashboardUpcomingMrProvider(session.employeeId!),
                );
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: 'Profile and security',
            onPressed: () => context.go('/profile'),
            icon: CircleAvatar(child: Text(_initials(session.user.name))),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayAttendanceProvider);
          ref.invalidate(leaveSummaryProvider);
          if (session.employeeId != null) {
            ref.invalidate(dashboardUpcomingMrProvider(session.employeeId!));
          }
          if (session.employeeId != null) {
            await Future.wait([
              ref.read(todayAttendanceProvider.future),
              ref.read(leaveSummaryProvider.future),
            ]);
          }
        },
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(session: session),
              if (session.employeeId != null && !companyManager) ...[
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 680
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: _LiveMetric(
                            title: "Today's attendance",
                            icon: Icons.timer_outlined,
                            color: VistoraColors.cyan,
                            value: attendance?.when(
                              data: (data) => data.attendance == null
                                  ? 'Not clocked in'
                                  : data.attendance!.checkOutAt == null
                                  ? 'Working • ${_duration(data.attendance!.workedMinutes)}'
                                  : 'Completed • ${_duration(data.attendance!.workedMinutes)}',
                              error: (error, _) => error.toString(),
                              loading: () => 'Loading…',
                            ),
                            onTap: () => context.go('/attendance'),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _LiveMetric(
                            title: 'Leave balance',
                            icon: Icons.beach_access_outlined,
                            color: VistoraColors.green,
                            value: leave?.when(
                              data: (data) =>
                                  '${data.remainingTotal} days • ${data.pendingCount} pending',
                              error: (error, _) => error.toString(),
                              loading: () => 'Loading…',
                            ),
                            onTap: () => context.go(
                              role == 'supervisor' ? '/my-leave' : '/leave',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              if (managesLeave) ...[
                const SizedBox(height: 18),
                _LiveMetric(
                  title: role == 'supervisor'
                      ? 'Subordinate leave actions'
                      : 'Pending leave actions',
                  icon: Icons.pending_actions,
                  color: VistoraColors.amber,
                  value: pendingLeaves?.when(
                    data: (count) =>
                        '$count request${count == 1 ? '' : 's'} awaiting action',
                    error: (error, _) => error.toString(),
                    loading: () => 'Loading…',
                  ),
                  onTap: () => context.go('/leave'),
                ),
              ],
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Upcoming holidays',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/holidays'),
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      holidays.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => Text(error.toString()),
                        data: (items) => items.isEmpty
                            ? const Text('No upcoming holidays configured.')
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: items
                                    .take(3)
                                    .map(
                                      (item) => Chip(
                                        avatar: const Icon(
                                          Icons.event,
                                          size: 17,
                                        ),
                                        label: Text(
                                          '${item.name} • ${DateFormat.MMMd().format(item.date)}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (upcomingMr != null) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'MR visits • Next 3 days',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/mr'),
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                        upcomingMr.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text(error.toString()),
                          data: (items) => items.isEmpty
                              ? const Text(
                                  'No MR visits scheduled in the next 3 days.',
                                )
                              : Column(
                                  children: items
                                      .take(5)
                                      .map(
                                        (item) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const CircleAvatar(
                                            child: Icon(
                                              Icons.medical_services_outlined,
                                            ),
                                          ),
                                          title: Text(
                                            item.doctorName ?? 'Doctor visit',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${DateFormat.MMMd().format(item.visitDate)} • ${item.locationAddress ?? 'Location'}',
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                          ),
                                          onTap: () => _showUpcomingMrVisit(
                                            context,
                                            item,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Your workspace',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                      ? 3
                      : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modules.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 2 ? 1.05 : 1.1,
                    ),
                    itemBuilder: (context, index) => _ModuleCard(
                      module: modules[index],
                      onTap: () {
                        final route = modules[index].route;
                        if (route != null) {
                          context.go(route);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${modules[index].label} is not available for this account.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  List<_Module> _modules(AuthSession session) {
    if (session.user.normalizedRole == 'superadmin') {
      return [
        const _Module(
          'Platform',
          Icons.space_dashboard_outlined,
          VistoraColors.orange,
          '/platform',
        ),
        const _Module(
          'Companies',
          Icons.apartment_outlined,
          VistoraColors.cyan,
          '/platform/companies',
        ),
        const _Module(
          'Payments',
          Icons.receipt_long_outlined,
          VistoraColors.green,
          '/platform/payments',
        ),
        const _Module(
          'Onboarding',
          Icons.how_to_reg_outlined,
          VistoraColors.pink,
          '/platform/onboarding',
        ),
        if (session.features.mr)
          const _Module(
            'MR Visits',
            Icons.location_on_outlined,
            VistoraColors.green,
            '/mr',
          ),
      ];
    }
    return [
      _Module(
        'Attendance',
        Icons.event_available_outlined,
        VistoraColors.cyan,
        '/attendance',
      ),
      const _Module(
        'Leave',
        Icons.beach_access_outlined,
        VistoraColors.green,
        '/leave',
      ),
      const _Module(
        'Payslips',
        Icons.payments_outlined,
        VistoraColors.amber,
        '/payslips',
      ),
      if (const {'admin', 'hr'}.contains(session.user.normalizedRole))
        const _Module(
          'Payroll Admin',
          Icons.calculate_outlined,
          VistoraColors.orange,
          '/payroll-admin',
        ),
      if (const {'admin', 'hr'}.contains(session.user.normalizedRole))
        const _Module(
          'Salary Structures',
          Icons.account_balance_wallet_outlined,
          VistoraColors.green,
          '/salary-structures',
        ),
      const _Module(
        'Holidays',
        Icons.calendar_month_outlined,
        VistoraColors.pink,
        '/holidays',
      ),
      if (session.user.isCompanyManager || session.user.isSupervisor)
        _Module(
          session.user.isSupervisor ? 'Subordinate Employees' : 'Employees',
          Icons.groups_outlined,
          VistoraColors.pink,
          session.user.isSupervisor ? '/team-attendance' : '/employees',
        ),
      if (session.features.projects)
        const _Module(
          'Projects',
          Icons.work_outline,
          VistoraColors.orange,
          '/projects',
        ),
      const _Module(
        'Interviews',
        Icons.record_voice_over_outlined,
        VistoraColors.pink,
        '/interviews',
      ),
      if (session.features.mr)
        const _Module(
          'MR Visits',
          Icons.location_on_outlined,
          VistoraColors.green,
          '/mr',
        ),
      if (session.user.isCompanyManager)
        const _Module(
          'HR Workspace',
          Icons.admin_panel_settings_outlined,
          VistoraColors.pink,
          '/hr-operations',
        ),
      if (session.features.fileManager && session.user.isCompanyManager)
        const _Module(
          'Secure Files',
          Icons.folder_copy_outlined,
          VistoraColors.cyan,
          '/file-manager',
        ),
      if (session.user.isCompanyManager)
        const _Module(
          'Company Settings',
          Icons.settings_outlined,
          VistoraColors.orange,
          '/company-settings',
        ),
    ];
  }

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  static String _duration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sign out',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) => AlertDialog(
        icon: const Icon(Icons.logout, color: VistoraColors.orange, size: 34),
        title: const Text('Sign out of Vistora?'),
        content: const Text(
          'Your secure session will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .88, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

Future<void> _showUpcomingMrVisit(
  BuildContext context,
  MrAssignment assignment,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close visit details',
  barrierColor: Colors.black.withValues(alpha: .72),
  transitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (context, _, _) => SafeArea(
    child: Dialog(
      insetPadding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x33FF6A00), Color(0x2200D2FF)],
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x2200D2FF),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: VistoraColors.cyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.doctorName ?? 'Doctor visit',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          if ((assignment.doctorSpecialization ?? '')
                              .isNotEmpty)
                            Text(
                              assignment.doctorSpecialization!,
                              style: const TextStyle(
                                color: VistoraColors.muted,
                              ),
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
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MrDashboardDetail(
                      icon: Icons.event_outlined,
                      title: 'Visit schedule',
                      value: DateFormat.yMMMMEEEEd().format(
                        assignment.visitDate,
                      ),
                    ),
                    _MrDashboardDetail(
                      icon: Icons.place_outlined,
                      title: 'Doctor location',
                      value:
                          assignment.locationAddress ??
                          assignment.location.address,
                    ),
                    _MrDashboardDetail(
                      icon: assignment.geofenceRequired
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      title: 'Location validation',
                      value: assignment.geofenceRequired
                          ? 'Submit within ${assignment.location.radiusMeters} metres of this location.'
                          : 'GPS is captured without a radius restriction.',
                    ),
                    if ((assignment.instructions ?? '').isNotEmpty)
                      _MrDashboardDetail(
                        icon: Icons.notes_outlined,
                        title: 'Instructions',
                        value: assignment.instructions!,
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/mr');
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open MR workspace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween(
        begin: .88,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
      child: child,
    ),
  ),
);

class _MrDashboardDetail extends StatelessWidget {
  const _MrDashboardDetail({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: VistoraColors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(color: VistoraColors.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0x33FF6A00), Color(0x22124ECC), Color(0x2200D2FF)],
      ),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${session.user.name.split(' ').first}',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '${session.user.roleType} workspace • ${session.employeeCode ?? 'Account'} • ${DateFormat.yMMMMd().format(DateTime.now())}',
        ),
      ],
    ),
  );
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color color;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .14),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        value ?? 'Unavailable',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _Module {
  const _Module(this.label, this.icon, this.color, [this.route]);
  final String label;
  final IconData icon;
  final Color color;
  final String? route;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});
  final _Module module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: module.label,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: module.color),
              ),
              const Spacer(),
              Text(
                module.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                module.route == null ? 'Role phase' : 'Open',
                style: const TextStyle(
                  color: VistoraColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
