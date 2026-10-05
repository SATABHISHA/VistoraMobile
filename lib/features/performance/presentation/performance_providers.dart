import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/performance/data/performance_repository.dart';
import 'package:vistora_mobile/features/performance/domain/performance_models.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>(
  (ref) => PerformanceRepository(ref.watch(apiClientProvider)),
);

final performancePageProvider = FutureProvider<PerformancePage>(
  (ref) => ref.watch(performanceRepositoryProvider).page(),
);
