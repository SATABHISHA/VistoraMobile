import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/core/widgets/status_badge.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/leave/domain/leave_models.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_providers.dart';

class TeamLeaveScreen extends ConsumerStatefulWidget {
  const TeamLeaveScreen({super.key});

  @override
  ConsumerState<TeamLeaveScreen> createState() => _TeamLeaveScreenState();
}

class _TeamLeaveScreenState extends ConsumerState<TeamLeaveScreen> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String? _status;
  late Future<List<LeaveRequestItem>> _result;

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<List<LeaveRequestItem>> _load() async {
    var items = await ref
        .read(leaveRepositoryProvider)
        .requests(perPage: 100, status: _status, query: _search.text);
    final status = _status;
    final search = _search.text.trim().toLowerCase();
    if (status != null) {
      items = items
          .where((item) => item.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (search.isNotEmpty) {
      items = items.where((item) {
        final haystack = [
          item.employeeName,
          item.employeeCode,
          item.reason,
          item.leaveTypeName,
        ].whereType<String>().join(' ').toLowerCase();
        return haystack.contains(search);
      }).toList();
    }
    return items;
  }

  Future<void> _refresh() async {
    setState(() => _result = _load());
    await _result;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final supervisor = session?.user.normalizedRole == 'supervisor';
    return Scaffold(
      appBar: AppBar(
        title: Text(supervisor ? 'Subordinate Leave' : 'Leave Approvals'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                onSubmitted: (_) => _refresh(),
                decoration: InputDecoration(
                  labelText: 'Search employee leave',
                  hintText: 'Employee name or ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 350),
                    () {
                      if (mounted) _refresh();
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              _StatusTabs(
                selected: _status,
                onChanged: (value) {
                  setState(() {
                    _status = value;
                    _result = _load();
                  });
                },
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<LeaveRequestItem>>(
                future: _result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return AsyncErrorCard(
                      error: snapshot.error!,
                      onRetry: _refresh,
                    );
                  }
                  final items = supervisor
                      ? snapshot.data!
                            .where(
                              (item) => item.employeeId != session?.employeeId,
                            )
                            .toList()
                      : snapshot.data!;
                  final pending = items
                      .where((item) => item.status == 'pending')
                      .length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: VistoraColors.amber.withValues(alpha: .08),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.pending_actions),
                          ),
                          title: Text(
                            '$pending pending action${pending == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text(
                            'Approve, reject or review employee requests',
                          ),
                        ),
                      ),
                      if (items.isEmpty)
                        const EmptyState(
                          title: 'No leave requests',
                          message: 'No requests match the selected filters.',
                          icon: Icons.beach_access_outlined,
                        )
                      else
                        ...items.map(
                          (item) => _TeamLeaveCard(
                            item: item,
                            action: () => _action(item),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _action(LeaveRequestItem item) async {
    final repository = ref.read(leaveRepositoryProvider);
    if (item.status == 'pending') {
      final options = await repository.approvalOptions(item.id);
      if (!mounted) return;
      int? selected = options.isEmpty ? null : options.first.leaveTypeId;
      final note = TextEditingController();
      final action = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Review ${item.employeeName ?? 'employee'} leave',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                if (options.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Deduct from leave type',
                    ),
                    items: options
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.leaveTypeId,
                            child: Text(
                              '${option.name} • ${option.balance} available',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocal(() => selected = value),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Decision note'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, 'reject'),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, 'approve'),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      final decisionNote = note.text.trim();
      note.dispose();
      if (action == 'approve') {
        await repository.approve(
          item.id,
          leaveTypeId: selected,
          note: decisionNote,
        );
      }
      if (action == 'reject') {
        await repository.reject(item.id, note: decisionNote);
      }
      if (action != null) await _refresh();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert leave decision?'),
        content: Text(
          'Return ${item.employeeName ?? 'this employee'} leave request to pending?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.revert(item.id);
      await _refresh();
    }
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (label: 'All', value: null),
      (label: 'Pending', value: 'pending'),
      (label: 'Approved', value: 'approved'),
      (label: 'Rejected', value: 'rejected'),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(tab.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected == tab.value
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      border: tab == tabs.last
                          ? null
                          : Border(
                              right: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                    ),
                    child: Text(
                      tab.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamLeaveCard extends StatelessWidget {
  const _TeamLeaveCard({required this.item, required this.action});
  final LeaveRequestItem item;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(_initials(item.employeeName ?? 'Employee')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employeeName ?? 'Employee',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      item.employeeCode ?? '—',
                      style: const TextStyle(color: VistoraColors.muted),
                    ),
                  ],
                ),
              ),
              StatusBadge(item.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${item.leaveTypeName ?? 'Leave'} • ${item.days} day(s)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${DateFormat.yMMMd().format(item.startDate)} – ${DateFormat.yMMMd().format(item.endDate)}',
          ),
          if (item.reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.reason!,
                style: const TextStyle(color: VistoraColors.muted),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: action,
              icon: Icon(item.status == 'pending' ? Icons.rule : Icons.undo),
              label: Text(
                item.status == 'pending' ? 'Review request' : 'Revert decision',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
