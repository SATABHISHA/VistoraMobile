import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/work/data/employee_work_repository.dart';
import 'package:vistora_mobile/features/work/domain/employee_work_models.dart';

final employeeWorkRepositoryProvider = Provider<EmployeeWorkRepository>(
  (ref) => EmployeeWorkRepository(ref.watch(apiClientProvider)),
);

final employeeProjectsProvider = FutureProvider<List<EmployeeProject>>(
  (ref) => ref.watch(employeeWorkRepositoryProvider).projects(),
);

final employeePerformanceProvider = FutureProvider<List<PerformanceReviewItem>>(
  (ref) => ref
      .watch(employeeWorkRepositoryProvider)
      .performance(
        employeeId: ref.watch(authControllerProvider).session?.employeeId,
      ),
);

final interviewTasksProvider = FutureProvider<List<InterviewTask>>(
  (ref) => ref.watch(employeeWorkRepositoryProvider).interviews(),
);
