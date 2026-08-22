import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, required this.auth, super.key});

  final Widget child;
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(auth);
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = destinations.indexWhere(
      (item) =>
          item.route == location ||
          (location == '/my-leave' && item.route == '/leave'),
    );
    final index = selectedIndex < 0 ? 0 : selectedIndex;

    return PopScope<void>(
      canPop: location == '/dashboard',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && location != '/dashboard') {
          context.go('/dashboard');
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) =>
              context.go(destinations[value].route),
          destinations: [
            for (final item in destinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }

  static List<_ShellDestination> _destinations(AuthState auth) {
    final isManager = const {
      'admin',
      'hr',
      'superadmin',
    }.contains(auth.session?.user.normalizedRole);
    final isSupervisor = auth.session?.user.normalizedRole == 'supervisor';
    final items = <_ShellDestination>[
      const _ShellDestination(
        'Home',
        Icons.home_outlined,
        Icons.home,
        '/dashboard',
      ),
    ];
    if (isManager) {
      items.add(
        const _ShellDestination(
          'Attendance',
          Icons.groups_outlined,
          Icons.groups,
          '/attendance',
        ),
      );
      items.add(
        const _ShellDestination(
          'Leave',
          Icons.pending_actions_outlined,
          Icons.pending_actions,
          '/leave',
        ),
      );
      items.add(
        const _ShellDestination(
          'Payroll',
          Icons.payments_outlined,
          Icons.payments,
          '/payroll-admin',
        ),
      );
    } else if (isSupervisor) {
      items.add(
        const _ShellDestination(
          'Attendance',
          Icons.access_time_outlined,
          Icons.access_time_filled,
          '/attendance',
        ),
      );
      items.add(
        const _ShellDestination(
          'Team',
          Icons.groups_outlined,
          Icons.groups,
          '/team-attendance',
        ),
      );
      items.add(
        const _ShellDestination(
          'Leave',
          Icons.pending_actions_outlined,
          Icons.pending_actions,
          '/leave',
        ),
      );
    } else if (auth.session?.employeeId != null) {
      items.add(
        const _ShellDestination(
          'Attendance',
          Icons.access_time_outlined,
          Icons.access_time_filled,
          '/attendance',
        ),
      );
      items.add(
        const _ShellDestination(
          'Leave',
          Icons.beach_access_outlined,
          Icons.beach_access,
          '/leave',
        ),
      );
    }
    if (items.length < 5) {
      items.add(
        const _ShellDestination(
          'Payslips',
          Icons.receipt_long_outlined,
          Icons.receipt_long,
          '/payslips',
        ),
      );
    }
    if (items.length < 5) {
      items.add(
        const _ShellDestination(
          'Profile',
          Icons.person_outline,
          Icons.person,
          '/profile',
        ),
      );
    }
    return items;
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.icon, this.selectedIcon, this.route);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
