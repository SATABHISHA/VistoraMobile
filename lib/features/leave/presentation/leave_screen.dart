import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/core/widgets/status_badge.dart';
import 'package:vistora_mobile/features/leave/domain/leave_models.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_providers.dart';
import 'package:vistora_mobile/features/leave/presentation/team_leave_screen.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key, this.personalMode = false});

  final bool personalMode;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(leaveSummaryProvider);
    ref.invalidate(leaveRequestsProvider);
    await Future.wait([
      ref.read(leaveSummaryProvider.future),
      ref.read(leaveRequestsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).session?.user.normalizedRole;
    if (!personalMode && const {'admin', 'hr', 'supervisor'}.contains(role)) {
      return const TeamLeaveScreen();
    }
    final summary = ref.watch(leaveSummaryProvider);
    final requests = ref.watch(leaveRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leave'),
        actions: [
          IconButton(
            tooltip: 'Apply for leave',
            onPressed: summary.value == null
                ? null
                : () => _showApply(context, ref, summary.value!),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: summary.value == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showApply(context, ref, summary.value!),
              icon: const Icon(Icons.add),
              label: const Text('Apply Leave'),
            ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AsyncErrorCard(
                  error: error,
                  onRetry: () => ref.invalidate(leaveSummaryProvider),
                ),
                data: (value) => _Summary(value),
              ),
              const SizedBox(height: 24),
              Text(
                'Request history',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              requests.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AsyncErrorCard(
                  error: error,
                  onRetry: () => ref.invalidate(leaveRequestsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        title: 'No leave requests',
                        message:
                            'Your submitted leave requests will appear here.',
                        icon: Icons.beach_access_outlined,
                      )
                    : _RequestHistory(items),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showApply(
    BuildContext context,
    WidgetRef ref,
    LeaveSummary summary,
  ) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ApplyLeaveSheet(types: summary.types),
    );
    if (applied == true) {
      ref.invalidate(leaveSummaryProvider);
      ref.invalidate(leaveRequestsProvider);
    }
  }
}

class _RequestHistory extends StatefulWidget {
  const _RequestHistory(this.items);

  final List<LeaveRequestItem> items;

  @override
  State<_RequestHistory> createState() => _RequestHistoryState();
}

class _RequestHistoryState extends State<_RequestHistory> {
  static const _pageSize = 5;
  int _page = 1;

  @override
  void didUpdateWidget(covariant _RequestHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _page = 1;
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = (widget.items.length / _pageSize).ceil();
    final page = _page.clamp(1, pageCount);
    final start = (page - 1) * _pageSize;
    final visible = widget.items.skip(start).take(_pageSize);
    return Column(
      children: [
        ...visible.map((item) => _LeaveCard(item)),
        if (pageCount > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: page > 1 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              Text('Page $page of $pageCount'),
              OutlinedButton.icon(
                onPressed: page < pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.value);
  final LeaveSummary value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 700
              ? (constraints.maxWidth - 24) / 3
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                'Remaining',
                value.remainingTotal,
                VistoraColors.green,
                width,
              ),
              _Metric('Used', value.usedTotal, VistoraColors.cyan, width),
              _Metric(
                'Pending',
                value.pendingCount,
                VistoraColors.amber,
                width,
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Leave balance by type',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...value.types.map(
                (type) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text('${type.name} (${type.code})')),
                      Text(
                        '${_number(type.remaining)} remaining',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color, this.width);
  final String label;
  final num value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: VistoraColors.muted)),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 27,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard(this.item);
  final LeaveRequestItem item;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.leaveTypeName ?? 'Leave request',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              StatusBadge(item.status),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${DateFormat.yMMMd().format(item.startDate)} – ${DateFormat.yMMMd().format(item.endDate)}  •  ${item.days} day(s)',
          ),
          if (item.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              item.reason!,
              style: const TextStyle(color: VistoraColors.muted),
            ),
          ],
          if (item.decisionNote != null) ...[
            const Divider(height: 22),
            Text('Decision note: ${item.decisionNote}'),
          ],
        ],
      ),
    ),
  );
}

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet({required this.types});
  final List<LeaveTypeBalance> types;

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  int? _typeId;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _typeId = widget.types.isEmpty ? null : widget.types.first.id;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? (_start ?? now) : (_end ?? _start ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_typeId == null || _start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select leave type and dates.')),
      );
      return;
    }
    if (_end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(leaveRepositoryProvider)
          .apply(
            leaveTypeId: _typeId!,
            startDate: _start!,
            endDate: _end!,
            reason: _reason.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      22,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Apply for leave',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              value: _typeId,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: widget.types
                  .map(
                    (type) => DropdownMenuItem(
                      value: type.id,
                      child: Text('${type.name} (${type.remaining} available)'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _typeId = value),
              validator: (value) =>
                  value == null ? 'Select a leave type' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: true),
                    icon: const Icon(Icons.event),
                    label: Text(
                      _start == null
                          ? 'Start date'
                          : DateFormat.yMMMd().format(_start!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: false),
                    icon: const Icon(Icons.event_available),
                    label: Text(
                      _end == null
                          ? 'End date'
                          : DateFormat.yMMMd().format(_end!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    ),
  );
}
