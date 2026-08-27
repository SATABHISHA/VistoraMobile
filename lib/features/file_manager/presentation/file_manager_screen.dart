import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/file_manager/data/file_manager_repository.dart';
import 'package:vistora_mobile/features/file_manager/domain/file_manager_models.dart';

final fileManagerRepositoryProvider = Provider<FileManagerRepository>(
  (ref) => FileManagerRepository(ref.watch(apiClientProvider)),
);

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  bool _busy = false;
  late Future<FileManagerPage> _future;

  FileManagerRepository get repository =>
      ref.read(fileManagerRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<FileManagerPage> _load() => repository.folders(
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    page: _page,
  );

  Future<void> _refresh({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _refresh(resetPage: true);
    });
  }

  Future<void> _action(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (mounted) _toast(message);
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.create_new_folder_outlined),
        title: const Text('Create secure folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 190,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name?.isNotEmpty == true) {
      await _action(() => repository.createFolder(name!), 'Folder created.');
    }
  }

  Future<void> _createEmployeeFolders() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final count = await repository.createEmployeeFolders();
      await _refresh();
      if (mounted) _toast('$count employee folder(s) created.');
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(ManagedFolder folder) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FolderSheet(folderId: folder.id),
    );
    if (mounted) await _refresh();
  }

  Future<void> _deleteFolder(ManagedFolder folder) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete ${folder.name}?',
      message:
          'The folder and all ${folder.filesCount} contained file(s) will be permanently deleted.',
      confirmLabel: 'Delete folder',
    );
    if (confirmed) {
      await _action(
        () => repository.deleteFolder(folder.id),
        'Folder and files deleted.',
      );
    }
  }

  void _toast(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFF8B2635) : null,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Secure Files', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(
            'Tenant document vault',
            style: TextStyle(fontSize: 11, color: VistoraColors.muted),
          ),
        ],
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<FileManagerPage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 260),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.cloud_off_outlined,
                  size: 54,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          final page = snapshot.data!;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            children: [
              _StorageHero(page: page),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _search,
                    onChanged: _searchChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search folders',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _createFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('New folder'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _createEmployeeFolders,
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Create employee folders'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (page.folders.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.folder_off_outlined, size: 48),
                        SizedBox(height: 10),
                        Text(
                          'No folders found',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text('Create a folder to begin managing documents.'),
                      ],
                    ),
                  ),
                )
              else
                for (var i = 0; i < page.folders.length; i++)
                  TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 260 + i * 35),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, 14 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    ),
                    child: _FolderCard(
                      folder: page.folders[i],
                      open: () => _openFolder(page.folders[i]),
                      delete: () => _deleteFolder(page.folders[i]),
                    ),
                  ),
              _PageControls(
                page: page.page,
                lastPage: page.lastPage,
                total: page.total,
                previous: page.page > 1
                    ? () {
                        _page--;
                        _refresh();
                      }
                    : null,
                next: page.hasMore
                    ? () {
                        _page++;
                        _refresh();
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FolderSheet extends ConsumerStatefulWidget {
  const _FolderSheet({required this.folderId});
  final int folderId;

  @override
  ConsumerState<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends ConsumerState<_FolderSheet> {
  late Future<ManagedFolder> _future;
  bool _busy = false;
  FileManagerRepository get repository =>
      ref.read(fileManagerRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = repository.folder(widget.folderId);
  }

  Future<void> _refresh() async {
    setState(() => _future = repository.folder(widget.folderId));
    await _future;
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles();
    final picked = result?.files.single;
    if (picked == null) return;
    final fileSize = picked.size;
    if (fileSize > 2 * 1024 * 1024) {
      _toast('Files must be 2 MB or smaller.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await repository.upload(
        folderId: widget.folderId,
        fileName: picked.name,
        path: picked.path,
        bytes: picked.path == null ? picked.bytes : null,
      );
      await _refresh();
      _toast('File uploaded securely.');
    } catch (error) {
      _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(ManagedFile file) async {
    setState(() => _busy = true);
    try {
      final path = await repository.download(file);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        _toast('Downloaded ${file.name}. ${result.message}');
      }
    } catch (error) {
      _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ManagedFile file) async {
    if (!await _confirm(
      context,
      title: 'Delete ${file.name}?',
      message: 'This stored file will be permanently removed.',
      confirmLabel: 'Delete file',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repository.deleteFile(file.id);
      await _refresh();
      _toast('File deleted.');
    } catch (error) {
      _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFF8B2635) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .88,
    minChildSize: .5,
    maxChildSize: .96,
    builder: (context, controller) => FutureBuilder<ManagedFolder>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final folder = snapshot.data!;
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x2200D2FF),
                  child: Icon(Icons.folder_open, color: VistoraColors.cyan),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      Text('${folder.files.length} secure file(s)'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _upload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (folder.files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(Icons.insert_drive_file_outlined, size: 50),
                    SizedBox(height: 10),
                    Text('This folder is empty.'),
                  ],
                ),
              )
            else
              for (final file in folder.files)
                Card(
                  child: ListTile(
                    onTap: _busy ? null : () => _download(file),
                    leading: CircleAvatar(
                      child: Icon(_fileIcon(file.mimeType)),
                    ),
                    title: Text(
                      file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_bytes(file.sizeBytes)} • ${file.scanStatus}',
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !_busy,
                      onSelected: (value) =>
                          value == 'download' ? _download(file) : _delete(file),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'download',
                          child: Text('Download and open'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

class _StorageHero extends StatelessWidget {
  const _StorageHero({required this.page});
  final FileManagerPage page;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0x3300D2FF), Color(0x22124ECC), Color(0x22FF2D78)],
      ),
      border: Border.all(color: const Color(0x2200D2FF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: VistoraColors.cyan),
            SizedBox(width: 9),
            Text(
              'Company document vault',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_bytes(page.usedBytes)} of ${page.quotaMb} MB used • ${page.total} folders',
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: page.usageRatio,
            minHeight: 9,
            color: page.usageRatio > .85
                ? VistoraColors.pink
                : VistoraColors.cyan,
          ),
        ),
      ],
    ),
  );
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.open,
    required this.delete,
  });
  final ManagedFolder folder;
  final VoidCallback open;
  final VoidCallback delete;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: open,
      contentPadding: const EdgeInsets.all(16),
      leading: const CircleAvatar(
        backgroundColor: Color(0x2200D2FF),
        child: Icon(Icons.folder_outlined, color: VistoraColors.cyan),
      ),
      title: Text(
        folder.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${folder.filesCount} file(s)${folder.employeeId == null ? ' • Manual folder' : ' • Employee folder'}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'open' ? open() : delete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('Open folder')),
          PopupMenuItem(value: 'delete', child: Text('Delete folder')),
        ],
      ),
    ),
  );
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.lastPage,
    required this.total,
    this.previous,
    this.next,
  });
  final int page, lastPage, total;
  final VoidCallback? previous, next;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      children: [
        Expanded(child: Text('$total folders • Page $page of $lastPage')),
        IconButton(onPressed: previous, icon: const Icon(Icons.chevron_left)),
        IconButton(onPressed: next, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

IconData _fileIcon(String mime) {
  if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.contains('sheet') || mime.contains('excel')) {
    return Icons.table_chart_outlined;
  }
  if (mime.contains('word') || mime.contains('document')) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

String _bytes(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '$value B';
}
