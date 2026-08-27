import 'dart:io';

import 'package:dio/dio.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.latestVersion,
    this.minimumVersion,
    this.latestBuild,
    this.forceUpdate = true,
    this.message = 'A newer version of Vistora is available.',
    this.androidUrl,
    this.iosUrl,
  });

  final String latestVersion;
  final String? minimumVersion;
  final int? latestBuild;
  final bool forceUpdate;
  final String message;
  final String? androidUrl;
  final String? iosUrl;

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    return AppUpdateManifest(
      latestVersion: '${json['latest_version'] ?? json['version'] ?? ''}',
      minimumVersion: json['minimum_version']?.toString(),
      latestBuild: int.tryParse('${json['latest_build'] ?? ''}'),
      forceUpdate: json['force_update'] as bool? ?? true,
      message:
          json['message']?.toString() ??
          'A newer version of Vistora is available.',
      androidUrl: json['android_url']?.toString(),
      iosUrl: json['ios_url']?.toString(),
    );
  }
}

class AppStoreLookupResult {
  const AppStoreLookupResult({
    required this.version,
    required this.trackViewUrl,
  });

  final String version;
  final String trackViewUrl;

  factory AppStoreLookupResult.fromJson(Map<String, dynamic> json) {
    return AppStoreLookupResult(
      version: json['version']?.toString() ?? '',
      trackViewUrl: json['trackViewUrl']?.toString() ?? '',
    );
  }
}

class AppUpdateState {
  const AppUpdateState({
    required this.current,
    this.manifest,
    this.playUpdateAvailable = false,
  });

  final PackageInfo current;
  final AppUpdateManifest? manifest;
  final bool playUpdateAvailable;

  bool get isRequired {
    final update = manifest;
    if (playUpdateAvailable) return true;
    if (update == null || update.latestVersion.trim().isEmpty) return false;
    final newer = compareVersions(update.latestVersion, current.version) > 0;
    final buildNewer =
        update.latestBuild != null &&
        (int.tryParse(current.buildNumber) ?? 0) < update.latestBuild!;
    return newer || buildNewer;
  }
}

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const manifestUrl = String.fromEnvironment('UPDATE_MANIFEST_URL');
  static const androidStoreUrl = String.fromEnvironment('ANDROID_STORE_URL');
  static const iosStoreUrl = String.fromEnvironment('IOS_STORE_URL');
  static const appStoreCountry = String.fromEnvironment(
    'APP_STORE_COUNTRY',
    defaultValue: 'in',
  );

  Future<AppUpdateState> check() async {
    final current = await PackageInfo.fromPlatform();
    AppUpdateManifest? manifest;
    if (manifestUrl.trim().isNotEmpty) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(manifestUrl);
        final data = response.data;
        if (data != null) manifest = AppUpdateManifest.fromJson(data);
      } catch (_) {
        // A failed release manifest must not lock users out of the app.
      }
    }
    if (Platform.isIOS && manifest == null) {
      manifest = await _checkIosAppStore(current);
    }
    var playUpdateAvailable = false;
    if (Platform.isAndroid && manifest == null) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        playUpdateAvailable =
            info.updateAvailability == UpdateAvailability.updateAvailable;
      } catch (_) {
        // Local APKs and devices without Play Store metadata are expected.
      }
    }
    return AppUpdateState(
      current: current,
      manifest: manifest,
      playUpdateAvailable: playUpdateAvailable,
    );
  }

  Future<AppUpdateManifest?> _checkIosAppStore(PackageInfo current) async {
    try {
      final bundleId = current.packageName.trim();
      if (bundleId.isEmpty) return null;
      final response = await _dio.getUri<Map<String, dynamic>>(
        Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': bundleId,
          'country': appStoreCountry,
        }),
      );
      final data = response.data;
      final results = data?['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map<String, dynamic>) return null;
      final appStore = AppStoreLookupResult.fromJson(first);
      if (appStore.version.trim().isEmpty) return null;
      return AppUpdateManifest(
        latestVersion: appStore.version,
        forceUpdate: false,
        message: 'A newer version of Vistora is available on the App Store.',
        iosUrl: appStore.trackViewUrl.isEmpty
            ? iosStoreUrl
            : appStore.trackViewUrl,
      );
    } catch (_) {
      // App Store metadata may be unavailable before first approval or by region.
      return null;
    }
  }

  Future<bool> tryAndroidPlayUpdate() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }
    } catch (_) {
      // Local APKs and sideloaded builds do not have Play update metadata.
    }
    return false;
  }

  Future<bool> openStore(AppUpdateManifest? manifest) async {
    final configured = Platform.isAndroid
        ? (manifest?.androidUrl ?? androidStoreUrl)
        : (manifest?.iosUrl ?? iosStoreUrl);
    if (configured.trim().isEmpty) return false;
    return launchUrl(
      Uri.parse(configured),
      mode: LaunchMode.externalApplication,
    );
  }
}

int compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .take(4)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final a = parts(left);
  final b = parts(right);
  for (var i = 0; i < 4; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}
