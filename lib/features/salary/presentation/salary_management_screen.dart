import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/salary/data/salary_designer_store.dart';
import 'package:vistora_mobile/features/salary/data/salary_repository.dart';
import 'package:vistora_mobile/features/salary/domain/salary_models.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>(
  (ref) => SalaryRepository(ref.watch(apiClientProvider)),
);

final salaryDesignerStoreProvider = Provider<SalaryDesignerStore>(
  (ref) => SalaryDesignerStore(),
);

class SalaryManagementScreen extends ConsumerStatefulWidget {
  const SalaryManagementScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<SalaryManagementScreen> createState() =>
      _SalaryManagementScreenState();
}

class _SalaryManagementScreenState
    extends ConsumerState<SalaryManagementScreen> {
  late final TextEditingController _search;
  Timer? _debounce;
  int _year = DateTime.now().year;
  int _page = 1;
  late Future<SalaryRosterPage> _future;
  SalaryDesignerState _designer = SalaryDesignerState.defaults;
  bool _designerLoading = true;

  SalaryRepository get repository => ref.read(salaryRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _future = _load();
    _loadDesigner();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<SalaryRosterPage> _load() => repository.roster(
    year: _year,
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    page: _page,
  );

  Future<void> _refresh({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _showEmployee(SalaryRosterEmployee employee) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _SalaryDetailSheet(
        employee: employee,
        year: _year,
        repository: repository,
        designer: _designer,
        onChanged: _refresh,
      ),
    );
  }

  Future<void> _loadDesigner() async {
    final corpId =
        ref.read(authControllerProvider).session?.user.corpId ?? 'default';
    final value = await ref.read(salaryDesignerStoreProvider).read(corpId);
    if (mounted) {
      setState(() {
        _designer = value;
        _designerLoading = false;
      });
    }
  }

  Future<void> _saveDesigner(SalaryDesignerState value) async {
    final previous = _designer;
    setState(() => _designer = value);
    try {
      final corpId =
          ref.read(authControllerProvider).session?.user.corpId ?? 'default';
      await ref.read(salaryDesignerStoreProvider).write(corpId, value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _designer = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save salary designer: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var offset = -4; offset <= 1; offset++) DateTime.now().year + offset,
    ]..sort((a, b) => b.compareTo(a));
    return DefaultTabController(
      length: 6,
      initialIndex: widget.initialQuery == null ? 0 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Salary Structure'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: Icon(Icons.settings_suggest_outlined),
                text: 'Pay Components',
              ),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Pay Groups'),
              Tab(
                icon: Icon(Icons.calculate_outlined),
                text: 'Formula Builder',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet_outlined),
                text: 'Salary Structure',
              ),
              Tab(icon: Icon(Icons.trending_up), text: 'Revisions'),
              Tab(icon: Icon(Icons.add_card_outlined), text: 'Arrears'),
            ],
          ),
        ),
        body: _designerLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ComponentsWorkspace(
                    designer: _designer,
                    onChanged: _saveDesigner,
                  ),
                  _PayGroupsWorkspace(
                    designer: _designer,
                    onChanged: _saveDesigner,
                  ),
                  _FormulaWorkspace(
                    designer: _designer,
                    onChanged: _saveDesigner,
                  ),
                  _buildRoster(years, _SalaryWorkspaceMode.structure),
                  _buildRoster(years, _SalaryWorkspaceMode.revisions),
                  _buildRoster(years, _SalaryWorkspaceMode.arrears),
                ],
              ),
      ),
    );
  }

  Widget _buildRoster(List<int> years, _SalaryWorkspaceMode mode) =>
      RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<SalaryRosterPage>(
          future: _future,
          builder: (context, snapshot) {
            final result = snapshot.data;
            return ListView(
              key: PageStorageKey(mode.name),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                _SalaryHero(total: result?.total, year: _year, mode: mode),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 560;
                    final search = TextField(
                      controller: mode == _SalaryWorkspaceMode.structure
                          ? _search
                          : null,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search employee name, ID or email',
                      ),
                      onChanged: (value) {
                        if (mode != _SalaryWorkspaceMode.structure) {
                          _search.value = TextEditingValue(
                            text: value,
                            selection: TextSelection.collapsed(
                              offset: value.length,
                            ),
                          );
                        }
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 300),
                          () => mounted ? _refresh(reset: true) : null,
                        );
                      },
                    );
                    final year = DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: years
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null || value == _year) return;
                        _year = value;
                        _refresh(reset: true);
                      },
                    );
                    return stacked
                        ? Column(
                            children: [
                              search,
                              const SizedBox(height: 12),
                              year,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(flex: 3, child: search),
                              const SizedBox(width: 12),
                              Expanded(child: year),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(44),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  _SalaryError(error: snapshot.error, retry: _refresh)
                else if (result == null || result.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_outlined, size: 42),
                          SizedBox(height: 10),
                          Text('No active employees match this search.'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...result.items.asMap().entries.map(
                    (entry) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 230 + entry.key * 35),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: _SalaryEmployeeCard(
                        employee: entry.value,
                        year: _year,
                        mode: mode,
                        open: () => _showEmployee(entry.value),
                      ),
                    ),
                  ),
                  _PageControls(
                    page: result.page,
                    lastPage: result.lastPage,
                    previous: result.page > 1
                        ? () {
                            _page--;
                            _refresh();
                          }
                        : null,
                    next: result.hasMore
                        ? () {
                            _page++;
                            _refresh();
                          }
                        : null,
                  ),
                ],
              ],
            );
          },
        ),
      );
}

