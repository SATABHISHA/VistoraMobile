import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
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
    final canManageProjects =
        session.user.isCompanyManager || session.user.isSupervisor;
    final tabs = <_WorkTab>[
      if (session.features.projects)
        _WorkTab(
          canManageProjects ? 'Project Management' : 'Projects',
          Icons.work_outline,
          canManageProjects
              ? const _ProjectManagementTab()
              : const _ProjectsTab(),
        ),
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
        final projectUpdates = _projectUpdates(item);
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
                if (assignment != null) ...[
                  const SizedBox(height: 9),
                  _ProjectUpdatePreview(updates: assignment.updates),
                ],
                if (projectUpdates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ProjectUpdatesSection(updates: projectUpdates),
                ],
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
    if (submitted == true) {
      ref.invalidate(employeeProjectsProvider);
      final employeeId = ref.read(authControllerProvider).session?.employeeId;
      if (employeeId != null) {
        ref.invalidate(dashboardAssignedProjectsProvider(employeeId));
      }
    }
  }
}

class _ProjectManagementTab extends ConsumerStatefulWidget {
  const _ProjectManagementTab();

  @override
  ConsumerState<_ProjectManagementTab> createState() =>
      _ProjectManagementTabState();
}

class _ProjectManagementTabState extends ConsumerState<_ProjectManagementTab> {
  String _view = 'projects';
  int? _projectFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectManagementProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(projectManagementProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (page) {
        final session = ref.watch(authControllerProvider).session!;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(projectManagementProvider);
            await ref.read(projectManagementProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'projects',
                        icon: Icon(Icons.work_outline),
                        label: Text('Projects'),
                      ),
                      ButtonSegment<String>(
                        value: 'updates',
                        icon: Icon(Icons.groups_outlined),
                        label: Text('Team updates'),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (selection) =>
                        setState(() => _view = selection.first),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_view == 'projects') ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign and track projects',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select from the employees available to your role. Changes are shared with the web dashboard instantly.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: page.assignableEmployees.isEmpty
                              ? null
                              : () => _createProject(context, ref, page),
                          icon: const Icon(Icons.add_task),
                          label: const Text('Assign new project'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Projects',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (page.projects.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No projects have been assigned yet.'),
                    ),
                  )
                else
                  for (final project in page.projects)
                    _ProjectManagementCard(
                      project: project,
                      employees: page.assignableEmployees,
                      canChangeSupervisor: session.user.isCompanyManager,
                      canChangeStatus:
                          session.user.isCompanyManager ||
                          session.user.isSupervisor,
                    ),
              ] else
                _TeamUpdatesView(
                  page: page,
                  selectedProjectId: _projectFilter,
                  onProjectChanged: (value) =>
                      setState(() => _projectFilter = value),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createProject(
    BuildContext context,
    WidgetRef ref,
    ProjectManagementPage page,
  ) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateProjectSheet(
        employees: page.assignableEmployees,
        canChangeSupervisor: ref
            .read(authControllerProvider)
            .session!
            .user
            .isCompanyManager,
      ),
    );
    if (created == true && context.mounted) {
      ref.invalidate(projectManagementProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project assigned successfully.')),
      );
    }
  }
}

class _TeamProjectUpdate {
  const _TeamProjectUpdate({
    required this.project,
    required this.assignment,
    required this.update,
  });

  final EmployeeProject project;
  final ProjectAssignmentItem assignment;
  final ProjectUpdateItem update;
}

List<_TeamProjectUpdate> _projectUpdates(EmployeeProject project) {
  final updates = <_TeamProjectUpdate>[];
  for (final assignment in project.assignments) {
    for (final update in assignment.updates) {
      updates.add(
        _TeamProjectUpdate(
          project: project,
          assignment: assignment,
          update: update,
        ),
      );
    }
  }
  updates.sort(
    (a, b) => (b.update.createdAt ?? b.update.periodStart ?? DateTime(0))
        .compareTo(a.update.createdAt ?? a.update.periodStart ?? DateTime(0)),
  );
  return updates;
}

class _TeamUpdatesView extends StatelessWidget {
  const _TeamUpdatesView({
    required this.page,
    required this.selectedProjectId,
    required this.onProjectChanged,
  });

  final ProjectManagementPage page;
  final int? selectedProjectId;
  final ValueChanged<int?> onProjectChanged;

