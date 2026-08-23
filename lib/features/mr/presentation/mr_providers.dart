import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/mr/data/mr_repository.dart';
import 'package:vistora_mobile/features/mr/domain/mr_models.dart';

final mrRepositoryProvider = Provider<MrRepository>(
  (ref) => MrRepository(ref.watch(apiClientProvider)),
);
final mrMetadataProvider = FutureProvider<MrMetadata>(
  (ref) => ref.watch(mrRepositoryProvider).metadata(),
);
final mrSettingsProvider = FutureProvider<MrSettings>(
  (ref) => ref.watch(mrRepositoryProvider).settings(),
);
final mrDoctorsProvider = FutureProvider<List<MrDoctor>>(
  (ref) async =>
      (await ref.watch(mrRepositoryProvider).doctors(perPage: 100)).items,
);
final mrLocationsProvider = FutureProvider<List<MrLocation>>(
  (ref) async =>
      (await ref.watch(mrRepositoryProvider).locations(perPage: 100)).items,
);
final mrTerritoriesProvider = FutureProvider<List<MrTerritory>>(
  (ref) async =>
      (await ref.watch(mrRepositoryProvider).territories(perPage: 100)).items,
);

void invalidateMr(WidgetRef ref) {
  ref.invalidate(mrMetadataProvider);
  ref.invalidate(mrSettingsProvider);
  ref.invalidate(mrDoctorsProvider);
  ref.invalidate(mrLocationsProvider);
  ref.invalidate(mrTerritoriesProvider);
}