enum _SalaryWorkspaceMode { structure, revisions, arrears }

class _ComponentsWorkspace extends StatelessWidget {
  const _ComponentsWorkspace({required this.designer, required this.onChanged});

  final SalaryDesignerState designer;
  final Future<void> Function(SalaryDesignerState) onChanged;

  Future<void> _edit(
    BuildContext context, [
    SalaryPayComponent? component,
  ]) async {
    final value = await showModalBottomSheet<SalaryPayComponent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ComponentEditor(
        component:
            component ??
            SalaryPayComponent(
              id: designer.nextComponentId(),
              name: '',
              code: '',
              type: 'Earning',
              taxable: '1',
              description: '',
            ),
        isNew: component == null,
      ),
    );
    if (value == null) return;
    final duplicate = designer.components.any(
      (item) =>
          item.id != value.id &&
          (item.name.toLowerCase() == value.name.toLowerCase() ||
              item.code.toLowerCase() == value.code.toLowerCase()),
    );
    if (duplicate && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Component name and code must be unique.'),
        ),
      );
      return;
    }
    final next = [
      ...designer.components.where((item) => item.id != value.id),
      value,
    ]..sort((a, b) => a.id.compareTo(b.id));
    await onChanged(designer.copyWith(components: next));
  }

  Future<void> _delete(
    BuildContext context,
    SalaryPayComponent component,
  ) async {
    final usedBy = designer.payGroups
        .where((group) => group.componentIds.contains(component.id))
        .map((group) => group.name)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text('Delete ${component.name}?'),
        content: Text(
          usedBy.isEmpty
              ? 'The component and its formula will be removed.'
              : 'It will also be removed from: ${usedBy.join(', ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await onChanged(
      designer.copyWith(
        components: designer.components
            .where((item) => item.id != component.id)
            .toList(),
        payGroups: designer.payGroups
            .map(
              (group) => group.copyWith(
                componentIds: group.componentIds
                    .where((id) => id != component.id)
                    .toList(),
              ),
            )
            .toList(),
        formulas: designer.formulas
            .where(
              (formula) =>
                  formula.componentId != component.id &&
                  formula.referenceComponentId != component.id,
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
    children: [
      const _DesignerHero(
        icon: Icons.settings_suggest_outlined,
        title: 'Pay components',
        subtitle:
            'Create earnings, deductions, and reimbursements used by salary structures.',
        colors: [Color(0xFF0F3B32), Color(0xFF17142C)],
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add component'),
        ),
      ),
      const SizedBox(height: 14),
      if (designer.components.isEmpty)
        const _DesignerEmpty(
          icon: Icons.settings_suggest_outlined,
          title: 'No pay components',
          subtitle: 'Add a component before creating a pay group.',
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 760
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: designer.components.asMap().entries.map((entry) {
                final component = entry.value;
                final color = _componentColor(component.type);
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 220 + entry.key * 35),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: color.withValues(alpha: .24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  component.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _DesignerPill(component.type, color),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            component.code,
                            style: const TextStyle(
                              color: VistoraColors.muted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            component.description.isEmpty
                                ? 'No description'
                                : component.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _DesignerPill(
                                component.taxable == '1'
                                    ? 'Taxable'
                                    : component.taxable == 'partial'
                                    ? 'Part taxable'
                                    : 'Non-taxable',
                                component.taxable == '1'
                                    ? VistoraColors.amber
                                    : VistoraColors.cyan,
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                tooltip: 'Edit component',
                                onPressed: () => _edit(context, component),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                tooltip: 'Delete component',
                                onPressed: () => _delete(context, component),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
    ],
  );
}

class _PayGroupsWorkspace extends StatelessWidget {
  const _PayGroupsWorkspace({required this.designer, required this.onChanged});

  final SalaryDesignerState designer;
  final Future<void> Function(SalaryDesignerState) onChanged;

  Future<void> _edit(BuildContext context, [SalaryPayGroup? group]) async {
    final value = await showModalBottomSheet<SalaryPayGroup>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PayGroupEditor(
        group:
            group ??
            SalaryPayGroup(
              id: designer.nextPayGroupId(),
              name: '',
              componentIds: const [],
            ),
        components: designer.components,
        isNew: group == null,
      ),
    );
    if (value == null) return;
    if (designer.payGroups.any(
      (item) =>
          item.id != value.id &&
          item.name.toLowerCase() == value.name.toLowerCase(),
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pay group name must be unique.')),
        );
      }
      return;
    }
    final groups = [
      ...designer.payGroups.where((item) => item.id != value.id),
      value,
    ]..sort((a, b) => a.id.compareTo(b.id));
    await onChanged(designer.copyWith(payGroups: groups));
  }

  Future<void> _delete(BuildContext context, SalaryPayGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: const Text(
          'Existing employee salary snapshots remain unchanged. The group will no longer be available for new assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onChanged(
        designer.copyWith(
          payGroups: designer.payGroups
              .where((item) => item.id != group.id)
              .toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
    children: [
      const _DesignerHero(
        icon: Icons.inventory_2_outlined,
        title: 'Pay groups',
        subtitle:
            'Bundle components into reusable packages for employee salary assignment.',
        colors: [Color(0xFF2B1E48), Color(0xFF093047)],
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: designer.components.isEmpty ? null : () => _edit(context),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Create pay group'),
        ),
      ),
      const SizedBox(height: 14),
      if (designer.payGroups.isEmpty)
        const _DesignerEmpty(
          icon: Icons.inventory_2_outlined,
          title: 'No pay groups',
          subtitle: 'Create a reusable group of salary components.',
        )
      else
        ...designer.payGroups.asMap().entries.map((entry) {
          final group = entry.value;
          final members = group.componentIds
              .map(designer.componentById)
              .whereType<SalaryPayComponent>()
              .toList();
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 230 + entry.key * 45),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            ),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0x223AA7FF),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: VistoraColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _DesignerPill(
                          '${members.length} components',
                          VistoraColors.cyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: members
                          .map(
                            (item) => Chip(
                              avatar: Icon(
                                item.isDeduction
                                    ? Icons.remove_circle_outline
                                    : Icons.add_circle_outline,
                                size: 16,
                              ),
                              label: Text(item.name),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _edit(context, group),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: () => _delete(context, group),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
    ],
  );
}

class _FormulaWorkspace extends StatelessWidget {
  const _FormulaWorkspace({required this.designer, required this.onChanged});

  final SalaryDesignerState designer;
  final Future<void> Function(SalaryDesignerState) onChanged;

  Future<void> _edit(BuildContext context, [SalaryFormula? formula]) async {
    final value = await showModalBottomSheet<SalaryFormula>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FormulaEditor(
        formula:
            formula ??
            SalaryFormula(
              id: designer.nextFormulaId(),
              componentId: designer.components.isEmpty
                  ? 0
                  : designer.components.first.id,
              type: 'fixed',
              value: 0,
            ),
        designer: designer,
        isNew: formula == null,
      ),
    );
    if (value == null) return;
    if (_wouldCreateFormulaCycle(designer, value)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This formula would create a circular reference.'),
          ),
        );
      }
      return;
    }
    final formulas = [
      ...designer.formulas.where(
        (item) => item.id != value.id && item.componentId != value.componentId,
      ),
      value,
    ]..sort((a, b) => a.id.compareTo(b.id));
    await onChanged(designer.copyWith(formulas: formulas));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
    children: [
      const _DesignerHero(
        icon: Icons.calculate_outlined,
        title: 'Formula builder',
        subtitle:
            'Define fixed, CTC-based, component-based, or manually entered salary rules.',
        colors: [Color(0xFF3A2416), Color(0xFF151A3A)],
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: designer.components.isEmpty ? null : () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add formula'),
        ),
      ),
      const SizedBox(height: 14),
      if (designer.formulas.isEmpty)
        const _DesignerEmpty(
          icon: Icons.calculate_outlined,
          title: 'No formulas defined',
          subtitle: 'Add a calculation rule for a salary component.',
        )
      else
        ...designer.formulas.asMap().entries.map((entry) {
          final formula = entry.value;
          final component = designer.componentById(formula.componentId);
          final reference = designer.componentById(
            formula.referenceComponentId ?? 0,
          );
          final color = _componentColor(component?.type ?? 'Earning');
          return Card(
            margin: const EdgeInsets.only(bottom: 11),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: .12),
                child: Icon(Icons.functions, color: color),
              ),
              title: Text(
                component?.name ?? 'Unknown component',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(_formulaDescription(formula, reference)),
              ),
              trailing: Wrap(
                spacing: 3,
                children: [
                  IconButton(
                    tooltip: 'Edit formula',
                    onPressed: () => _edit(context, formula),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove formula',
                    onPressed: () => onChanged(
                      designer.copyWith(
                        formulas: designer.formulas
                            .where((item) => item.id != formula.id)
                            .toList(),
                      ),
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          );
        }),
    ],
  );
}

class _ComponentEditor extends StatefulWidget {
  const _ComponentEditor({required this.component, required this.isNew});
  final SalaryPayComponent component;
  final bool isNew;

  @override
  State<_ComponentEditor> createState() => _ComponentEditorState();
}

class _ComponentEditorState extends State<_ComponentEditor> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _description;
  late String _type;
  late String _taxable;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.component.name);
    _code = TextEditingController(text: widget.component.code);
    _description = TextEditingController(text: widget.component.description);
    _type = widget.component.type;
    _taxable = widget.component.taxable;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      18,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isNew ? 'Add pay component' : 'Edit pay component',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Component name'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const ['Earning', 'Deduction', 'Reimbursement']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _taxable,
            decoration: const InputDecoration(labelText: 'Tax treatment'),
            items: const [
              DropdownMenuItem(value: '1', child: Text('Taxable')),
              DropdownMenuItem(value: 'partial', child: Text('Part taxable')),
              DropdownMenuItem(value: '0', child: Text('Non-taxable')),
            ],
            onChanged: (value) => setState(() => _taxable = value ?? _taxable),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              if (!_key.currentState!.validate()) return;
              Navigator.pop(
                context,
                widget.component.copyWith(
                  name: _name.text.trim(),
                  code: _code.text.trim().toUpperCase(),
                  type: _type,
                  taxable: _taxable,
                  description: _description.text.trim(),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save component'),
          ),
        ],
      ),
    ),
  );
}

