import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/file_manager/domain/file_manager_models.dart';

void main() {
  test('parses secure folder files and calculates quota usage', () {
    final folder = ManagedFolder.fromJson({
      'id': 8,
      'employee_id': 6,
      'name': 'EMP006_Meera_Das',
      'files_count': 1,
      'files': [
        {
          'id': 19,
          'original_name': 'appointment-letter.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 524288,
          'malware_scan_status': 'clean',
          'created_at': '2026-08-23T10:00:00+05:30',
        },
      ],
    });
    final page = FileManagerPage(
      folders: [folder],
      page: 1,
      lastPage: 2,
      total: 13,
      usedBytes: 524288,
      quotaMb: 1,
    );

    expect(folder.name, 'EMP006_Meera_Das');
    expect(folder.files.single.name, 'appointment-letter.pdf');
    expect(folder.files.single.scanStatus, 'clean');
    expect(page.hasMore, isTrue);
    expect(page.usageRatio, 0.5);
  });
}
