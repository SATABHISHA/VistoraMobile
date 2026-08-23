import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/file_manager/domain/file_manager_models.dart';

class FileManagerRepository {
  const FileManagerRepository(this._api);
  final ApiClient _api;

  Future<FileManagerPage> folders({
    String? query,
    int page = 1,
    int perPage = 12,
  }) async {
    final response = await _api.get(
      '/file-manager',
      queryParameters: {
        'paginated': 1,
        'q': ?query,
        'page': page,
        'perPage': perPage,
      },
    );
    final data = asMap(response['data']);
    final paginator = asMap(data['folders']);
    final raw = asList(paginator['data']);
    return FileManagerPage(
      folders: raw.map((item) => ManagedFolder.fromJson(asMap(item))).toList(),
      page: asInt(paginator['current_page'], 1),
      lastPage: asInt(paginator['last_page'], 1),
      total: asInt(paginator['total'], raw.length),
      usedBytes: asInt(data['usedBytes'] ?? data['used_bytes']),
      quotaMb: asInt(data['quotaMb'] ?? data['quota_mb']),
    );
  }

  Future<ManagedFolder> folder(int id) async {
    final response = await _api.get('/file-manager/folders/$id');
    return ManagedFolder.fromJson(asMap(asMap(response['data'])['folder']));
  }

  Future<void> createFolder(String name) =>
      _api.post('/file-manager/folders', data: {'name': name.trim()});

  Future<int> createEmployeeFolders() async {
    final response = await _api.post('/file-manager/employees/create-all');
    return asInt(asMap(response['data'])['count']);
  }

  Future<void> upload({
    required int folderId,
    required String fileName,
    String? path,
    Uint8List? bytes,
  }) async {
    final file = path != null
        ? await MultipartFile.fromFile(path, filename: fileName)
        : MultipartFile.fromBytes(bytes!, filename: fileName);
    await _api.post(
      '/file-manager/folders/$folderId/files',
      data: FormData.fromMap({'file': file}),
    );
  }

  Future<void> deleteFolder(int id) => _api.delete('/file-manager/folders/$id');

  Future<void> deleteFile(int id) => _api.delete('/file-manager/files/$id');

  Future<String> download(ManagedFile file) async {
    final response = await _api.download(
      '/file-manager/files/${file.id}/download',
    );
    final bytes = response.data ?? const <int>[];
    final directory = await getTemporaryDirectory();
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final output = File('${directory.path}${Platform.pathSeparator}$safeName');
    await output.writeAsBytes(bytes, flush: true);
    return output.path;
  }
}
