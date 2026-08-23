import 'package:vistora_mobile/core/api/api_parsing.dart';

class ManagedFile {
  const ManagedFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.scanStatus,
    this.createdAt,
  });

  final int id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String scanStatus;
  final DateTime? createdAt;

  factory ManagedFile.fromJson(Map<String, dynamic> json) => ManagedFile(
    id: asInt(json['id']),
    name: json['original_name']?.toString() ?? 'Document',
    mimeType: json['mime_type']?.toString() ?? 'application/octet-stream',
    sizeBytes: asInt(json['size_bytes']),
    scanStatus: json['malware_scan_status']?.toString() ?? 'pending',
    createdAt: asDateTime(json['created_at']),
  );
}

class ManagedFolder {
  const ManagedFolder({
    required this.id,
    required this.name,
    required this.filesCount,
    this.employeeId,
    this.files = const [],
  });

  final int id;
  final int? employeeId;
  final String name;
  final int filesCount;
  final List<ManagedFile> files;

  factory ManagedFolder.fromJson(Map<String, dynamic> json) {
    final files = asList(
      json['files'],
    ).map((item) => ManagedFile.fromJson(asMap(item))).toList();
    return ManagedFolder(
      id: asInt(json['id']),
      employeeId: json['employee_id'] == null
          ? null
          : asInt(json['employee_id']),
      name: json['name']?.toString() ?? 'Folder',
      filesCount: asInt(json['files_count'], files.length),
      files: files,
    );
  }
}

class FileManagerPage {
  const FileManagerPage({
    required this.folders,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.usedBytes,
    required this.quotaMb,
  });

  final List<ManagedFolder> folders;
  final int page;
  final int lastPage;
  final int total;
  final int usedBytes;
  final int quotaMb;

  bool get hasMore => page < lastPage;
  double get usageRatio => quotaMb <= 0
      ? 0
      : (usedBytes / (quotaMb * 1024 * 1024)).clamp(0, 1).toDouble();
}