  @override
  Widget build(BuildContext context) {
    final selected =
        page.projects.any((project) => project.id == selectedProjectId)
        ? selectedProjectId
        : null;
    final updates = page.projects
        .where((project) => selected == null || project.id == selected)
        .expand(_projectUpdates)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<int?>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Project filter',
                prefixIcon: Icon(Icons.filter_alt_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All projects'),
                ),
                ...page.projects.map(
                  (project) => DropdownMenuItem<int?>(
                    value: project.id,
                    child: Text(
                      '${project.name} (${project.code})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
              onChanged: onProjectChanged,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (updates.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.update_rounded, size: 42),
                  SizedBox(height: 8),
                  Text(
                    'No team updates yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Submitted updates will appear here with the employee name.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          for (final item in updates) _TeamUpdateCard(item: item),
      ],
    );
  }
}

class _ProjectUpdatesSection extends StatelessWidget {
  const _ProjectUpdatesSection({required this.updates});

  final List<_TeamProjectUpdate> updates;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x1424D6A3),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x5524D6A3)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                size: 17,
                color: Colors.tealAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Team project updates',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text('${updates.length}'),
            ],
          ),
          const SizedBox(height: 8),
          for (final update in updates) _ProjectUpdateEntry(item: update),
        ],
      ),
    ),
  );
}

class _ProjectUpdateEntry extends StatelessWidget {
  const _ProjectUpdateEntry({required this.item});

  final _TeamProjectUpdate item;

  @override
  Widget build(BuildContext context) {
    final update = item.update;
    final employee =
        item.assignment.employeeName ??
        item.assignment.employeeCode ??
        'Employee';
    final date = update.createdAt ?? update.periodStart;
    final period = update.periodType.isEmpty
        ? 'Project update'
        : '${update.periodType[0].toUpperCase()}${update.periodType.substring(1)} update';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                child: Text(employee.substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '$period${date == null ? '' : ' • ${DateFormat.yMMMd().format(date)}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${update.progressPercent}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if ((update.achievements ?? '').trim().isNotEmpty)
            _UpdateDetail(label: 'Achievements', value: update.achievements!),
          if ((update.blockers ?? '').trim().isNotEmpty)
            _UpdateDetail(label: 'Blockers', value: update.blockers!),
          if ((update.nextPlan ?? '').trim().isNotEmpty)
            _UpdateDetail(label: 'Next plan', value: update.nextPlan!),
        ],
      ),
    );
  }
}

class _TeamUpdateCard extends StatelessWidget {
  const _TeamUpdateCard({required this.item});

  final _TeamProjectUpdate item;

  @override
  Widget build(BuildContext context) {
    final update = item.update;
    final employee =
        item.assignment.employeeName ??
        item.assignment.employeeCode ??
        'Employee';
    final date = update.createdAt ?? update.periodStart;
    final periodLabel = update.periodType.isEmpty
        ? 'Update'
        : '${update.periodType[0].toUpperCase()}${update.periodType.substring(1)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(employee.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${item.project.name} • ${item.project.code}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text('${update.progressPercent}%'),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              '$periodLabel${date == null ? '' : ' • ${DateFormat.yMMMd().format(date)}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((update.achievements ?? '').trim().isNotEmpty)
              _UpdateDetail(label: 'Achievements', value: update.achievements!),
            if ((update.blockers ?? '').trim().isNotEmpty)
              _UpdateDetail(label: 'Blockers', value: update.blockers!),
            if ((update.nextPlan ?? '').trim().isNotEmpty)
              _UpdateDetail(label: 'Next plan', value: update.nextPlan!),
          ],
        ),
      ),
    );
  }
}

