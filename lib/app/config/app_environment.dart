import 'dart:io';

enum AppEnvironmentName { local, staging, production }

class AppEnvironment {
  /// Production API used by iOS builds launched directly from Xcode.
  static const liveApiBaseUrl = 'https://vistora.ahanova.in/api/v1';

  const AppEnvironment({required this.name, required this.apiBaseUrl});

  final AppEnvironmentName name;
  final String apiBaseUrl;

  static AppEnvironment get current {
    const configuredEnvironment = String.fromEnvironment('APP_ENV');
    final environment = configuredEnvironment.isEmpty && Platform.isIOS
        ? 'production'
        : (configuredEnvironment.isEmpty ? 'local' : configuredEnvironment);
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    final name = AppEnvironmentName.values.firstWhere(
      (value) => value.name == environment,
      orElse: () => AppEnvironmentName.local,
    );
    // iOS devices and simulators cannot use the host loopback address to
    // reach the developer machine. Keep Android's local emulator default,
    // while making an iOS Xcode run immediately usable against production.
    final defaultUrl = Platform.isIOS
        ? liveApiBaseUrl
        : (Platform.isAndroid ? 'http://10.0.2.2:8000/api/v1' : liveApiBaseUrl);

    return AppEnvironment(
      name: name,
      apiBaseUrl: (configuredUrl.isEmpty ? defaultUrl : configuredUrl)
          .replaceFirst(RegExp(r'/$'), ''),
    );
  }

  bool get isProduction => name == AppEnvironmentName.production;
}
