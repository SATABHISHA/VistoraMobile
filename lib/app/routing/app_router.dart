import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vistora_mobile/core/widgets/network_banner.dart';
import 'package:vistora_mobile/app/routing/app_shell.dart';
import 'package:vistora_mobile/features/attendance/presentation/attendance_screen.dart';
import 'package:vistora_mobile/features/attendance/presentation/team_attendance_screen.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:vistora_mobile/features/auth/presentation/login_screen.dart';
import 'package:vistora_mobile/features/auth/presentation/splash_screen.dart';
import 'package:vistora_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_screen.dart';
import 'package:vistora_mobile/features/holidays/presentation/holidays_screen.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_screen.dart';
import 'package:vistora_mobile/features/payslips/presentation/payslips_screen.dart';
import 'package:vistora_mobile/features/payroll/presentation/payroll_admin_screen.dart';
import 'package:vistora_mobile/features/profile/presentation/profile_screen.dart';
import 'package:vistora_mobile/features/work/presentation/employee_work_screen.dart';

final _routerRefreshProvider = Provider<ValueNotifier<AuthStatus>>((ref) {
  final notifier = ValueNotifier(ref.read(authControllerProvider).status);
  ref.listen(authControllerProvider, (previous, next) {
    notifier.value = next.status;
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      final authPath = path == '/login' || path == '/forgot-password';
      if (auth.status == AuthStatus.initializing) {
        return path == '/splash' ? null : '/splash';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return authPath ? null : '/login';
      }
      if (auth.status == AuthStatus.authenticated &&
          (authPath || path == '/splash')) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/projects' &&
          auth.session?.features.projects != true) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/mr' &&
          auth.session?.features.mr != true) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/payroll-admin' &&
          !const {'admin', 'hr'}.contains(auth.session?.user.normalizedRole)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          auth: ref.watch(authControllerProvider),
          child: NetworkBanner(child: child),
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/team-attendance',
            builder: (context, state) => const TeamAttendanceScreen(),
          ),
          GoRoute(
            path: '/leave',
            builder: (context, state) => const LeaveScreen(),
          ),
          GoRoute(
            path: '/my-leave',
            builder: (context, state) => const LeaveScreen(personalMode: true),
          ),
          GoRoute(
            path: '/holidays',
            builder: (context, state) => const HolidaysScreen(),
          ),
          GoRoute(
            path: '/payslips',
            builder: (context, state) => const PayslipsScreen(),
          ),
          GoRoute(
            path: '/payroll-admin',
            builder: (context, state) => const PayrollAdminScreen(),
          ),
          GoRoute(path: '/mr', builder: (context, state) => const MrScreen()),
          GoRoute(
            path: '/projects',
            builder: (context, state) =>
                const EmployeeWorkScreen(initialIndex: 0),
          ),
          GoRoute(
            path: '/performance',
            builder: (context, state) => EmployeeWorkScreen(
              initialIndex:
                  ref.read(authControllerProvider).session?.features.projects ==
                      true
                  ? 1
                  : 0,
            ),
          ),
          GoRoute(
            path: '/interviews',
            builder: (context, state) => EmployeeWorkScreen(
              initialIndex:
                  ref.read(authControllerProvider).session?.features.projects ==
                      true
                  ? 2
                  : 1,
            ),
          ),
        ],
      ),
    ],
  );
});
