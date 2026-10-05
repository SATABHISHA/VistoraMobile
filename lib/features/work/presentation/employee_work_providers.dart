import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/work/data/employee_work_repository.dart';
import 'package:vistora_mobile/features/work/domain/employee_work_models.dart';

final employeeWorkRepositoryProvider = Provider<EmployeeWorkRepository>(
  (ref) => EmployeeWorkRepository(ref.watch(apiClientProvider)),
);

final employeeProjectsProvider = FutureProvider<List<EmployeeProject>>(
  (ref) => ref.watch(employeeWorkRepositoryProvider).projects(),
);

final dashboardAssignedProjectsProvider = FutureProvider.autoDispose
    .family<List<EmployeeProject>, int>((ref, employeeId) async {
      // The API applies the tenant and reporting-tree scope. The employee id
      // only scopes this provider's cache to the signed-in account.
      return ref.watch(employeeWorkRepositoryProvider).projects();
    });

final projectManagementProvider = FutureProvider<ProjectManagementPage>(
  (ref) => ref.watch(employeeWorkRepositoryProvider).projectManagement(),
);

final interviewTasksProvider = FutureProvider<List<InterviewTask>>(
  (ref) => ref.watch(employeeWorkRepositoryProvider).interviews(),
);
