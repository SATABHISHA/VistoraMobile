import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/performance/domain/performance_models.dart';
import 'package:vistora_mobile/features/performance/presentation/performance_providers.dart';

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;
  late DateTime _period;
  late TextEditingController _searchController;
  String _search = '';
  int _pageNumber = 1;
  int _pageSize = 6;

  @override
  void initState() {
    super.initState();
    _period = DateTime(DateTime.now().year, DateTime.now().month);
    _searchController = TextEditingController();
    _tabs = TabController(length: 1, vsync: this);
    _tabs.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabs.indexIsChanging && mounted && _pageNumber != 1) {
      setState(() => _pageNumber = 1);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(performancePageProvider);
    await ref.read(performancePageProvider.future);
  }

  void _syncTabs(bool manager, bool supervisor) {
    final length = manager
        ? 3
        : supervisor
        ? 4
        : 1;
    if (_tabs.length == length) return;
    final oldIndex = _tabs.index;
    _tabs.dispose();
    _tabs = TabController(length: length, vsync: this);
    _tabs.addListener(_handleTabChanged);
    _tabs.index = oldIndex.clamp(0, length - 1);
  }

  void _setSearch(String value) {
    setState(() {
      _search = value.trim();
      _pageNumber = 1;
    });
  }

  void _setPageSize(int? value) {
    if (value == null) return;
    setState(() {
      _pageSize = value;
      _pageNumber = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    if (session == null) return const SizedBox.shrink();
    final role = session.user.normalizedRole;
    final manager = session.user.isCompanyManager;
    final supervisor = role == 'supervisor';
    _syncTabs(manager, supervisor);
    final page = ref.watch(performancePageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            tooltip: 'Refresh performance',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Back to dashboard',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _PerformanceContent(
          child: AsyncErrorCard(error: error, onRetry: _refresh),
        ),
        data: (value) {
          _syncTabs(manager, supervisor);
          final tabViews = _tabViews(
            context: context,
            page: value,
            manager: manager,
            supervisor: supervisor,
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                children: [
                  _PerformanceHero(
                    company:
                        session.companyName ?? session.user.corpId ?? 'Tenant',
                    role: session.user.roleType,
                    manager: manager,
                  ),
                  if (manager || supervisor) ...[
                    const SizedBox(height: 8),
                    _periodPicker(context),
                  ],
                  const SizedBox(height: 8),
                  _PerformanceTabs(
                    controller: _tabs,
                    manager: manager,
                    supervisor: supervisor,
                  ),
                  _PerformanceSearchTools(
                    controller: _searchController,
                    pageSize: _pageSize,
                    onSearch: _setSearch,
                    onPageSizeChanged: _setPageSize,
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _tabs,
                    builder: (context, _) {
                      final index = _tabs.index.clamp(0, tabViews.length - 1);
                      return tabViews[index];
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tabViews({
    required BuildContext context,
    required PerformancePage page,
    required bool manager,
    required bool supervisor,
  }) {
    final views = <Widget>[];
    if (manager || supervisor) {
      views.add(
        _ReviewsView(
          page: page,
          period: _period,
          canManage: true,
          onAdd: () => _openReviewForm(context, page),
          onEdit: (review) => _openReviewForm(context, page, review: review),
          onDelete: _deleteReview,
          query: _search,
          pageNumber: _pageNumber,
          pageSize: _pageSize,
          onPageChanged: (value) => setState(() => _pageNumber = value),
        ),
      );
      views.add(
        _KpiView(
          page: page,
          period: _period,
          canManage: true,
          onAdd: (id) => _openReviewForm(context, page, employeeId: id),
          query: _search,
          pageNumber: _pageNumber,
          pageSize: _pageSize,
          onPageChanged: (value) => setState(() => _pageNumber = value),
        ),
      );
      views.add(
        _ReportView(
          page: page,
          period: _period,
          query: _search,
          pageNumber: _pageNumber,
          pageSize: _pageSize,
          onPageChanged: (value) => setState(() => _pageNumber = value),
        ),
      );
    }
    if (!manager) {
      views.add(
        _MyPerformanceView(
          page: page,
          query: _search,
          pageNumber: _pageNumber,
          pageSize: _pageSize,
          onPageChanged: (value) => setState(() => _pageNumber = value),
        ),
      );
    }
    return views;
  }

  Widget _periodPicker(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(7, (index) => currentYear + 2 - index);
    final months = List<int>.generate(12, (index) => index + 1);
    return _PerformanceContent(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final year = DropdownButtonFormField<int>(
            initialValue: _period.year,
            decoration: const InputDecoration(
              labelText: 'Year',
              prefixIcon: Icon(Icons.event_outlined),
            ),
            items: [
              for (final value in years)
                DropdownMenuItem(value: value, child: Text('$value')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _period = DateTime(value, _period.month);
                  _pageNumber = 1;
                });
              }
            },
          );
          final month = DropdownButtonFormField<int>(
            initialValue: _period.month,
            decoration: const InputDecoration(
              labelText: 'Month',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: [
              for (final value in months)
                DropdownMenuItem(
                  value: value,
                  child: Text(DateFormat.MMMM().format(DateTime(2000, value))),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _period = DateTime(_period.year, value);
                  _pageNumber = 1;
                });
              }
            },
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [year, const SizedBox(height: 10), month],
                )
              : Row(
                  children: [
                    Expanded(child: year),
                    const SizedBox(width: 10),
                    Expanded(child: month),
                  ],
                );
        },
      ),
    );
  }

  Future<void> _deleteReview(PerformanceReviewItem review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete performance review?'),
        content: Text(
          'Delete the ${review.periodLabel} review for ${review.employeeName}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(performanceRepositoryProvider).deleteReview(review.id);
      ref.invalidate(performancePageProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Performance review deleted successfully.'),
          ),
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

  Future<void> _openReviewForm(
    BuildContext context,
    PerformancePage page, {
    int? employeeId,
    PerformanceReviewItem? review,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewFormSheet(
        page: page,
        defaultEmployeeId: review?.employeeId ?? employeeId,
        period: review == null
            ? _period
            : DateTime(review.reviewYear, review.reviewMonth),
        existingReview: review,
      ),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(performancePageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            review == null
                ? 'Performance review saved successfully.'
                : 'Performance review updated successfully.',
          ),
        ),
      );
    }
  }
}

/// Constrains performance content without creating a nested vertical scroll
/// view. The tab views own the single mobile scroll position.
class _PerformanceContent extends StatelessWidget {
  const _PerformanceContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: child,
      ),
    ),
  );
}

