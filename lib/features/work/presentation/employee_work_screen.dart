import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/status_badge.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/work/domain/employee_work_models.dart';
import 'package:vistora_mobile/features/work/presentation/employee_work_providers.dart';

class EmployeeWorkScreen extends ConsumerWidget {
  const EmployeeWorkScreen({required this.initialIndex, super.key});
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session!;
    final tabs = <_WorkTab>[
      if (session.features.projects)
        const _WorkTab('Projects', Icons.work_outline, _ProjectsTab()),
      const _WorkTab('Performance', Icons.insights_outlined, _PerformanceTab()),
      const _WorkTab(
        'Interviews',
        Icons.record_voice_over_outlined,
        _InterviewsTab(),
      ),
    ];
    final safeIndex = initialIndex.clamp(0, tabs.length - 1);
    return DefaultTabController(
      length: tabs.length,
      initialIndex: safeIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Work'),
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs
                .map((tab) => Tab(text: tab.label, icon: Icon(tab.icon)))
                .toList(),
          ),
        ),
        body: TabBarView(children: tabs.map((tab) => tab.child).toList()),
      ),
    );
  }
}

class _WorkTab {
  const _WorkTab(this.label, this.icon, this.child);
  final String label;
  final IconData icon;
  final Widget child;
}

class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(authControllerProvider).session?.employeeId;
    return _AsyncList<EmployeeProject>(
      value: ref.watch(employeeProjectsProvider),
      onRefresh: () async {
        ref.invalidate(employeeProjectsProvider);
        await ref.read(employeeProjectsProvider.future);
      },
      emptyTitle: 'No project assignments',
      emptyMessage: 'Projects assigned to you will appear here.',
      itemBuilder: (item) {
        final assignment = item.assignmentFor(employeeId);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    StatusBadge(item.status),
                  ],
                ),
                const SizedBox(height: 7),
                Text('${item.code} • ${assignment?.role ?? 'Team member'}'),
                if (assignment?.deadline != null)
                  Text(
                    'Deadline ${DateFormat.yMMMd().format(assignment!.deadline!)}',
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: assignment == null
                        ? null
                        : () => _showProjectUpdate(
                            context,
                            ref,
                            item,
                            assignment,
                          ),
                    icon: const Icon(Icons.update),
                    label: const Text('Submit update'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProjectUpdate(
    BuildContext context,
    WidgetRef ref,
    EmployeeProject project,
    ProjectAssignmentItem assignment,
  ) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ProjectUpdateSheet(project: project, assignment: assignment),
    );
    if (submitted == true) ref.invalidate(employeeProjectsProvider);
  }
}

class _ProjectUpdateSheet extends ConsumerStatefulWidget {
  const _ProjectUpdateSheet({required this.project, required this.assignment});
  final EmployeeProject project;
  final ProjectAssignmentItem assignment;

  @override
  ConsumerState<_ProjectUpdateSheet> createState() =>
      _ProjectUpdateSheetState();
}

class _ProjectUpdateSheetState extends ConsumerState<_ProjectUpdateSheet> {
  final achievements = TextEditingController();
  final blockers = TextEditingController();
  final nextPlan = TextEditingController();
  double progress = 0;
  String period = 'weekly';
  bool saving = false;

  @override
  void dispose() {
    achievements.dispose();
    blockers.dispose();
    nextPlan.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => saving = true);
    try {
      await ref
          .read(employeeWorkRepositoryProvider)
          .submitProjectUpdate(
            projectId: widget.project.id,
            assignmentId: widget.assignment.id,
            periodType: period,
            periodStart: DateTime.now(),
            progressPercent: progress.round(),
            achievements: achievements.text.trim(),
            blockers: blockers.text.trim(),
            nextPlan: nextPlan.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.project.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: period,
            decoration: const InputDecoration(labelText: 'Reporting period'),
            items: const ['daily', 'weekly', 'monthly']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => period = value ?? period),
          ),
          const SizedBox(height: 12),
          Text(
            'Progress ${progress.round()}%',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            value: progress,
            max: 100,
            divisions: 20,
            label: '${progress.round()}%',
            onChanged: (value) => setState(() => progress = value),
          ),
          _field(achievements, 'Achievements'),
          _field(blockers, 'Blockers'),
          _field(nextPlan, 'Next plan'),
          FilledButton(
            onPressed: saving ? null : submit,
            child: saving
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('Submit Progress'),
          ),
        ],
      ),
    ),
  );

  static Widget _field(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          maxLength: 5000,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
          ),
        ),
      );
}

