import 'dart:io';

enum AppEnvironmentName { local, staging, production }

class AppEnvironment {
  const AppEnvironment({required this.name, required this.apiBaseUrl});

  final AppEnvironmentName name;
  final String apiBaseUrl;

  static AppEnvironment get current {
    const environment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    final name = AppEnvironmentName.values.firstWhere(
      (value) => value.name == environment,
      orElse: () => AppEnvironmentName.local,
    );
    final defaultUrl = Platform.isAndroid
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://127.0.0.1:8000/api/v1';

    return AppEnvironment(
      name: name,
      apiBaseUrl: (configuredUrl.isEmpty ? defaultUrl : configuredUrl)
          .replaceFirst(RegExp(r'/$'), ''),
    );
  }

  bool get isProduction => name == AppEnvironmentName.production;
}