class _UpdateDetail extends StatelessWidget {
  const _UpdateDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProjectManagementCard extends ConsumerWidget {
  const _ProjectManagementCard({
    required this.project,
    required this.employees,
    required this.canChangeSupervisor,
    required this.canChangeStatus,
  });
  final EmployeeProject project;
  final List<ProjectMemberOption> employees;
  final bool canChangeSupervisor;
  final bool canChangeStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = project.assignments
        .map((item) => item.employeeName ?? item.employeeCode ?? 'Employee')
        .join(', ');
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
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                StatusBadge(project.status),
              ],
            ),
            const SizedBox(height: 7),
            Text('${project.code} • ${project.healthStatus.toUpperCase()}'),
            const SizedBox(height: 9),
            Text(
              members.isEmpty ? 'No team members' : 'Team: $members',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (project.endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'Deadline ${DateFormat.yMMMd().format(project.endDate!)}',
                ),
              ),
            const SizedBox(height: 9),
            _ProjectUpdatePreview(
              updates: project.assignments
                  .expand((assignment) => assignment.updates)
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Supervisor: ${project.supervisorName ?? 'Not assigned'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _ProjectMembersSheet(
                        project: project,
                        employees: employees,
                        canChangeSupervisor: canChangeSupervisor,
                      ),
                    );
                    ref.invalidate(projectManagementProvider);
                  },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Manage team'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (canChangeStatus)
              Align(
                alignment: Alignment.centerRight,
                child: project.status == 'completed'
                    ? FilledButton.tonalIcon(
                        onPressed: () =>
                            _changeProjectStatus(context, ref, rollback: true),
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Rollback project'),
                      )
                    : FilledButton.icon(
                        onPressed: () =>
                            _changeProjectStatus(context, ref, rollback: false),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Complete project'),
                      ),
              )
            else
              const Text(
                'Completion is locked. Tenant HR/Admin or the project supervisor can complete it.',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProjectStatus(
    BuildContext context,
    WidgetRef ref, {
    required bool rollback,
  }) async {
    final confirmed = await _showProjectActionConfirmation(
      context,
      title: rollback ? 'Rollback project?' : 'Complete project?',
      message: rollback
          ? 'Move this project back to active so the team can continue updates?'
          : 'Mark this project as completed? Team members will keep access to their submitted updates.',
      confirmLabel: rollback ? 'Rollback project' : 'Complete project',
      danger: rollback,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final repository = ref.read(employeeWorkRepositoryProvider);
      if (rollback) {
        await repository.rollbackProject(project.id);
      } else {
        await repository.completeProject(project.id);
      }
      ref.invalidate(projectManagementProvider);
      final employeeId = ref.read(authControllerProvider).session?.employeeId;
      if (employeeId != null) {
        ref.invalidate(dashboardAssignedProjectsProvider(employeeId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rollback
                  ? 'Project rolled back to active.'
                  : 'Project marked as complete.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

Future<bool> _showProjectActionConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => TweenAnimationBuilder<double>(
      tween: Tween(begin: .86, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AlertDialog(
        icon: CircleAvatar(
          radius: 28,
          backgroundColor: (danger ? Colors.red : Colors.deepOrange).withValues(
            alpha: .16,
          ),
          child: Icon(
            danger ? Icons.warning_amber_rounded : Icons.auto_awesome,
            color: danger ? Colors.redAccent : Colors.deepOrangeAccent,
            size: 30,
          ),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class _ProjectUpdatePreview extends StatelessWidget {
  const _ProjectUpdatePreview({required this.updates});

  final List<ProjectUpdateItem> updates;

  @override
  Widget build(BuildContext context) {
    final sorted = [...updates]
      ..sort(
        (a, b) => (b.createdAt ?? b.periodStart ?? DateTime(0)).compareTo(
          a.createdAt ?? a.periodStart ?? DateTime(0),
        ),
      );
    final latest = sorted.isEmpty ? null : sorted.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: latest == null
            ? Colors.white.withValues(alpha: .035)
            : const Color(0x1424D6A3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: latest == null
              ? Colors.white.withValues(alpha: .07)
              : const Color(0x5524D6A3),
        ),
      ),
      child: latest == null
          ? const Text(
              'No updates submitted yet.',
              style: TextStyle(fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.tealAccent,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Latest project update',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('${latest.progressPercent}%'),
                  ],
                ),
                if ((latest.achievements ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    latest.achievements!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CreateProjectSheet extends ConsumerStatefulWidget {
  const _CreateProjectSheet({
    required this.employees,
    required this.canChangeSupervisor,
  });
  final List<ProjectMemberOption> employees;
  final bool canChangeSupervisor;

  @override
  ConsumerState<_CreateProjectSheet> createState() =>
      _CreateProjectSheetState();
}

class _CreateProjectSheetState extends ConsumerState<_CreateProjectSheet> {
  final name = TextEditingController();
  final employeeSearch = TextEditingController();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 14));
  final selected = <int>{};
  int? supervisorId;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    employeeSearch.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final value = await showDatePicker(
      context: context,
      initialDate: end ? endDate : startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (end) {
        endDate = value.isBefore(startDate) ? startDate : value;
      } else {
        startDate = value;
        if (endDate.isBefore(value)) endDate = value;
      }
    });
  }

  Future<bool> _confirmSave(String projectName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.86, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AlertDialog(
          icon: const CircleAvatar(radius: 28, child: Icon(Icons.auto_awesome)),
          title: const Text('Assign this project?'),
          content: Text(
            'Assign $projectName to ${selected.length} selected team member(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Assign project'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    final projectName = name.text.trim();
    if (projectName.isEmpty || selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a name and select at least one employee.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (!await _confirmSave(projectName)) return;
    setState(() => saving = true);
    try {
      await ref
          .read(employeeWorkRepositoryProvider)
          .createProject(
            name: projectName,
            startDate: startDate,
            endDate: endDate,
            employeeIds: selected.toList(),
            supervisorId: supervisorId,
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
            'Assign new project',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Project name'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(end: false),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Start ${DateFormat.yMMMd().format(startDate)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(end: true),
                icon: const Icon(Icons.event_outlined),
                label: Text('Deadline ${DateFormat.yMMMd().format(endDate)}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.canChangeSupervisor) ...[
            DropdownButtonFormField<int?>(
              initialValue: supervisorId,
              decoration: const InputDecoration(
                labelText: 'Project supervisor',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No supervisor selected'),
                ),
                ...widget.employees
                    .where(
                      (employee) =>
                          employee.roleType.toLowerCase() == 'supervisor',
                    )
                    .map(
                      (employee) => DropdownMenuItem<int?>(
                        value: employee.id,
                        child: Text('${employee.name} (${employee.code})'),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => supervisorId = value),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Assign team members',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: employeeSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search employees',
            ),
          ),
          const SizedBox(height: 6),
          for (final employee in widget.employees.where((employee) {
            final query = employeeSearch.text.trim().toLowerCase();
            return query.isEmpty ||
                [
                  employee.name,
                  employee.code,
                  employee.roleType,
                  employee.department,
                  employee.designation,
                ].whereType<String>().any(
                  (value) => value.toLowerCase().contains(query),
                );
          }))
            CheckboxListTile(
              value: selected.contains(employee.id),
              onChanged: (value) => setState(() {
                if (value == true) {
                  selected.add(employee.id);
                } else {
                  selected.remove(employee.id);
                }
              }),
              title: Text(employee.name),
              subtitle: Text(
                [
                  employee.code,
                  employee.roleType,
                  employee.designation,
                ].where((value) => value?.isNotEmpty == true).join(' • '),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch_outlined),
            label: Text(saving ? 'Assigning…' : 'Assign project'),
          ),
        ],
      ),
    ),
  );
}

class _ProjectMembersSheet extends ConsumerStatefulWidget {
  const _ProjectMembersSheet({
    required this.project,
    required this.employees,
    required this.canChangeSupervisor,
  });

  final EmployeeProject project;
  final List<ProjectMemberOption> employees;
  final bool canChangeSupervisor;

  @override
  ConsumerState<_ProjectMembersSheet> createState() =>
      _ProjectMembersSheetState();
}

class _ProjectMembersSheetState extends ConsumerState<_ProjectMembersSheet> {
  late final Set<int> memberIds;
  final Set<int> selectedToAdd = <int>{};
  late int? supervisorId;
  final search = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    memberIds = widget.project.assignments
        .map((item) => item.employeeId)
        .toSet();
    supervisorId = widget.project.supervisorId;
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String _memberName(int id) {
    for (final assignment in widget.project.assignments) {
      if (assignment.employeeId == id) {
        return assignment.employeeName ?? assignment.employeeCode ?? 'Employee';
      }
    }
    for (final employee in widget.employees) {
      if (employee.id == id) return employee.name;
    }
    return 'Employee';
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      ref.invalidate(projectManagementProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.86, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AlertDialog(
          icon: CircleAvatar(
            radius: 28,
            backgroundColor: (danger ? Colors.red : Colors.deepOrange)
                .withValues(alpha: 0.16),
            child: Icon(
              danger ? Icons.warning_amber_rounded : Icons.auto_awesome,
              color: danger ? Colors.redAccent : Colors.deepOrangeAccent,
              size: 30,
            ),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _addSelected() async {
    final ids = selectedToAdd.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one employee to add.')),
      );
      return;
    }
    final names = ids.map(_memberName).join(', ');
    final confirmed = await _confirmAction(
      title: 'Add team members?',
      message:
          'Add ${ids.length} selected employee(s) to this project?\n$names',
      confirmLabel: 'Add selected',
    );
    if (!confirmed) return;
    await _run(() async {
      final repository = ref.read(employeeWorkRepositoryProvider);
      for (final employeeId in ids) {
        await repository.addProjectMember(
          projectId: widget.project.id,
          employeeId: employeeId,
        );
      }
      if (mounted) {
        setState(() {
          memberIds.addAll(ids);
          selectedToAdd.clear();
        });
      }
    });
  }

  Future<void> _remove(int employeeId) async {
    if (employeeId == supervisorId) {
      await _confirmAction(
        title: 'Release not available',
        message:
            'This employee is the project supervisor. Ask tenant HR/Admin to change the supervisor before releasing them.',
        confirmLabel: 'Got it',
      );
      return;
    }
    final subordinateIds = widget.employees
        .map((employee) => employee.id)
        .toSet();
    if (!widget.canChangeSupervisor && !subordinateIds.contains(employeeId)) {
      await _confirmAction(
        title: 'Release not available',
        message:
            'You can release only your own active subordinates. This employee is outside your subordinate team.',
        confirmLabel: 'Got it',
      );
      return;
    }
    final confirmed = await _confirmAction(
      title: 'Release from project?',
      message:
          'Release ${_memberName(employeeId)} from this project? Their submitted updates will remain available.',
      confirmLabel: 'Release employee',
      danger: true,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref
          .read(employeeWorkRepositoryProvider)
          .removeProjectMember(
            projectId: widget.project.id,
            employeeId: employeeId,
          );
      if (mounted) setState(() => memberIds.remove(employeeId));
    });
  }

  Future<void> _changeSupervisor(int? value) async {
    await _run(() async {
      await ref
          .read(employeeWorkRepositoryProvider)
          .changeProjectSupervisor(
            projectId: widget.project.id,
            supervisorId: value,
          );
      setState(() => supervisorId = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final available = widget.employees.where((employee) {
      if (memberIds.contains(employee.id)) return false;
      if (query.isEmpty) return true;
      return [
        employee.name,
        employee.code,
        employee.roleType,
        employee.department,
        employee.designation,
      ].whereType<String>().any((value) => value.toLowerCase().contains(query));
    }).toList();
    final supervisors = widget.employees
        .where((employee) => employee.roleType.toLowerCase() == 'supervisor')
        .toList();
    final subordinateIds = widget.employees
        .map((employee) => employee.id)
        .toSet();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manage project team',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(widget.project.name),
            if (widget.canChangeSupervisor) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: supervisorId,
                decoration: const InputDecoration(
                  labelText: 'Project supervisor',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No supervisor selected'),
                  ),
                  ...supervisors.map(
                    (employee) => DropdownMenuItem<int?>(
                      value: employee.id,
                      child: Text('${employee.name} (${employee.code})'),
                    ),
                  ),
                ],
                onChanged: busy ? null : _changeSupervisor,
              ),
            ] else if (widget.project.supervisorName != null) ...[
              const SizedBox(height: 12),
              Text('Supervisor: ${widget.project.supervisorName}'),
            ],
            const SizedBox(height: 18),
            const Text(
              'Current team',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            if (memberIds.isEmpty)
              const Text('No team members assigned.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: memberIds
                    .map(
                      (id) => Chip(
                        label: Text(_memberName(id)),
                        onDeleted:
                            busy ||
                                id == supervisorId ||
                                (!widget.canChangeSupervisor &&
                                    !subordinateIds.contains(id))
                            ? null
                            : () => _remove(id),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 18),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search employees to add',
              ),
            ),
            const SizedBox(height: 8),
            if (available.isEmpty)
              const Text('No additional allowed employees found.')
            else
              for (final employee in available)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selectedToAdd.contains(employee.id),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          if (value ?? false) {
                            selectedToAdd.add(employee.id);
                          } else {
                            selectedToAdd.remove(employee.id);
                          }
                        }),
                  title: Text(employee.name),
                  subtitle: Text(
                    [employee.code, employee.roleType, employee.designation]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(' • '),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy || selectedToAdd.isEmpty ? null : _addSelected,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(
                selectedToAdd.isEmpty
                    ? 'Add selected employees'
                    : 'Add selected (${selectedToAdd.length})',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: busy ? null : () => Navigator.pop(context, true),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
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

class _InterviewsTab extends ConsumerStatefulWidget {
  const _InterviewsTab();

  @override
  ConsumerState<_InterviewsTab> createState() => _InterviewsTabState();
}

class _InterviewsTabState extends ConsumerState<_InterviewsTab> {
  final _search = TextEditingController();
  String _view = 'assigned';
  String? _mode;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  late Future<InterviewTaskPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<InterviewTaskPage> _load() => ref
      .read(employeeWorkRepositoryProvider)
      .interviewPage(
        view: _view,
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        dateFrom: _from == null ? null : _date(_from!),
        dateTo: _to == null ? null : _date(_to!),
        mode: _mode,
        page: _page,
      );

  Future<void> _reload({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from
        ? (_from ?? DateTime.now())
        : (_to ?? _from ?? DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value == null || !mounted) return;
    if (from) {
      _from = value;
      if (_to != null && _to!.isBefore(value)) _to = value;
    } else {
      _to = value;
      if (_from != null && _from!.isAfter(value)) _from = value;
    }
    await _reload(reset: true);
  }

  void _clearFilters() {
    _search.clear();
    _mode = null;
    _from = null;
    _to = null;
    _reload(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider).session!.user.id;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _view == 'completed'
                        ? 'Completed interviews'
                        : 'Assigned interviews',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tab in const [
                        ('assigned', 'Assigned'),
                        ('completed', 'Completed'),
                        ('all', 'All'),
                      ])
                        ChoiceChip(
                          selected: _view == tab.$1,
                          label: Text(tab.$2),
                          onSelected: (_) {
                            setState(() => _view = tab.$1);
                            _reload(reset: true);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onSubmitted: (_) => _reload(reset: true),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () => _reload(reset: true),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      hintText: 'Search name, email or position',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Mode'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All modes')),
                      DropdownMenuItem(
                        value: 'in_person',
                        child: Text('In person'),
                      ),
                      DropdownMenuItem(
                        value: 'virtual',
                        child: Text('Virtual'),
                      ),
                      DropdownMenuItem(value: 'phone', child: Text('Phone')),
                    ],
                    onChanged: (value) {
                      setState(() => _mode = value);
                      _reload(reset: true);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(from: true),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _from == null
                              ? 'From date'
                              : DateFormat.yMMMd().format(_from!),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          _to == null
                              ? 'To date'
                              : DateFormat.yMMMd().format(_to!),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<InterviewTaskPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(snapshot.error.toString()),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _reload,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final result = snapshot.data!;
              if (result.items.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const Icon(Icons.record_voice_over_outlined, size: 42),
                        const SizedBox(height: 10),
                        Text(
                          _view == 'completed'
                              ? 'No completed interviews'
                              : 'No interviews found',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Try another tab, date range or search term.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < result.items.length; index++)
                    _WorkAnimatedCard(
                      index: index,
                      child: Builder(
                        builder: (context) {
                          final item = result.items[index];
                          final mine = item.feedbackBy(userId);
                          return _InterviewTaskCard(
                            task: item,
                            feedback: mine,
                            onOpen: () => _showFeedback(item, mine),
                            onResume: item.resumeName == null
                                ? null
                                : () => _downloadResume(item),
                          );
                        },
                      ),
                    ),
                  _WorkPageControls(
                    page: result.page,
                    lastPage: result.lastPage,
                    total: result.total,
                    previous: result.page > 1
                        ? () {
                            _page--;
                            _reload();
                          }
                        : null,
                    next: result.hasMore
                        ? () {
                            _page++;
                            _reload();
                          }
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedback(
    InterviewTask task,
    InterviewFeedbackItem? existing,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InterviewFeedbackSheet(
        task: task,
        existing: existing,
        onResume: task.resumeName == null ? null : () => _downloadResume(task),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _downloadResume(InterviewTask task) async {
    try {
      final path = await ref
          .read(employeeWorkRepositoryProvider)
          .downloadResume(
            candidateId: task.candidateId,
            fileName: task.resumeName ?? 'candidate_resume',
          );
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resume downloaded. ${result.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _WorkAnimatedCard extends StatelessWidget {
  const _WorkAnimatedCard({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 240 + index.clamp(0, 6) * 45),
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Transform.translate(
      offset: Offset(0, 14 * (1 - value)),
      child: Opacity(opacity: value, child: child),
    ),
    child: Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
  );
}

class _WorkPageControls extends StatelessWidget {
  const _WorkPageControls({
    required this.page,
    required this.lastPage,
    required this.total,
    this.previous,
    this.next,
  });

  final int page, lastPage, total;
  final VoidCallback? previous, next;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text('$total interviews · Page $page of $lastPage')),
      IconButton(onPressed: previous, icon: const Icon(Icons.chevron_left)),
      IconButton(onPressed: next, icon: const Icon(Icons.chevron_right)),
    ],
  );
}

class _InterviewTaskCard extends StatelessWidget {
  const _InterviewTaskCard({
    required this.task,
    required this.feedback,
    required this.onOpen,
    this.onResume,
  });

  final InterviewTask task;
  final InterviewFeedbackItem? feedback;
  final VoidCallback onOpen;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 320),
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Transform.translate(
      offset: Offset(0, 14 * (1 - value)),
      child: Opacity(opacity: value, child: child),
    ),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x1511D8FF), Color(0x12FF5A72)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0x24FF6B00),
                      child: Text(
                        _initials(task.candidateName),
                        style: const TextStyle(
                          color: Color(0xFFFF7A00),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.candidateName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            task.position.isEmpty
                                ? 'Position not specified'
                                : task.position,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      feedback == null ? 'feedback pending' : 'completed',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 9,
                    children: [
                      _detail(
                        Icons.event_outlined,
                        DateFormat.yMMMd().format(task.scheduledAt),
                      ),
                      _detail(
                        Icons.schedule_outlined,
                        DateFormat.jm().format(task.scheduledAt),
                      ),
                      _detail(Icons.videocam_outlined, _label(task.mode)),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                if (task.candidateEmail.isNotEmpty)
                  _detail(Icons.email_outlined, task.candidateEmail),
                if (task.candidatePhone != null)
                  _detail(Icons.phone_outlined, task.candidatePhone!),
                if (task.resumeName != null) ...[
                  _detail(
                    Icons.description_outlined,
                    'Resume: ${task.resumeName}',
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: onResume,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('View / download resume'),
                    ),
                  ),
                ],
                if (task.notes != null) ...[
                  const Divider(height: 22),
                  Text(
                    task.notes!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (feedback != null) ...[
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
                      Text(
                        '${feedback!.rating}/5 • ${_label(feedback!.recommendation)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: Text(
                        feedback == null ? 'Give feedback' : 'View / update',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  static Widget _detail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF57D5FF)),
        const SizedBox(width: 7),
        Flexible(child: Text(value)),
      ],
    ),
  );

  static String _label(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static String _initials(String value) => value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class _InterviewFeedbackSheet extends ConsumerStatefulWidget {
  const _InterviewFeedbackSheet({
    required this.task,
    this.existing,
    this.onResume,
  });
  final InterviewTask task;
  final InterviewFeedbackItem? existing;
  final VoidCallback? onResume;

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
          const SizedBox(height: 5),
          Text(
            widget.task.position.isEmpty
                ? 'Position not specified'
                : widget.task.position,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0x1211D8FF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InterviewTaskCard._detail(
                    Icons.event_available_outlined,
                    DateFormat.yMMMd().add_jm().format(widget.task.scheduledAt),
                  ),
                  _InterviewTaskCard._detail(
                    Icons.videocam_outlined,
                    _InterviewTaskCard._label(widget.task.mode),
                  ),
                  if (widget.task.candidateEmail.isNotEmpty)
                    _InterviewTaskCard._detail(
                      Icons.email_outlined,
                      widget.task.candidateEmail,
                    ),
                  if (widget.task.candidatePhone != null)
                    _InterviewTaskCard._detail(
                      Icons.phone_outlined,
                      widget.task.candidatePhone!,
                    ),
                  if (widget.task.resumeName != null) ...[
                    _InterviewTaskCard._detail(
                      Icons.description_outlined,
                      'Resume: ${widget.task.resumeName}',
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: widget.onResume,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('View / download resume'),
                      ),
                    ),
                  ],
                  if (widget.task.notes != null) ...[
                    const Divider(),
                    Text(
                      'Interview notes',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(widget.task.notes!),
                  ],
                ],
              ),
            ),
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