class _PayGroupEditor extends StatefulWidget {
  const _PayGroupEditor({
    required this.group,
    required this.components,
    required this.isNew,
  });
  final SalaryPayGroup group;
  final List<SalaryPayComponent> components;
  final bool isNew;

  @override
  State<_PayGroupEditor> createState() => _PayGroupEditorState();
}

class _PayGroupEditorState extends State<_PayGroupEditor> {
  late final TextEditingController _name;
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.name)
      ..addListener(_refresh);
    _selected = widget.group.componentIds.toSet();
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _name.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .82,
    minChildSize: .55,
    maxChildSize: .96,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          widget.isNew ? 'Create pay group' : 'Edit pay group',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 17),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Pay group name'),
        ),
        const SizedBox(height: 18),
        const Text(
          'Included components',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...widget.components.map(
          (component) => CheckboxListTile(
            value: _selected.contains(component.id),
            secondary: Icon(
              component.isDeduction
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
              color: _componentColor(component.type),
            ),
            title: Text(component.name),
            subtitle: Text('${component.code} · ${component.type}'),
            onChanged: (value) => setState(
              () => value == true
                  ? _selected.add(component.id)
                  : _selected.remove(component.id),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _name.text.trim().isEmpty || _selected.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  widget.group.copyWith(
                    name: _name.text.trim(),
                    componentIds: _selected.toList()..sort(),
                  ),
                ),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save pay group'),
        ),
      ],
    ),
  );
}