class _PerformanceTab extends ConsumerWidget {
  const _PerformanceTab();

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => _AsyncList<PerformanceReviewItem>(
    value: ref.watch(employeePerformanceProvider),
    onRefresh: () async {
      ref.invalidate(employeePerformanceProvider);
      await ref.read(employeePerformanceProvider.future);
    },
    emptyTitle: 'No performance reviews',
    emptyMessage: 'Published review history will appear here.',
    itemBuilder: (item) => Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(DateTime(item.year, item.month)),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                CircleAvatar(child: Text(item.overallScore.toStringAsFixed(1))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _score('Quality', item.quality),
                _score('Timeliness', item.timeliness),
                _score('Teamwork', item.teamwork),
                _score('Initiative', item.initiative),
                _score('Communication', item.communication),
              ],
            ),
            if (item.comment != null) ...[
              const Divider(height: 24),
              Text(item.comment!),
            ],
          ],
        ),
      ),
    ),
  );

  static Widget _score(String label, int score) =>
      Chip(label: Text('$label $score/10'));
}

class _InterviewsTab extends ConsumerWidget {
  const _InterviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authControllerProvider).session!.user.id;
    return _AsyncList<InterviewTask>(
      value: ref.watch(interviewTasksProvider),
      onRefresh: () async {
        ref.invalidate(interviewTasksProvider);
        await ref.read(interviewTasksProvider.future);
      },
      emptyTitle: 'No interviews assigned',
      emptyMessage: 'New panel assignments will appear here.',
      itemBuilder: (item) {
        final mine = item.feedbackBy(userId);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.candidateName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    StatusBadge(mine == null ? 'pending' : 'completed'),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${item.position} • ${DateFormat.yMMMd().add_jm().format(item.scheduledAt)} • ${item.mode.replaceAll('_', ' ')}',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showFeedback(context, ref, item, mine),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(
                      mine == null ? 'Give feedback' : 'Update feedback',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFeedback(
    BuildContext context,
    WidgetRef ref,
    InterviewTask task,
    InterviewFeedbackItem? existing,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InterviewFeedbackSheet(task: task, existing: existing),
    );
    if (saved == true) ref.invalidate(interviewTasksProvider);
  }
}

class _InterviewFeedbackSheet extends ConsumerStatefulWidget {
  const _InterviewFeedbackSheet({required this.task, this.existing});
  final InterviewTask task;
  final InterviewFeedbackItem? existing;

  @override
  ConsumerState<_InterviewFeedbackSheet> createState() =>
      _InterviewFeedbackSheetState();
}

class _InterviewFeedbackSheetState
    extends ConsumerState<_InterviewFeedbackSheet> {
  late int rating;
  late String recommendation;
  late TextEditingController feedback;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    rating = widget.existing?.rating ?? 5;
    recommendation = widget.existing?.recommendation ?? 'hire';
    feedback = TextEditingController(text: widget.existing?.feedback);
  }

  @override
  void dispose() {
    feedback.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (feedback.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await ref
          .read(employeeWorkRepositoryProvider)
          .submitInterviewFeedback(
            interviewId: widget.task.id,
            rating: rating,
            recommendation: recommendation,
            feedback: feedback.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.task.candidateName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: rating,
            decoration: const InputDecoration(labelText: 'Rating'),
            items: [5, 4, 3, 2, 1]
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value / 5')),
                )
                .toList(),
            onChanged: (value) => setState(() => rating = value ?? rating),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: recommendation,
            decoration: const InputDecoration(labelText: 'Recommendation'),
            items: const ['strong_hire', 'hire', 'hold', 'reject']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.replaceAll('_', ' ').toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => recommendation = value ?? recommendation),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: feedback,
            minLines: 4,
            maxLines: 7,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Interview feedback',
              alignLabelWithHint: true,
            ),
          ),
          FilledButton(
            onPressed: saving ? null : submit,
            child: saving
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('Submit Feedback'),
          ),
        ],
      ),
    ),
  );
}

class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({
    required this.value,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });
  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        value.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => AsyncErrorCard(error: error, onRetry: onRefresh),
          data: (items) => items.isEmpty
              ? EmptyState(title: emptyTitle, message: emptyMessage)
              : Column(children: items.map(itemBuilder).toList()),
        ),
      ],
    ),
  );
}
