import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/config/app_environment.dart';
import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/storage/token_storage.dart';
import 'package:vistora_mobile/features/auth/data/auth_repository.dart';

final environmentProvider = Provider<AppEnvironment>(
  (ref) => AppEnvironment.current,
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(environmentProvider).apiBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});
