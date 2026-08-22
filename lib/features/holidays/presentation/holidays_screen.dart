import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/core/widgets/async_state_view.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/holidays/domain/holiday.dart';
import 'package:vistora_mobile/features/holidays/presentation/holiday_providers.dart';

class HolidaysScreen extends ConsumerStatefulWidget {
  const HolidaysScreen({super.key});

  @override
  ConsumerState<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends ConsumerState<HolidaysScreen> {
  int year = DateTime.now().year;

  bool get canManage {
    final role = ref.read(authControllerProvider).session!.user.normalizedRole;
    return role == 'admin' || role == 'hr';
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(holidaysProvider(year));
    return Scaffold(
      appBar: AppBar(title: const Text('Holidays')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add Holiday'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(holidaysProvider(year));
          await ref.read(holidaysProvider(year).future);
        },
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Company holiday calendar',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  DropdownButton<int>(
                    value: year,
                    items: List.generate(
                      5,
                      (index) => DropdownMenuItem(
                        value: DateTime.now().year - 1 + index,
                        child: Text('${DateTime.now().year - 1 + index}'),
                      ),
                    ),
                    onChanged: (value) => setState(() => year = value ?? year),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AsyncErrorCard(
                  error: error,
                  onRetry: () => ref.invalidate(holidaysProvider(year)),
                ),
                data: (values) => values.isEmpty
                    ? const EmptyState(
                        title: 'No holidays configured',
                        message:
                            'Company holidays for this year will appear here.',
                        icon: Icons.calendar_month_outlined,
                      )
                    : Column(
                        children: values
                            .map(
                              (holiday) => Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(15),
                                  leading: CircleAvatar(
                                    child: Text(
                                      DateFormat('dd').format(holiday.date),
                                    ),
                                  ),
                                  title: Text(
                                    holiday.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${DateFormat.yMMMMEEEEd().format(holiday.date)} • ${holiday.type}',
                                  ),
                                  trailing: canManage
                                      ? PopupMenuButton<String>(
                                          onSelected: (action) =>
                                              action == 'edit'
                                              ? _edit(holiday)
                                              : _remove(holiday),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Remove'),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit([Holiday? holiday]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HolidaySheet(holiday: holiday),
    );
    if (saved == true) {
      ref.invalidate(holidaysProvider(year));
      ref.invalidate(upcomingHolidaysProvider);
    }
  }

  Future<void> _remove(Holiday holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove holiday?'),
        content: Text('Remove ${holiday.name} from the company calendar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(holidayRepositoryProvider).remove(holiday.id);
      ref.invalidate(holidaysProvider(year));
      ref.invalidate(upcomingHolidaysProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _HolidaySheet extends ConsumerStatefulWidget {
  const _HolidaySheet({this.holiday});
  final Holiday? holiday;

  @override
  ConsumerState<_HolidaySheet> createState() => _HolidaySheetState();
}

class _HolidaySheetState extends ConsumerState<_HolidaySheet> {
  late final TextEditingController name;
  late DateTime date;
  late String type;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.holiday?.name);
    date = widget.holiday?.date ?? DateTime.now();
    type = widget.holiday?.type ?? 'Company';
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await ref
          .read(holidayRepositoryProvider)
          .save(
            id: widget.holiday?.id,
            date: date,
            name: name.text,
            type: type,
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
            widget.holiday == null ? 'Add holiday' : 'Edit holiday',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Holiday name'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (value != null) setState(() => date = value);
            },
            icon: const Icon(Icons.event),
            label: Text(DateFormat.yMMMMEEEEd().format(date)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const ['National', 'Restricted', 'Company']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => type = value ?? type),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: saving ? null : submit,
            child: saving
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('Save Holiday'),
          ),
        ],
      ),
    ),
  );
}
