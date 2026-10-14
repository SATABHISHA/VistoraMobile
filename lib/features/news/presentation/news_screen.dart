import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/news/data/news_repository.dart';
import 'package:vistora_mobile/features/news/domain/news_models.dart';

final newsRepositoryProvider = Provider<NewsRepository>(
  (ref) => NewsRepository(ref.watch(apiClientProvider)),
);
final dashboardNewsProvider = FutureProvider.autoDispose<NewsItem?>(
  (ref) => ref.watch(newsRepositoryProvider).popup(),
);

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});
  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  late Future<NewsPage> _future;
  int _page = 1, _perPage = 5;
  late int _year;
  int? _month;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  void _load() => _future = ref
      .read(newsRepositoryProvider)
      .list(
        page: _page,
        perPage: _perPage,
        year: _year,
        month: _month,
        date: _date,
      );
  Future<void> _refresh() async => setState(_load);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vistora News'),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          const _NewsHero(),
          const SizedBox(height: 14),
          _NewsFilters(
            year: _year,
            month: _month,
            date: _date,
            perPage: _perPage,
            onChanged: (year, month, date, perPage) => setState(() {
              _year = year;
              _month = month;
              _date = date;
              _perPage = perPage;
              _page = 1;
              _load();
            }),
          ),
          const SizedBox(height: 14),
          FutureBuilder<NewsPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const _NewsLoading();
              if (snapshot.hasError)
                return _NewsError(error: snapshot.error, onRetry: _refresh);
              final page = snapshot.requireData;
              return Column(
                children: [
                  if (page.items.isEmpty) const _NewsEmpty(),
                  ...page.items.map((item) => _NewsCard(item: item)),
                  _NewsPager(
                    page: page,
                    onPrevious: page.hasPrevious
                        ? () => setState(() {
                            _page--;
                            _load();
                          })
                        : null,
                    onNext: page.hasNext
                        ? () => setState(() {
                            _page++;
                            _load();
                          })
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class NewsAdminScreen extends ConsumerStatefulWidget {
  const NewsAdminScreen({super.key});
  @override
  ConsumerState<NewsAdminScreen> createState() => _NewsAdminScreenState();
}

class _NewsAdminScreenState extends ConsumerState<NewsAdminScreen> {
  late Future<NewsPage> _future;
  int _page = 1, _perPage = 5;
  late int _year, _month;
  DateTime? _date;
  String _status = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  void _load() => _future = ref
      .read(newsRepositoryProvider)
      .adminList(
        page: _page,
        perPage: _perPage,
        year: _year,
        month: _month,
        date: _date,
        status: _status,
      );
  Future<void> _refresh() async => setState(_load);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Newsroom'),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _compose,
      icon: const Icon(Icons.campaign_outlined),
      label: const Text('Publish news'),
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          const _NewsHero(
            title: 'Superadmin broadcast centre',
            subtitle:
                'Publish to every tenant, one tenant, or selected employees.',
          ),
          const SizedBox(height: 14),
          _NewsFilters(
            year: _year,
            month: _month,
            date: _date,
            perPage: _perPage,
            includeAllMonths: false,
            status: _status,
            onStatusChanged: (value) => setState(() {
              _status = value;
              _page = 1;
              _load();
            }),
            onChanged: (year, month, date, perPage) => setState(() {
              _year = year;
              _month = month ?? DateTime.now().month;
              _date = date;
              _perPage = perPage;
              _page = 1;
              _load();
            }),
          ),
          const SizedBox(height: 14),
          FutureBuilder<NewsPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const _NewsLoading();
              if (snapshot.hasError)
                return _NewsError(error: snapshot.error, onRetry: _refresh);
              final page = snapshot.requireData;
              return Column(
                children: [
                  if (page.items.isEmpty) const _NewsEmpty(),
                  ...page.items.map(
                    (item) => _AdminNewsCard(
                      item: item,
                      onStatus: () async {
                        await ref
                            .read(newsRepositoryProvider)
                            .setStatus(
                              item.id,
                              item.status == 'published'
                                  ? 'unpublish'
                                  : 'publish',
                            );
                        if (mounted) setState(_load);
                      },
                    ),
                  ),
                  _NewsPager(
                    page: page,
                    onPrevious: page.hasPrevious
                        ? () => setState(() {
                            _page--;
                            _load();
                          })
                        : null,
                    onNext: page.hasNext
                        ? () => setState(() {
                            _page++;
                            _load();
                          })
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _compose() async {
    final published = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewsComposer(),
    );
    if (published == true && mounted)
      setState(() {
        _page = 1;
        _load();
      });
  }
}

class _NewsComposer extends ConsumerStatefulWidget {
  const _NewsComposer();
  @override
  ConsumerState<_NewsComposer> createState() => _NewsComposerState();
}

class _NewsComposerState extends ConsumerState<_NewsComposer> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _link = TextEditingController();
  String _scope = 'all';
  String? _corpId;
  String _query = '';
  int _targetPage = 1;
  late Future<NewsTargets> _targets;
  final _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _targets = ref.read(newsRepositoryProvider).targets();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _link.dispose();
    super.dispose();
  }

  void _reloadTargets() => setState(
    () => _targets = ref
        .read(newsRepositoryProvider)
        .targets(corpId: _corpId, query: _query, page: _targetPage),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Publish news',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Audience'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All tenants')),
                DropdownMenuItem(value: 'tenant', child: Text('One tenant')),
                DropdownMenuItem(
                  value: 'employee',
                  child: Text('Selected employees'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _scope = value ?? 'all';
                  if (_scope != 'employee') _selected.clear();
                });
                _reloadTargets();
              },
            ),
            if (_scope != 'all') ...[
              const SizedBox(height: 12),
              FutureBuilder<NewsTargets>(
                future: _targets,
                builder: (context, snapshot) {
                  final tenants =
                      snapshot.data?.tenants ?? const <NewsTenantTarget>[];
                  return DropdownButtonFormField<String>(
                    initialValue: _corpId,
                    decoration: const InputDecoration(labelText: 'Tenant'),
                    items: tenants
                        .map(
                          (tenant) => DropdownMenuItem(
                            value: tenant.corpId,
                            child: Text(
                              tenant.companyName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      _corpId = value;
                      _targetPage = 1;
                      _reloadTargets();
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              decoration: const InputDecoration(
                labelText: 'Attached link (optional)',
                hintText: 'https://example.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
            ),
            if (_scope == 'employee') ...[
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search employees',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  _query = value;
                  _targetPage = 1;
                  _reloadTargets();
                },
              ),
              const SizedBox(height: 8),
              FutureBuilder<NewsTargets>(
                future: _targets,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) return const LinearProgressIndicator();
                  final allSelected =
                      data.employees.isNotEmpty &&
                      data.employees.every(
                        (employee) => _selected.contains(employee.id),
                      );
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            for (final employee in data.employees) {
                              allSelected
                                  ? _selected.remove(employee.id)
                                  : _selected.add(employee.id);
                            }
                          }),
                          child: Text(
                            allSelected ? 'Clear page' : 'Select all on page',
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 190),
                        child: ListView(
                          shrinkWrap: true,
                          children: data.employees
                              .map(
                                (employee) => CheckboxListTile(
                                  value: _selected.contains(employee.id),
                                  onChanged: (value) => setState(
                                    () => value == true
                                        ? _selected.add(employee.id)
                                        : _selected.remove(employee.id),
                                  ),
                                  title: Text(employee.name),
                                  subtitle: Text(
                                    '${employee.empCode} · ${employee.email ?? 'No email'}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${data.total} employees'),
                          Row(
                            children: [
                              IconButton(
                                onPressed: data.hasPrevious
                                    ? () {
                                        _targetPage--;
                                        _reloadTargets();
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              IconButton(
                                onPressed: data.hasNext
                                    ? () {
                                        _targetPage++;
                                        _reloadTargets();
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _publish,
              icon: const Icon(Icons.send),
              label: const Text('Publish now'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty ||
        _message.text.trim().isEmpty ||
        (_scope != 'all' && _corpId == null) ||
        (_scope == 'employee' && _selected.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the title, message, audience and recipients.',
          ),
        ),
      );
      return;
    }
    await ref
        .read(newsRepositoryProvider)
        .publish(
          title: _title.text,
          message: _message.text,
          scope: _scope,
          corpId: _corpId,
          linkUrl: _link.text,
          employeeIds: _selected.toList(),
        );
    if (mounted) Navigator.pop(context, true);
  }
}

class _NewsHero extends StatelessWidget {
  const _NewsHero({
    this.title = 'Vistora News',
    this.subtitle =
        'Important updates, announcements and useful links for your Vistora workspace.',
  });
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [VistoraColors.orange, VistoraColors.pink],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: VistoraColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewsFilters extends StatelessWidget {
  const _NewsFilters({
    required this.year,
    required this.month,
    required this.date,
    required this.perPage,
    required this.onChanged,
    this.includeAllMonths = true,
    this.status,
    this.onStatusChanged,
  });
  final int year;
  final int? month;
  final DateTime? date;
  final int perPage;
  final bool includeAllMonths;
  final String? status;
  final ValueChanged<String>? onStatusChanged;
  final void Function(int, int?, DateTime?, int) onChanged;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = <DropdownMenuItem<int?>>[];
    if (includeAllMonths)
      months.add(
        const DropdownMenuItem(value: null, child: Text('All months')),
      );
    months.addAll(
      List.generate(
        12,
        (i) => DropdownMenuItem(
          value: i + 1,
          child: Text(DateFormat.MMMM().format(DateTime(2000, i + 1))),
        ),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            DropdownButton<int>(
              value: year,
              items: List.generate(7, (i) => now.year + 1 - i)
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value')),
                  )
                  .toList(),
              onChanged: (value) =>
                  onChanged(value ?? now.year, month, date, perPage),
            ),
            DropdownButton<int?>(
              value: month,
              items: months,
              onChanged: (value) => onChanged(year, value, date, perPage),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? now,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 1, 12, 31),
                );
                if (picked != null) onChanged(year, month, picked, perPage);
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                date == null
                    ? 'Any date'
                    : DateFormat('dd-MM-yyyy').format(date!),
              ),
            ),
            DropdownButton<int>(
              value: perPage,
              items: [3, 5, 10, 20, 50]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value rows'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => onChanged(year, month, date, value ?? 5),
            ),
            if (status != null && onStatusChanged != null)
              DropdownButton<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: '', child: Text('All statuses')),
                  DropdownMenuItem(
                    value: 'published',
                    child: Text('Published'),
                  ),
                  DropdownMenuItem(
                    value: 'unpublished',
                    child: Text('Unpublished'),
                  ),
                ],
                onChanged: (value) => onStatusChanged!(value ?? ''),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final NewsItem item;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.publishedAt == null
                  ? ''
                  : DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(item.publishedAt!.toLocal()),
              style: const TextStyle(
                color: VistoraColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              item.message,
              style: const TextStyle(color: VistoraColors.muted, height: 1.45),
            ),
            if (item.linkUrl?.isNotEmpty == true)
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(item.linkUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(
                  Icons.open_in_new,
                  color: VistoraColors.orange,
                ),
                label: const Text(
                  'Open attached link',
                  style: TextStyle(color: VistoraColors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminNewsCard extends StatelessWidget {
  const _AdminNewsCard({required this.item, required this.onStatus});
  final NewsItem item;
  final VoidCallback onStatus;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(label: Text(item.status)),
            ],
          ),
          Text(
            '${item.tenantName ?? item.corpId ?? 'All tenants'} · ${item.targetScope} · ${item.recipientCount} recipients',
            style: const TextStyle(color: VistoraColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            item.message,
            style: const TextStyle(color: VistoraColors.muted),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onStatus,
              child: Text(item.status == 'published' ? 'Unpublish' : 'Publish'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewsPager extends StatelessWidget {
  const _NewsPager({required this.page, this.onPrevious, this.onNext});
  final NewsPage page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${page.total} updates · Page ${page.page} of ${page.lastPage}',
            style: const TextStyle(color: VistoraColors.muted),
          ),
        ),
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

class _NewsLoading extends StatelessWidget {
  const _NewsLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _NewsEmpty extends StatelessWidget {
  const _NewsEmpty();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Center(
        child: Text(
          'No news matches these filters.',
          style: TextStyle(color: VistoraColors.muted),
        ),
      ),
    ),
  );
}

class _NewsError extends StatelessWidget {
  const _NewsError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: const Text('News could not be loaded'),
      subtitle: Text('$error'),
      trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
    ),
  );
}