class _FormulaEditor extends StatefulWidget {
  const _FormulaEditor({
    required this.formula,
    required this.designer,
    required this.isNew,
  });
  final SalaryFormula formula;
  final SalaryDesignerState designer;
  final bool isNew;

  @override
  State<_FormulaEditor> createState() => _FormulaEditorState();
}

class _FormulaEditorState extends State<_FormulaEditor> {
  late int _componentId;
  late String _type;
  late int? _referenceId;
  late final TextEditingController _value;

  @override
  void initState() {
    super.initState();
    _componentId = widget.formula.componentId;
    _type = widget.formula.type;
    _referenceId = widget.formula.referenceComponentId;
    _value = TextEditingController(
      text: widget.formula.value == 0
          ? ''
          : widget.formula.value.toStringAsFixed(
              widget.formula.value % 1 == 0 ? 0 : 2,
            ),
    )..addListener(_refresh);
  }

  @override
  void dispose() {
    _value.removeListener(_refresh);
    _value.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final references = widget.designer.components
        .where((item) => item.id != _componentId)
        .toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isNew ? 'Formula builder' : 'Edit formula',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: _componentId,
            decoration: const InputDecoration(labelText: 'Component'),
            items: widget.designer.components
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _componentId = value ?? _componentId;
              if (_referenceId == _componentId) _referenceId = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Calculation type'),
            items: const [
              DropdownMenuItem(value: 'fixed', child: Text('Fixed amount')),
              DropdownMenuItem(
                value: 'percent_ctc',
                child: Text('% of annual CTC'),
              ),
              DropdownMenuItem(
                value: 'percent_comp',
                child: Text('% of another component'),
              ),
              DropdownMenuItem(value: 'manual', child: Text('Variable/manual')),
            ],
            onChanged: (value) => setState(() {
              _type = value ?? _type;
              if (_type != 'percent_comp') _referenceId = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type.startsWith('percent')
                  ? 'Percentage'
                  : 'Monthly amount',
              prefixText: _type.startsWith('percent') ? null : '₹ ',
              suffixText: _type.startsWith('percent') ? '%' : null,
            ),
          ),
          if (_type == 'percent_comp') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: references.any((item) => item.id == _referenceId)
                  ? _referenceId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Reference component',
              ),
              items: references
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _referenceId = value),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed:
                double.tryParse(_value.text.trim()) == null ||
                    (_type == 'percent_comp' && _referenceId == null)
                ? null
                : () => Navigator.pop(
                    context,
                    widget.formula.copyWith(
                      componentId: _componentId,
                      type: _type,
                      value: double.parse(_value.text.trim()),
                      referenceComponentId: _referenceId,
                      clearReference: _type != 'percent_comp',
                    ),
                  ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save formula'),
          ),
        ],
      ),
    );
  }
}