class _PerformanceHero extends StatelessWidget {
  const _PerformanceHero({
    required this.company,
    required this.role,
    required this.manager,
  });

  final String company;
  final String role;
  final bool manager;

  @override
  Widget build(BuildContext context) => _PerformanceContent(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x332F145D), Color(0x33204B68)],
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: VistoraColors.amber,
                size: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance workspace',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$company • $role • ${manager ? 'Team reviews and reports' : 'Your reviews and feedback'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PerformanceSearchTools extends StatelessWidget {
  const _PerformanceSearchTools({
    required this.controller,
    required this.pageSize,
    required this.onSearch,
    required this.onPageSizeChanged,
  });

  final TextEditingController controller;
  final int pageSize;
  final ValueChanged<String> onSearch;
  final ValueChanged<int?> onPageSizeChanged;

  @override
  Widget build(BuildContext context) => _PerformanceContent(
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x1AFF6A00), Color(0x1A00D2FF)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final search = TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                labelText: 'Search this tab',
                hintText: 'Name, employee code, department or comment',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          controller.clear();
                          onSearch('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            );
            final pageSizeField = DropdownButtonFormField<int>(
              initialValue: pageSize,
              decoration: const InputDecoration(
                labelText: 'Rows per page',
                prefixIcon: Icon(Icons.view_list_outlined),
              ),
              items: const [6, 9, 12]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value')),
                  )
                  .toList(),
              onChanged: onPageSizeChanged,
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 10),
                      pageSizeField,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      SizedBox(width: 150, child: pageSizeField),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}

class _PerformanceTabs extends StatelessWidget {
  const _PerformanceTabs({
    required this.controller,
    required this.manager,
    required this.supervisor,
  });

  final TabController controller;
  final bool manager;
  final bool supervisor;

  @override
  Widget build(BuildContext context) => _PerformanceContent(
    child: Material(
      color: Colors.transparent,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabs: [
          if (manager || supervisor)
            const Tab(
              icon: Icon(Icons.stars_outlined),
              text: 'Monthly Reviews',
            ),
          if (manager || supervisor)
            const Tab(
              icon: Icon(Icons.analytics_outlined),
              text: 'KPI Scoring',
            ),
          if (manager || supervisor)
            const Tab(
              icon: Icon(Icons.assessment_outlined),
              text: 'Performance Report',
            ),
          if (!manager)
            const Tab(icon: Icon(Icons.person_outline), text: 'My Performance'),
        ],
      ),
    ),
  );
}

