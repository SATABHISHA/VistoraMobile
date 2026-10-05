import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/leave/data/leave_repository.dart';
import 'package:vistora_mobile/features/leave/domain/leave_models.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(apiClientProvider)),
);

final leaveSummaryProvider = FutureProvider<LeaveSummary>((ref) {
  ref.watch(authControllerProvider.select((state) => state.session?.user.id));
  return ref.watch(leaveRepositoryProvider).mySummary();
});

final leaveRequestsProvider = FutureProvider<List<LeaveRequestItem>>((ref) {
  ref.watch(authControllerProvider.select((state) => state.session?.user.id));
  return ref.watch(leaveRepositoryProvider).requests();
});