class _DesignerHero extends StatelessWidget {
  const _DesignerHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      gradient: LinearGradient(colors: colors),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .18)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: .08),
          child: Icon(icon, color: VistoraColors.orange),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DesignerEmpty extends StatelessWidget {
  const _DesignerEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 42, color: VistoraColors.muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _DesignerPill extends StatelessWidget {
  const _DesignerPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withValues(alpha: .28)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}

Color _componentColor(String type) => switch (type.toLowerCase()) {
  'deduction' => VistoraColors.pink,
  'reimbursement' => VistoraColors.amber,
  _ => VistoraColors.green,
};

String _formulaDescription(
  SalaryFormula formula,
  SalaryPayComponent? reference,
) => switch (formula.type) {
  'percent_ctc' => '${_compactNumber(formula.value)}% of monthly CTC',
  'percent_comp' =>
    '${_compactNumber(formula.value)}% of ${reference?.name ?? 'another component'}',
  'manual' => 'Variable/manual monthly value · ${_money(formula.value)}',
  _ => 'Fixed monthly amount · ${_money(formula.value)}',
};

String _compactNumber(double value) => value % 1 == 0
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

bool _wouldCreateFormulaCycle(
  SalaryDesignerState designer,
  SalaryFormula candidate,
) {
  if (candidate.type != 'percent_comp' ||
      candidate.referenceComponentId == null) {
    return false;
  }
  final graph = <int, int>{};
  for (final formula in designer.formulas) {
    if (formula.componentId != candidate.componentId &&
        formula.type == 'percent_comp' &&
        formula.referenceComponentId != null) {
      graph[formula.componentId] = formula.referenceComponentId!;
    }
  }
  graph[candidate.componentId] = candidate.referenceComponentId!;
  final seen = <int>{};
  var current = candidate.componentId;
  while (graph[current] != null) {
    if (!seen.add(current)) return true;
    current = graph[current]!;
  }
  return false;
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

class _SalaryDetailSheet extends StatefulWidget {
  const _SalaryDetailSheet({
    required this.employee,
    required this.year,
    required this.repository,
    required this.designer,
    required this.onChanged,
  });

  final SalaryRosterEmployee employee;
  final int year;
  final SalaryRepository repository;
  final SalaryDesignerState designer;
  final Future<void> Function() onChanged;

  @override
  State<_SalaryDetailSheet> createState() => _SalaryDetailSheetState();
}

class _SalaryDetailSheetState extends State<_SalaryDetailSheet> {
  late Future<SalaryEmployeeDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.detail(widget.employee.employeeId);
  }

  Future<void> _reload() async {
    setState(
      () => _future = widget.repository.detail(widget.employee.employeeId),
    );
    await Future.wait([_future, widget.onChanged()]);
  }

  Future<void> _revise() async {
    final input = await showModalBottomSheet<_RevisionInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RevisionEditor(year: widget.year),
    );
    if (input == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.revise(
        employeeId: widget.employee.employeeId,
        year: widget.year,
        revisionDate: input.revisionDate,
        incrementAmount: input.increment,
        arrearEffectiveDate: input.arrearEffectiveDate,
      );
      await _reload();
      if (mounted) {
        _message('Salary revision applied and draft payroll refreshed.');
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(SalaryStructureRecord? current) async {
    final input = await showModalBottomSheet<_SalaryStructureInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SalaryStructureEditor(
        year: widget.year,
        designer: widget.designer,
        current: current,
      ),
    );
    if (input == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.upsertStructure(
        employeeId: widget.employee.employeeId,
        year: widget.year,
        payGroupName: input.group.name,
        payGroupSnapshot: widget.designer.snapshotFor(input.group),
        annualCtc: input.annualCtc,
        breakup: input.breakup,
      );
      await _reload();
      if (mounted) {
        _message(
          current == null
              ? 'Salary structure assigned successfully.'
              : 'Salary structure updated successfully.',
        );
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rollback(SalaryRevisionRecord revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.history),
        title: const Text('Rollback salary revision?'),
        content: const Text(
          'The latest applied increment and its pending arrears will be reversed. Released payroll is never altered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.rollback(
        employeeId: widget.employee.employeeId,
        revisionId: revision.id,
      );
      await _reload();
      if (mounted) _message('Latest salary revision rolled back.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF5A182B) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .92,
    minChildSize: .55,
    maxChildSize: .98,
    builder: (context, controller) => FutureBuilder<SalaryEmployeeDetail>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final structure = detail?.forYear(widget.year);
        final revisions =
            detail?.revisions
                .where((item) => item.year == widget.year)
                .toList() ??
            const <SalaryRevisionRecord>[];
        SalaryRevisionRecord? latestApplied;
        for (final revision in revisions) {
          if (revision.actionStatus == 'applied') {
            latestApplied = revision;
            break;
          }
        }
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: VistoraColors.orange.withValues(alpha: .15),
                  child: Text(
                    _initials(widget.employee.name),
                    style: const TextStyle(
                      color: VistoraColors.orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${widget.employee.code} · ${widget.year} salary'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(45),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot.hasError)
              _SalaryError(
                error: snapshot.error,
                retry: () => setState(
                  () => _future = widget.repository.detail(
                    widget.employee.employeeId,
                  ),
                ),
              )
            else if (structure == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No salary structure for ${widget.year}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a pay group, preview its component formulas, and assign this employee’s annual CTC.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy || widget.designer.payGroups.isEmpty
                            ? null
                            : () => _assign(null),
                        icon: const Icon(Icons.add_card_outlined),
                        label: const Text('Assign salary structure'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _StructureCard(structure: structure),
              const SizedBox(height: 12),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy || widget.designer.payGroups.isEmpty
                        ? null
                        : () => _assign(structure),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit structure'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _revise,
                    icon: const Icon(Icons.trending_up),
                    label: const Text('Apply salary revision'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Revision history',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (revisions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No revisions recorded for this year.'),
                  ),
                )
              else
                ...revisions.map(
                  (revision) => _RevisionCard(
                    revision: revision,
                    canRollback:
                        latestApplied?.id == revision.id &&
                        revision.canRollback,
                    busy: _busy,
                    rollback: () => _rollback(revision),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _SalaryStructureInput {
  const _SalaryStructureInput({
    required this.group,
    required this.annualCtc,
    required this.breakup,
  });

  final SalaryPayGroup group;
  final double annualCtc;
  final SalaryBreakup breakup;
}

class _SalaryStructureEditor extends StatefulWidget {
  const _SalaryStructureEditor({
    required this.year,
    required this.designer,
    this.current,
  });

  final int year;
  final SalaryDesignerState designer;
  final SalaryStructureRecord? current;

  @override
  State<_SalaryStructureEditor> createState() => _SalaryStructureEditorState();
}

class _SalaryStructureEditorState extends State<_SalaryStructureEditor> {
  late final TextEditingController _ctc;
  late int _groupId;

  @override
  void initState() {
    super.initState();
    SalaryPayGroup? selected;
    for (final group in widget.designer.payGroups) {
      if (group.name.toLowerCase() ==
          widget.current?.payGroupName.toLowerCase()) {
        selected = group;
        break;
      }
    }
    selected ??= widget.designer.payGroups.first;
    _groupId = selected.id;
    _ctc = TextEditingController(
      text: widget.current == null
          ? ''
          : widget.current!.ctcAnnual.toStringAsFixed(0),
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctc.removeListener(_refresh);
    _ctc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.designer.payGroups.firstWhere(
      (item) => item.id == _groupId,
    );
    final annualCtc = double.tryParse(_ctc.text.trim()) ?? 0;
    final breakup = widget.designer.calculate(group, annualCtc);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .94,
      minChildSize: .65,
      maxChildSize: .98,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 30,
        ),
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x22FF6B00),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: VistoraColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.current == null
                          ? 'Assign salary structure'
                          : 'Edit salary structure',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('${widget.year} · API-backed employee salary'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: _groupId,
            decoration: const InputDecoration(labelText: 'Pay group'),
            items: widget.designer.payGroups
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _groupId = value ?? _groupId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctc,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Annual CTC',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MoneyChip(
                'Gross / month',
                breakup.grossMonthly,
                VistoraColors.cyan,
              ),
              _MoneyChip(
                'Deductions',
                breakup.deductionMonthly,
                VistoraColors.pink,
              ),
              _MoneyChip(
                'Net / month',
                breakup.netMonthly,
                VistoraColors.green,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Salary breakup preview',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: VistoraColors.cyan.withValues(alpha: .19),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('COMPONENT')),
                  DataColumn(label: Text('TYPE')),
                  DataColumn(label: Text('MONTHLY')),
                  DataColumn(label: Text('ANNUAL')),
                ],
                rows: breakup.lines
                    .map(
                      (line) => DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.component.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  line.component.code,
                                  style: const TextStyle(
                                    color: VistoraColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            _DesignerPill(
                              line.component.type,
                              _componentColor(line.component.type),
                            ),
                          ),
                          DataCell(Text(_money(line.monthly))),
                          DataCell(Text(_money(line.annual))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: annualCtc <= 0 || breakup.lines.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    _SalaryStructureInput(
                      group: group,
                      annualCtc: annualCtc,
                      breakup: breakup,
                    ),
                  ),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              widget.current == null ? 'Assign structure' : 'Update structure',
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionEditor extends StatefulWidget {
  const _RevisionEditor({required this.year});
  final int year;

  @override
  State<_RevisionEditor> createState() => _RevisionEditorState();
}

class _RevisionEditorState extends State<_RevisionEditor> {
  final _form = GlobalKey<FormState>();
  final _increment = TextEditingController();
  DateTime _revisionDate = DateTime.now();
  DateTime? _arrearEffectiveDate;

  @override
  void dispose() {
    _increment.dispose();
    super.dispose();
  }

  Future<void> _pickRevision() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _revisionDate,
      firstDate: DateTime(widget.year),
      lastDate: DateTime(widget.year, 12, 31),
    );
    if (value != null) setState(() => _revisionDate = value);
  }

  Future<void> _pickEffective() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _arrearEffectiveDate ?? _revisionDate,
      firstDate: DateTime(widget.year),
      lastDate: _revisionDate,
    );
    if (value != null) setState(() => _arrearEffectiveDate = value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Apply salary revision',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Laravel scales the existing structure proportionally and calculates eligible arrears.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _increment,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Annual increment amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter an amount greater than zero.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickRevision,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                'Revision date · ${DateFormat.yMMMd().format(_revisionDate)}',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickEffective,
              icon: const Icon(Icons.history),
              label: Text(
                _arrearEffectiveDate == null
                    ? 'Set arrear effective date (optional)'
                    : 'Arrears from · ${DateFormat.yMMMd().format(_arrearEffectiveDate!)}',
              ),
            ),
            if (_arrearEffectiveDate != null)
              TextButton(
                onPressed: () => setState(() => _arrearEffectiveDate = null),
                child: const Text('Remove arrear date'),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _RevisionInput(
                    increment: double.parse(_increment.text.trim()),
                    revisionDate: _revisionDate,
                    arrearEffectiveDate: _arrearEffectiveDate,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Apply revision'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RevisionInput {
  const _RevisionInput({
    required this.increment,
    required this.revisionDate,
    this.arrearEffectiveDate,
  });
  final double increment;
  final DateTime revisionDate;
  final DateTime? arrearEffectiveDate;
}

class _SalaryHero extends StatelessWidget {
  const _SalaryHero({
    required this.total,
    required this.year,
    required this.mode,
  });
  final int? total;
  final int year;
  final _SalaryWorkspaceMode mode;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      gradient: const LinearGradient(
        colors: [Color(0xFF3B201D), Color(0xFF082C43)],
      ),
      border: Border.all(color: VistoraColors.orange.withValues(alpha: .26)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0x33FF6B00),
          child: Icon(switch (mode) {
            _SalaryWorkspaceMode.structure =>
              Icons.account_balance_wallet_outlined,
            _SalaryWorkspaceMode.revisions => Icons.trending_up,
            _SalaryWorkspaceMode.arrears => Icons.add_card_outlined,
          }, color: VistoraColors.orange),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (mode) {
                  _SalaryWorkspaceMode.structure => 'Salary structure',
                  _SalaryWorkspaceMode.revisions => 'Salary revisions',
                  _SalaryWorkspaceMode.arrears => 'Arrears control',
                },
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(switch (mode) {
                _SalaryWorkspaceMode.structure =>
                  '${total ?? '—'} active employees · $year structures',
                _SalaryWorkspaceMode.revisions =>
                  'Select an employee to apply or rollback $year revisions',
                _SalaryWorkspaceMode.arrears =>
                  'Review revision arrears or use Payroll to add manual arrears',
              }),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SalaryEmployeeCard extends StatelessWidget {
  const _SalaryEmployeeCard({
    required this.employee,
    required this.year,
    required this.mode,
    required this.open,
  });
  final SalaryRosterEmployee employee;
  final int year;
  final _SalaryWorkspaceMode mode;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) {
    final salary = employee.salary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: VistoraColors.cyan.withValues(alpha: .12),
                    child: Text(
                      _initials(employee.name),
                      style: const TextStyle(
                        color: VistoraColors.cyan,
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
                          employee.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          employee.code,
                          style: const TextStyle(color: VistoraColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    salary == null
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: salary == null
                        ? VistoraColors.amber
                        : VistoraColors.green,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (salary == null)
                Text(
                  'No $year salary structure',
                  style: const TextStyle(
                    color: VistoraColors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else ...[
                Text(
                  salary.payGroupName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MoneyChip(
                      'Annual CTC',
                      salary.ctcAnnual,
                      VistoraColors.orange,
                    ),
                    _MoneyChip(
                      'Net / month',
                      salary.netMonthly,
                      VistoraColors.green,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: open,
                  icon: Icon(switch (mode) {
                    _SalaryWorkspaceMode.structure => Icons.edit_outlined,
                    _SalaryWorkspaceMode.revisions => Icons.trending_up,
                    _SalaryWorkspaceMode.arrears => Icons.add_card_outlined,
                  }),
                  label: Text(switch (mode) {
                    _SalaryWorkspaceMode.structure => 'View & assign structure',
                    _SalaryWorkspaceMode.revisions => 'Revision history',
                    _SalaryWorkspaceMode.arrears => 'Review arrears',
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructureCard extends StatelessWidget {
  const _StructureCard({required this.structure});
  final SalaryStructureRecord structure;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFF12243A), Color(0xFF17142C)],
      ),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          structure.payGroupName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _SalaryLine('Annual CTC', structure.ctcAnnual, VistoraColors.orange),
        _SalaryLine(
          'Gross monthly',
          structure.grossMonthly,
          VistoraColors.cyan,
        ),
        _SalaryLine(
          'Deductions',
          structure.deductionMonthly,
          VistoraColors.pink,
        ),
        _SalaryLine(
          'Net monthly',
          structure.netMonthly,
          VistoraColors.green,
          strong: true,
        ),
      ],
    ),
  );
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.revision,
    required this.canRollback,
    required this.busy,
    required this.rollback,
  });
  final SalaryRevisionRecord revision;
  final bool canRollback;
  final bool busy;
  final VoidCallback rollback;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMd().format(revision.revisionDate),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(revision.actionStatus),
            ],
          ),
          const SizedBox(height: 9),
          _SalaryLine(
            'Annual increment',
            revision.incrementAmount,
            VistoraColors.orange,
          ),
          _SalaryLine(
            'Old net / month',
            revision.oldNetMonthly,
            VistoraColors.muted,
          ),
          _SalaryLine(
            'New net / month',
            revision.newNetMonthly,
            VistoraColors.green,
          ),
          if (revision.arrearsDue > 0)
            _SalaryLine(
              'Arrears due · ${revision.arrearsStatus}',
              revision.arrearsDue,
              VistoraColors.amber,
            ),
          if (canRollback)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : rollback,
                icon: const Icon(Icons.undo),
                label: const Text('Rollback latest revision'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SalaryLine extends StatelessWidget {
  const _SalaryLine(this.label, this.amount, this.color, {this.strong = false});
  final String label;
  final double amount;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          _money(amount),
          style: TextStyle(
            color: color,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            fontSize: strong ? 17 : null,
          ),
        ),
      ],
    ),
  );
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label ${_money(amount)}',
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'applied'
        ? VistoraColors.green
        : VistoraColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.lastPage,
    this.previous,
    this.next,
  });
  final int page;
  final int lastPage;
  final VoidCallback? previous;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Page $page of $lastPage',
          style: const TextStyle(color: VistoraColors.muted),
        ),
      ),
      IconButton.filledTonal(
        onPressed: previous,
        icon: const Icon(Icons.chevron_left),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        onPressed: next,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _SalaryError extends StatelessWidget {
  const _SalaryError({required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 38, color: VistoraColors.pink),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