class _ReviewsView extends StatelessWidget {
  const _ReviewsView({
    required this.page,
    required this.period,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.query,
    required this.pageNumber,
    required this.pageSize,
    required this.onPageChanged,
  });

  final PerformancePage page;
  final DateTime period;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<PerformanceReviewItem> onEdit;
  final ValueChanged<PerformanceReviewItem> onDelete;
  final String query;
  final int pageNumber;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final allowed = _eligible(page);
    final ids = allowed.map((item) => item.id).toSet();
    final reviews = page.reviews
        .where(
          (review) =>
              ids.contains(review.employeeId) &&
              review.reviewMonth == period.month &&
              review.reviewYear == period.year &&
              _matchesReview(review, query),
        )
        .toList();
    final pageItems = _pageItems(reviews, pageNumber, pageSize);
    return Column(
      children: [
        _PerformanceContent(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                'Monthly performance reviews',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              );
              final add = FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add review'),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    if (canManage) ...[
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: add),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  if (canManage) add,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          const _PerformanceContent(
            child: EmptyState(
              title: 'No reviews for this month',
              message: 'Add a review to start tracking the selected period.',
              icon: Icons.stars_outlined,
            ),
          )
        else ...[
          for (var i = 0; i < pageItems.length; i++)
            _ReviewCard(
              review: pageItems[i],
              index: i,
              canManage: canManage,
              onEdit: () => onEdit(pageItems[i]),
              onDelete: () => onDelete(pageItems[i]),
            ),
          _PaginationControls(
            total: reviews.length,
            pageNumber: pageNumber,
            pageSize: pageSize,
            onPageChanged: onPageChanged,
          ),
        ],
      ],
    );
  }
}

class _KpiView extends StatelessWidget {
  const _KpiView({
    required this.page,
    required this.period,
    required this.canManage,
    required this.onAdd,
    required this.query,
    required this.pageNumber,
    required this.pageSize,
    required this.onPageChanged,
  });

