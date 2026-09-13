import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/core/update/app_update_service.dart';

void main() {
  group('compareVersions', () {
    test('compares semantic versions', () {
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('1.0.0+2', '1.0.0+1'), greaterThan(0));
      expect(compareVersions('2.0', '2.0.0'), 0);
      expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
    });
  });

  test('parses release manifest', () {
    final manifest = AppUpdateManifest.fromJson({
      'latest_version': '1.2.0',
      'minimum_version': '1.1.0',
      'latest_build': 12,
      'force_update': true,
      'message': 'Update required',
    });
    expect(manifest.latestVersion, '1.2.0');
    expect(manifest.latestBuild, 12);
    expect(manifest.forceUpdate, isTrue);
  });

  group('AppUpdateState', () {
    final current = PackageInfo(
      appName: 'Vistora',
      packageName: 'in.ahanova.vistora_mobile',
      version: '1.0.4',
      buildNumber: '7',
      buildSignature: '',
    );

    test('offers a newer version without forcing the user', () {
      final state = AppUpdateState(
        current: current,
        manifest: AppUpdateManifest(
          latestVersion: '1.0.5',
          minimumVersion: '1.0.0',
          forceUpdate: false,
        ),
      );

      expect(state.hasUpdate, isTrue);
      expect(state.isRequired, isFalse);
    });

    test('requires update below the minimum supported version', () {
      final state = AppUpdateState(
        current: current,
        manifest: AppUpdateManifest(
          latestVersion: '1.0.5',
          minimumVersion: '1.0.5',
        ),
      );

      expect(state.isRequired, isTrue);
    });

    test('can explicitly force a newer release', () {
      final state = AppUpdateState(
        current: current,
        manifest: AppUpdateManifest(latestVersion: '1.0.5', forceUpdate: true),
      );

      expect(state.isRequired, isTrue);
    });

    test('detects a store update without forcing it', () {
      final state = AppUpdateState(current: current, playUpdateAvailable: true);

      expect(state.hasUpdate, isTrue);
      expect(state.isRequired, isFalse);
    });

    test('can detect a build-only manifest update', () {
      final state = AppUpdateState(
        current: current,
        manifest: const AppUpdateManifest(latestVersion: '', latestBuild: 8),
      );

      expect(state.hasUpdate, isTrue);
    });
  });
}
