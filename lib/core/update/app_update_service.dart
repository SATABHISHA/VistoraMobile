import 'dart:async';
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
    this.forceUpdate = false,
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
      forceUpdate: json['force_update'] as bool? ?? false,
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

  bool get hasUpdate {
    final update = manifest;
    if (playUpdateAvailable) return true;
    if (update == null) return false;
    final latestVersion = update.latestVersion.trim();
    final newer =
        latestVersion.isNotEmpty &&
        compareVersions(latestVersion, current.version) > 0;
    final buildNewer =
        update.latestBuild != null &&
        (int.tryParse(current.buildNumber) ?? 0) < update.latestBuild!;
    return newer || buildNewer;
  }

  bool get isRequired {
    if (!hasUpdate) return false;
    final minimum = manifest?.minimumVersion?.trim();
    if (minimum != null &&
        minimum.isNotEmpty &&
        compareVersions(current.version, minimum) < 0) {
      return true;
    }
    return manifest?.forceUpdate ?? false;
  }
}

class AppUpdateService {
  AppUpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );

  final Dio _dio;

  static const manifestUrl = String.fromEnvironment('UPDATE_MANIFEST_URL');
  static const androidStoreUrl = String.fromEnvironment(
    'ANDROID_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=in.ahanova.vistora_mobile',
  );
  static const iosStoreUrl = String.fromEnvironment(
    'IOS_STORE_URL',
    defaultValue: 'https://apps.apple.com/app/id6805299271',
  );
  static const appStoreCountry = String.fromEnvironment(
    'APP_STORE_COUNTRY',
    defaultValue: 'in',
  );
  static const appStoreId = String.fromEnvironment(
    'IOS_APP_STORE_ID',
    defaultValue: '6805299271',
  );

  Future<AppUpdateState> check() async {
    final current = await PackageInfo.fromPlatform();
    AppUpdateManifest? manifest;
    if (manifestUrl.trim().isNotEmpty) {
      try {
        final manifestUri = Uri.parse(manifestUrl);
        final response = await _dio.getUri<Map<String, dynamic>>(
          manifestUri.replace(
            queryParameters: {
              ...manifestUri.queryParameters,
              '_v': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          ),
          options: Options(
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          ),
        );
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
    if (Platform.isAndroid) {
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
      if (appStoreId.trim().isEmpty) return null;
      final response = await _dio.getUri<Map<String, dynamic>>(
        Uri.https('itunes.apple.com', '/lookup', {
          'id': appStoreId,
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
        final result = await InAppUpdate.performImmediateUpdate();
        if (result == AppUpdateResult.success) return true;
      }
      if (info.flexibleUpdateAllowed) {
        return _startFlexibleUpdate();
      }
    } catch (_) {
      // Local APKs and sideloaded builds do not have Play update metadata.
    }
    return false;
  }

  Future<bool> _startFlexibleUpdate() async {
    StreamSubscription<InstallStatus>? subscription;
    try {
      subscription = InAppUpdate.installUpdateListener.listen(
        (status) async {
          if (status == InstallStatus.downloaded) {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (_) {
              // The Play listing remains available if install handoff fails.
            } finally {
              await subscription?.cancel();
            }
          } else if (status == InstallStatus.failed ||
              status == InstallStatus.canceled ||
              status == InstallStatus.installed) {
            await subscription?.cancel();
          }
        },
        onError: (_) {
          subscription?.cancel();
        },
      );
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) return true;
    } catch (_) {
      // If Play cannot start the in-app flow, the caller opens the store page.
    }
    await subscription?.cancel();
    return false;
  }

  Future<bool> openStore(AppUpdateManifest? manifest) async {
    final candidates = Platform.isAndroid
        ? [manifest?.androidUrl, androidStoreUrl]
        : [manifest?.iosUrl, iosStoreUrl];
    final configured = candidates.whereType<String>().firstWhere(
      (url) => url.trim().isNotEmpty,
      orElse: () => '',
    );
    if (configured.isEmpty) return false;
    try {
      return await launchUrl(
        Uri.parse(configured),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
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
