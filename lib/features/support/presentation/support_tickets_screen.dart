import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';
import 'package:vistora_mobile/features/support/data/support_ticket_repository.dart';
import 'package:vistora_mobile/features/support/domain/support_ticket_models.dart';

final supportTicketRepositoryProvider = Provider<SupportTicketRepository>(
  (ref) => SupportTicketRepository(ref.watch(apiClientProvider)),
);

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  late Future<SupportTicketPage> _future;
  final _search = TextEditingController();
  final _corpController = TextEditingController();
  Timer? _searchTimer;
  int _page = 1;
  int _perPage = 10;
  String _status = '';
  String _priority = '';
  String _corpId = '';

  bool get _isSuperadmin =>
      ref.read(authControllerProvider).session?.user.normalizedRole ==
      'superadmin';

  SupportTicketRepository get repository =>
      ref.read(supportTicketRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    _corpController.dispose();
    super.dispose();
  }

  Future<SupportTicketPage> _load() => repository.page(
    superadmin: _isSuperadmin,
    page: _page,
    perPage: _perPage,
    query: _search.text.trim().isEmpty ? null : _search.text.trim(),
    status: _status.isEmpty ? null : _status,
    priority: _priority.isEmpty ? null : _priority,
    corpId: _isSuperadmin && _corpId.trim().isNotEmpty ? _corpId.trim() : null,
  );

  Future<void> _refresh({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    try {
      final detail = await repository.show(
        ticket.id,
        superadmin: _isSuperadmin,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: VistoraColors.background,
        builder: (_) => _TicketDetailSheet(
          ticket: detail,
          superadmin: _isSuperadmin,
          repository: repository,
          currentUserId: sessionUserId,
          onChanged: () => _refresh(),
        ),
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    }
  }

  int get sessionUserId =>
      ref.read(authControllerProvider).session?.user.id ?? 0;

  Future<void> _createTicket() async {
    final ticket = await showModalBottomSheet<SupportTicket>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VistoraColors.background,
      builder: (_) => _CreateTicketSheet(repository: repository),
    );
    if (!mounted || ticket == null) return;
    _toast('${ticket.ticketNo} raised successfully.');
    await _refresh(resetPage: true);
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error
            ? const Color(0xFF7B263B)
            : VistoraColors.surfaceRaised,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support centre'),
            Text(
              'Private ticket conversations',
              style: TextStyle(fontSize: 12, color: VistoraColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh tickets',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _isSuperadmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _createTicket,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Raise ticket'),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<SupportTicketPage>(
          future: _future,
          builder: (context, snapshot) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              _SupportHero(
                superadmin: _isSuperadmin,
                sessionName: session?.companyName,
              ),
              const SizedBox(height: 14),
              _SupportFilters(
                superadmin: _isSuperadmin,
                search: _search,
                status: _status,
                priority: _priority,
                corpId: _corpId,
                corpController: _corpController,
                perPage: _perPage,
                onSearchChanged: (_) {
                  _searchTimer?.cancel();
                  _searchTimer = Timer(
                    const Duration(milliseconds: 300),
                    () => _refresh(resetPage: true),
                  );
                },
                onCorpChanged: (value) {
                  _corpId = value;
                  _refresh(resetPage: true);
                },
                onStatusChanged: (value) {
                  _status = value ?? '';
                  _refresh(resetPage: true);
                },
                onPriorityChanged: (value) {
                  _priority = value ?? '';
                  _refresh(resetPage: true);
                },
                onPerPageChanged: (value) {
                  if (value == null) return;
                  _perPage = value;
                  _refresh(resetPage: true);
                },
                onReset: () {
                  _search.clear();
                  _corpId = '';
                  _status = '';
                  _priority = '';
                  _refresh(resetPage: true);
                },
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const _SupportLoading()
              else if (snapshot.hasError)
                _SupportEmpty(message: snapshot.error.toString())
              else if (snapshot.data?.items.isEmpty ?? true)
                const _SupportEmpty(
                  message: 'No tickets match these filters yet.',
                )
              else ...[
                ...snapshot.data!.items.map(
                  (ticket) => _TicketCard(
                    ticket: ticket,
                    superadmin: _isSuperadmin,
                    onTap: () => _openTicket(ticket),
                  ),
                ),
                const SizedBox(height: 10),
                _SupportPager(
                  page: snapshot.data!.page,
                  lastPage: snapshot.data!.lastPage,
                  total: snapshot.data!.total,
                  onPrevious: snapshot.data!.page > 1
                      ? () => _goToPage(snapshot.data!.page - 1)
                      : null,
                  onNext: snapshot.data!.page < snapshot.data!.lastPage
                      ? () => _goToPage(snapshot.data!.page + 1)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToPage(int page) async {
    _page = page;
    await _refresh();
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero({required this.superadmin, this.sessionName});
  final bool superadmin;
  final String? sessionName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3A194F), Color(0xFF102F45)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .28)),
      boxShadow: const [BoxShadow(color: Color(0x331A9DCC), blurRadius: 24)],
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: VistoraColors.orange.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Icon(
            Icons.support_agent_outlined,
            color: VistoraColors.orange,
            size: 32,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                superadmin ? 'Support command centre' : 'Your support lounge',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                superadmin
                    ? 'Search every tenant conversation and help close issues beautifully.'
                    : 'Raise an issue and follow every reply in one private place.',
                style: const TextStyle(
                  color: VistoraColors.muted,
                  height: 1.35,
                ),
              ),
              if (sessionName != null) ...[
                const SizedBox(height: 5),
                Text(
                  sessionName!,
                  style: const TextStyle(color: VistoraColors.cyan),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SupportFilters extends StatelessWidget {
  const _SupportFilters({
    required this.superadmin,
    required this.search,
    required this.status,
    required this.priority,
    required this.corpId,
    required this.corpController,
    required this.perPage,
    required this.onSearchChanged,
    required this.onCorpChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onPerPageChanged,
    required this.onReset,
  });

  final bool superadmin;
  final TextEditingController search;
  final String status, priority, corpId;
  final TextEditingController corpController;
  final int perPage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCorpChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<int?> onPerPageChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: search,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search ticket ID, subject or issue',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (superadmin) ...[
            const SizedBox(height: 10),
            TextField(
              onChanged: onCorpChanged,
              controller: corpController,
              decoration: const InputDecoration(
                labelText: 'Tenant corporate ID',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: status.isEmpty ? null : status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All statuses')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In progress'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: priority.isEmpty ? null : priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All priorities'),
                    ),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: onPriorityChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: perPage,
                  decoration: const InputDecoration(labelText: 'Rows per page'),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 rows')),
                    DropdownMenuItem(value: 10, child: Text('10 rows')),
                    DropdownMenuItem(value: 20, child: Text('20 rows')),
                    DropdownMenuItem(value: 50, child: Text('50 rows')),
                  ],
                  onChanged: onPerPageChanged,
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.superadmin,
    required this.onTap,
  });
  final SupportTicket ticket;
  final bool superadmin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.ticketNo,
                    style: const TextStyle(
                      color: VistoraColors.cyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(ticket.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.subject,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VistoraColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                Chip(label: Text('${ticket.priority} priority')),
                Chip(label: Text('${ticket.messagesCount} replies')),
                if (superadmin) ...[
                  Chip(label: Text(ticket.corpId)),
                  if ((ticket.raisedByName ?? ticket.raisedByEmail ?? '')
                      .isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(ticket.raisedByName ?? ticket.raisedByEmail!),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(ticket.updatedAt),
                    style: const TextStyle(
                      color: VistoraColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: VistoraColors.cyan,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => VistoraColors.green,
      'closed' => VistoraColors.muted,
      'in_progress' => VistoraColors.amber,
      _ => VistoraColors.cyan,
    };
    return Chip(
      label: Text(status.replaceAll('_', ' ')),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      side: BorderSide(color: color.withValues(alpha: .4)),
      backgroundColor: color.withValues(alpha: .1),
    );
  }
}

class _SupportPager extends StatelessWidget {
  const _SupportPager({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });
  final int page, lastPage, total;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Page $page of $lastPage - $total tickets',
            style: const TextStyle(
              color: VistoraColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

class _SupportLoading extends StatelessWidget {
  const _SupportLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(35),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _SupportEmpty extends StatelessWidget {
  const _SupportEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VistoraColors.muted),
          ),
        ),
      ),
    );
  }
}

class _CreateTicketSheet extends StatefulWidget {
  const _CreateTicketSheet({required this.repository});
  final SupportTicketRepository repository;
  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'general';
  String _priority = 'medium';
  bool _busy = false;
  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_subject.text.trim().length < 3 ||
        _description.text.trim().length < 5) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ticket = await widget.repository.create(
        subject: _subject.text.trim(),
        description: _description.text.trim(),
        category: _category,
        priority: _priority,
      );
      if (mounted) Navigator.of(context).pop(ticket);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
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
          const Text(
            'Raise a support ticket',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: VistoraColors.orange,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Describe the issue'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(
                      value: 'technical',
                      child: Text('Technical'),
                    ),
                    DropdownMenuItem(value: 'billing', child: Text('Billing')),
                    DropdownMenuItem(value: 'account', child: Text('Account')),
                    DropdownMenuItem(
                      value: 'feature',
                      child: Text('Feature request'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'general'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: Text(_busy ? 'Sending...' : 'Submit ticket'),
          ),
        ],
      ),
    ),
  );
}

class _TicketDetailSheet extends StatefulWidget {
  const _TicketDetailSheet({
    required this.ticket,
    required this.superadmin,
    required this.repository,
    required this.currentUserId,
    required this.onChanged,
  });
  final SupportTicket ticket;
  final bool superadmin;
  final SupportTicketRepository repository;
  final int currentUserId;
  final Future<void> Function() onChanged;
  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  late SupportTicket _ticket = widget.ticket;
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _ticket = await widget.repository.show(
      _ticket.id,
      superadmin: widget.superadmin,
    );
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.reply(
        _ticket.id,
        superadmin: widget.superadmin,
        body: _reply.text.trim(),
      );
      _reply.clear();
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    setState(() => _busy = true);
    try {
      await widget.repository.resolve(_ticket.id);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await widget.repository.close(_ticket.id);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .86,
        minChildSize: .55,
        maxChildSize: .96,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ticket.ticketNo,
                          style: const TextStyle(
                            color: VistoraColors.cyan,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _ticket.subject,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.superadmin) ...[
                          const SizedBox(height: 5),
                          Text(
                            '${_ticket.corpId} · Raised by ${_ticket.raisedByName ?? _ticket.raisedByEmail ?? 'Tenant user'}',
                            style: const TextStyle(
                              color: VistoraColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusChip(_ticket.status),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _ticket.description,
                          style: const TextStyle(
                            color: VistoraColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._ticket.messages.map((message) {
                      final mine = message.userId == widget.currentUserId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 340),
                          decoration: BoxDecoration(
                            color: mine
                                ? VistoraColors.orange.withValues(alpha: .18)
                                : VistoraColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(message.body),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(message.createdAt),
                                style: const TextStyle(
                                  color: VistoraColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              if (_ticket.status != 'closed') ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reply to conversation',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _busy ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
              if (widget.superadmin) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_ticket.status != 'resolved' &&
                        _ticket.status != 'closed')
                      FilledButton.icon(
                        onPressed: _busy ? null : _resolve,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Resolve'),
                      ),
                    if (_ticket.status == 'resolved')
                      FilledButton.icon(
                        onPressed: _busy ? null : _close,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Close'),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime? value) => value == null
    ? 'Date unavailable'
    : DateFormat.yMMMd().add_jm().format(value);
