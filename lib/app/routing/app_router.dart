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
import 'package:vistora_mobile/features/employees/presentation/employee_management_screen.dart';
import 'package:vistora_mobile/features/file_manager/presentation/file_manager_screen.dart';
import 'package:vistora_mobile/features/finance_hub/presentation/finance_hub_screen.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_screen.dart';
import 'package:vistora_mobile/features/holidays/presentation/holidays_screen.dart';
import 'package:vistora_mobile/features/hr_operations/presentation/hr_operations_screen.dart';
import 'package:vistora_mobile/features/mr/presentation/mr_screen.dart';
import 'package:vistora_mobile/features/payslips/presentation/payslips_screen.dart';
import 'package:vistora_mobile/features/payroll/presentation/payroll_admin_screen.dart';
import 'package:vistora_mobile/features/platform_admin/presentation/platform_admin_screen.dart';
import 'package:vistora_mobile/features/profile/presentation/profile_screen.dart';
import 'package:vistora_mobile/features/salary/presentation/salary_management_screen.dart';
import 'package:vistora_mobile/features/tenant_settings/presentation/tenant_settings_screen.dart';
import 'package:vistora_mobile/features/tax_invoices/presentation/tax_invoices_screen.dart';
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
          path == '/finance-hub' &&
          (auth.session?.features.financeHub != true ||
              !const {
                'admin',
                'hr',
              }.contains(auth.session?.user.normalizedRole))) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/payroll-admin' &&
          !const {'admin', 'hr'}.contains(auth.session?.user.normalizedRole)) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/hr-operations' &&
          !const {'admin', 'hr'}.contains(auth.session?.user.normalizedRole)) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/file-manager' &&
          (auth.session?.features.fileManager != true ||
              !const {
                'admin',
                'hr',
                'superadmin',
              }.contains(auth.session?.user.normalizedRole))) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path.startsWith('/platform') &&
          auth.session?.user.normalizedRole != 'superadmin') {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/company-settings' &&
          !const {'admin', 'hr'}.contains(auth.session?.user.normalizedRole)) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/employees' &&
          !const {'admin', 'hr'}.contains(auth.session?.user.normalizedRole)) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/salary-structures' &&
          !const {'admin', 'hr'}.contains(auth.session?.user.normalizedRole)) {
        return '/dashboard';
      }
      if (auth.status == AuthStatus.authenticated &&
          path == '/tax-invoices' &&
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
            builder: (context, state) => TeamAttendanceScreen(
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeeManagementScreen(),
          ),
          GoRoute(
            path: '/salary-structures',
            builder: (context, state) => SalaryManagementScreen(
              initialQuery: state.uri.queryParameters['q'],
            ),
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
          GoRoute(
            path: '/hr-operations',
            builder: (context, state) => const HrOperationsScreen(),
          ),
          GoRoute(
            path: '/file-manager',
            builder: (context, state) => const FileManagerScreen(),
          ),
          GoRoute(
            path: '/company-settings',
            builder: (context, state) => const TenantSettingsScreen(),
          ),
          GoRoute(
            path: '/tax-invoices',
            builder: (context, state) => const TaxInvoicesScreen(),
          ),
          GoRoute(path: '/mr', builder: (context, state) => const MrScreen()),
          GoRoute(
            path: '/finance-hub',
            builder: (context, state) => const FinanceHubScreen(),
          ),
          GoRoute(
            path: '/platform',
            builder: (context, state) => const PlatformAdminScreen(),
          ),
          GoRoute(
            path: '/platform/companies',
            builder: (context, state) =>
                const PlatformAdminScreen(initialIndex: 1),
          ),
          GoRoute(
            path: '/platform/payments',
            builder: (context, state) =>
                const PlatformAdminScreen(initialIndex: 2),
          ),
          GoRoute(
            path: '/platform/onboarding',
            builder: (context, state) =>
                const PlatformAdminScreen(initialIndex: 3),
          ),
          GoRoute(
            path: '/platform/settings',
            builder: (context, state) =>
                const PlatformAdminScreen(initialIndex: 4),
          ),
          GoRoute(
            path: '/projects',
            builder: (context, state) =>
                const EmployeeWorkScreen(initialIndex: 0),
          ),
          GoRoute(
            path: '/interviews',
            builder: (context, state) {
              final session = ref.read(authControllerProvider).session!;
              if (session.user.isCompanyManager) {
                return const HrOperationsScreen();
              }
              return EmployeeWorkScreen(
                initialIndex: session.features.projects ? 1 : 0,
              );
            },
          ),
        ],
      ),
    ],
  );
});