  final PerformancePage page;
  final DateTime period;
  final bool canManage;
  final void Function(int id) onAdd;
  final String query;
  final int pageNumber;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final employees = _eligible(
      page,
    ).where((employee) => _matchesEmployee(employee, query)).toList();
    final ids = employees.map((item) => item.id).toSet();
    final reviews = page.reviews
        .where(
          (review) =>
              ids.contains(review.employeeId) &&
              review.reviewMonth == period.month &&
              review.reviewYear == period.year,
        )
        .toList();
    final pageEmployees = _pageItems(employees, pageNumber, pageSize);
    return Column(
      children: [
        _PerformanceContent(
          child: Text(
            'KPI scoring for ${DateFormat.yMMMM().format(period)}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 14),
        if (pageEmployees.isEmpty)
          const _PerformanceContent(
            child: EmptyState(
              title: 'No employees found',
              message: 'Try another name, employee code or department.',
              icon: Icons.search_off_outlined,
            ),
          ),
        for (final employee in pageEmployees)
          _KpiCard(
            employee: employee,
            reviews: reviews
                .where((item) => item.employeeId == employee.id)
                .toList(),
            canManage: canManage,
            onAdd: () => onAdd(employee.id),
          ),
        if (employees.isNotEmpty)
          _PaginationControls(
            total: employees.length,
            pageNumber: pageNumber,
            pageSize: pageSize,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.page,
    required this.period,
    required this.query,
    required this.pageNumber,
    required this.pageSize,
    required this.onPageChanged,
  });

  final PerformancePage page;
  final DateTime period;
  final String query;
  final int pageNumber;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final reviews = page.reviews
        .where(
          (item) =>
              _eligible(
                page,
              ).any((employee) => employee.id == item.employeeId) &&
              item.reviewMonth == period.month &&
              item.reviewYear == period.year &&
              _matchesReview(item, query),
        )
        .toList();
    final pageItems = _pageItems(reviews, pageNumber, pageSize);
    final double average = reviews.isEmpty
        ? 0.0
        : reviews.map((item) => item.overallScore).reduce((a, b) => a + b) /
              reviews.length;
    return Column(
      children: [
        _PerformanceContent(
          child: Text(
            'Performance report · ${DateFormat.yMMMM().format(period)}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 14),
        _PerformanceContent(
          child: _ReportSummary(reviewCount: reviews.length, average: average),
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          const _PerformanceContent(
            child: EmptyState(
              title: 'No report data',
              message: 'Saved reviews will appear in this report.',
              icon: Icons.assessment_outlined,
            ),
          ),
        for (var i = 0; i < pageItems.length; i++)
          _ReviewCard(review: pageItems[i], index: i),
        if (reviews.isNotEmpty)
          _PaginationControls(
            total: reviews.length,
            pageNumber: pageNumber,
            pageSize: pageSize,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}

class _MyPerformanceView extends StatelessWidget {
  const _MyPerformanceView({
    required this.page,
    required this.query,
    required this.pageNumber,
    required this.pageSize,
    required this.onPageChanged,
  });

  final PerformancePage page;
  final String query;
  final int pageNumber;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final reviews = page.reviews
        .where(
          (item) =>
              item.employeeId == page.currentEmployeeId &&
              _matchesReview(item, query),
        )
        .toList();
    final pageItems = _pageItems(reviews, pageNumber, pageSize);
    return Column(
      children: [
        _PerformanceContent(
          child: Text(
            'My performance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          const _PerformanceContent(
            child: EmptyState(
              title: 'No reviews yet',
              message:
                  'Your supervisor or tenant HR/Admin has not added a review yet.',
              icon: Icons.person_outline,
            ),
          ),
        for (var i = 0; i < pageItems.length; i++)
          _ReviewCard(review: pageItems[i], index: i),
        if (reviews.isNotEmpty)
          _PaginationControls(
            total: reviews.length,
            pageNumber: pageNumber,
            pageSize: pageSize,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}

bool _matchesEmployee(PerformanceEmployeeOption employee, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return [
    employee.name,
    employee.code,
    employee.roleType,
    employee.department,
    employee.designation,
  ].whereType<String>().join(' ').toLowerCase().contains(needle);
}

bool _matchesReview(PerformanceReviewItem review, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return [
    review.employeeName,
    review.employeeCode,
    review.periodLabel,
    review.comment,
    review.reviewerName,
  ].whereType<String>().join(' ').toLowerCase().contains(needle);
}

List<T> _pageItems<T>(List<T> items, int pageNumber, int pageSize) {
  final start = (pageNumber - 1) * pageSize;
  if (start >= items.length) return const [];
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.total,
    required this.pageNumber,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int total;
  final int pageNumber;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pages = (total / pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();
    final current = pageNumber.clamp(1, pages);
    return _PerformanceContent(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          runSpacing: 6,
          children: [
            Text(
              'Page $current of $pages • $total records',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            OutlinedButton.icon(
              onPressed: current > 1 ? () => onPageChanged(current - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            for (final page in _pageChoices(current, pages))
              if (page == null)
                const SizedBox(width: 20, child: Center(child: Text('…')))
              else
                SizedBox(
                  width: 40,
                  child: page == current
                      ? FilledButton(onPressed: null, child: Text('$page'))
                      : OutlinedButton(
                          onPressed: () => onPageChanged(page),
                          child: Text('$page'),
                        ),
                ),
            OutlinedButton.icon(
              onPressed: current < pages
                  ? () => onPageChanged(current + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

List<int?> _pageChoices(int current, int pages) {
  if (pages <= 5) return [for (var page = 1; page <= pages; page++) page];
  final visible = <int>{1, pages, current, current - 1, current + 1}
    ..removeWhere((page) => page < 1 || page > pages);
  final choices = <int?>[];
  for (var page = 1; page <= pages; page++) {
    if (visible.contains(page)) {
      choices.add(page);
    } else if (choices.isEmpty || choices.last != null) {
      choices.add(null);
    }
  }
  return choices;
}

List<PerformanceEmployeeOption> _eligible(PerformancePage page) {
  final me = page.currentEmployeeId;
  if (page.canManage) {
    return page.reviewableEmployees;
  }
  return page.employees.where((item) => item.id == me).toList();
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.index,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  final PerformanceReviewItem review;
  final int index;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => _PerformanceContent(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.employeeName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _ScoreBadge(review.overallScore),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${review.employeeCode} • ${review.periodLabel}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final key in performanceKpis)
                    _KpiPill(
                      label: performanceKpiLabels[key]!,
                      score: review.score(key),
                    ),
                ],
              ),
              if (review.comment?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: VistoraColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(review.comment!),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Reviewed by ${review.reviewerName ?? 'Tenant HR/Admin'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (canManage) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.employee,
    required this.reviews,
    required this.canManage,
    required this.onAdd,
  });

  final PerformanceEmployeeOption employee;
  final List<PerformanceReviewItem> reviews;
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final overall = reviews.isEmpty
        ? 0.0
        : reviews.map((item) => item.overallScore).reduce((a, b) => a + b) /
              reviews.length;
    return _PerformanceContent(
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      employee.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _ScoreBadge(overall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                employee.designation ?? employee.department ?? employee.code,
              ),
              const SizedBox(height: 15),
              for (final key in performanceKpis)
                _KpiBar(
                  label: performanceKpiLabels[key]!,
                  score: reviews.isEmpty
                      ? 0
                      : reviews
                                .map((item) => item.score(key))
                                .reduce((a, b) => a + b) /
                            reviews.length,
                ),
              if (canManage)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add review'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.reviewCount, required this.average});
  final int reviewCount;
  final double average;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'Saved reviews',
              value: '$reviewCount',
              color: VistoraColors.cyan,
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              label: 'Average score',
              value: '${average.toStringAsFixed(1)} / 10',
              color: VistoraColors.orange,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 23,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge(this.score);
  final double score;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: VistoraColors.orange.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      score.toStringAsFixed(1),
      style: const TextStyle(
        color: VistoraColors.orange,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({required this.label, required this.score});
  final String label;
  final double score;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$label  ${score.toStringAsFixed(1)} / 10'),
    avatar: const Icon(Icons.star, size: 16),
  );
}

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.label, required this.score});
  final String label;
  final double score;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '${score.toStringAsFixed(1)} / 10',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: score == 0 ? 0 : score / 10,
            minHeight: 8,
          ),
        ),
      ],
    ),
  );
}

class _ReviewFormSheet extends ConsumerStatefulWidget {
  const _ReviewFormSheet({
    required this.page,
    required this.period,
    this.defaultEmployeeId,
    this.existingReview,
  });
  final PerformancePage page;
  final DateTime period;
  final int? defaultEmployeeId;
  final PerformanceReviewItem? existingReview;
  @override
  ConsumerState<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<_ReviewFormSheet> {
  int? employeeId;
  final scores = <String, double>{for (final key in performanceKpis) key: 5};
  final comment = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final review = widget.existingReview;
    employeeId = review?.employeeId ?? widget.defaultEmployeeId;
    if (review != null) {
      for (final key in performanceKpis) {
        scores[key] = review.score(key);
      }
      comment.text = review.comment ?? '';
    }
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = _eligible(widget.page);
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add performance review',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: VistoraColors.orange,
              ),
            ),
            const SizedBox(height: 5),
            Text(DateFormat.yMMMM().format(widget.period)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: employeeId,
              decoration: const InputDecoration(labelText: 'Employee'),
              items: [
                for (final employee in employees)
                  DropdownMenuItem(
                    value: employee.id,
                    child: Text('${employee.name} · ${employee.code}'),
                  ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => employeeId = value),
            ),
            const SizedBox(height: 12),
            for (final key in performanceKpis)
              _ScoreSlider(
                label: performanceKpiLabels[key]!,
                value: scores[key]!,
                onChanged: saving
                    ? null
                    : (value) => setState(() => scores[key] = value),
              ),
            TextField(
              controller: comment,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Overall comment',
                hintText: 'Share clear, constructive feedback',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving…' : 'Save review'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an employee first.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final repository = ref.read(performanceRepositoryProvider);
      final ratings = scores.map((key, value) => MapEntry(key, value.round()));
      final note = comment.text.trim().isEmpty ? null : comment.text.trim();
      if (widget.existingReview == null) {
        await repository.saveReview(
          employeeId: employeeId!,
          month: widget.period.month,
          year: widget.period.year,
          ratings: ratings,
          comment: note,
        );
      } else {
        await repository.updateReview(
          reviewId: widget.existingReview!.id,
          employeeId: employeeId!,
          month: widget.period.month,
          year: widget.period.year,
          ratings: ratings,
          comment: note,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${value.round()} / 10',
            style: const TextStyle(
              color: VistoraColors.orange,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      Slider(value: value, min: 1, max: 10, divisions: 9, onChanged: onChanged),
    ],
  );
}
