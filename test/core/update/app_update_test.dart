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
}
