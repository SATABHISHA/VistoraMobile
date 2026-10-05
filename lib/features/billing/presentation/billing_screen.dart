import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/features/billing/data/billing_repository.dart';
import 'package:vistora_mobile/features/billing/domain/billing_models.dart';
import 'package:vistora_mobile/features/platform_admin/data/platform_repository.dart';
import 'package:vistora_mobile/features/platform_admin/domain/platform_models.dart';
import 'package:vistora_mobile/features/tax_invoices/data/tax_invoice_repository.dart';
import 'package:vistora_mobile/features/tax_invoices/presentation/tax_invoice_view.dart';

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);
final _platformRepositoryProvider = Provider<PlatformRepository>(
  (ref) => PlatformRepository(ref.watch(apiClientProvider)),
);

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _date = DateFormat('dd MMM yyyy');

class TenantBillingScreen extends ConsumerStatefulWidget {
  const TenantBillingScreen({super.key});

  @override
  ConsumerState<TenantBillingScreen> createState() =>
      _TenantBillingScreenState();
}

class _TenantBillingScreenState extends ConsumerState<TenantBillingScreen>
    with WidgetsBindingObserver {
  late Future<BillingPage> _future;
  int? _busyId;
  bool _paymentReturnPending = false;

  BillingRepository get repository => ref.read(billingRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = repository.tenantBills();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_paymentReturnPending ||
        !mounted) {
      return;
    }
    _paymentReturnPending = false;
    context.go(
      '/tax-invoices?refresh=${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = repository.tenantBills());
    await _future;
  }

  Future<void> _pay(PlatformBill bill) async {
    if (_busyId != null) return;
    setState(() => _busyId = bill.id);
    try {
      final result = await repository.startPayment(bill.id);
      final uri = Uri.tryParse(result.checkout.checkoutUrl);
      _paymentReturnPending = true;
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _paymentReturnPending = false;
        throw Exception('Secure payment checkout could not be opened.');
      }
      if (mounted) {
        _toast(
          'Secure checkout opened. Return here and refresh after payment.',
        );
      }
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _invoice(PlatformBill bill) async {
    if (bill.taxInvoiceId == null) return;
    try {
      final detail = await TaxInvoiceRepository(
        ref.read(apiClientProvider),
      ).show(bill.taxInvoiceId!);
      if (mounted) await showTaxInvoicePreview(context, detail);
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    }
  }

  Future<void> _billDocument(PlatformBill bill, {bool download = false}) async {
    try {
      final document = await repository.billDocument(bill.id);
      if (download) {
        await Printing.sharePdf(
          bytes: document.pdfBytes,
          filename: document.filename,
        );
      } else {
        await Printing.layoutPdf(onLayout: (_) async => document.pdfBytes);
      }
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error
            ? const Color(0xFF7B263B)
            : VistoraColors.surfaceRaised,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billing & invoices'),
          Text(
            'Outstanding company bills',
            style: TextStyle(fontSize: 12, color: VistoraColors.muted),
          ),
        ],
      ),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<BillingPage>(
        future: _future,
        builder: (context, snapshot) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            _BillingHero(
              overdue:
                  snapshot.data?.items.where((bill) => bill.overdue).length ??
                  0,
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _LoadingCard()
            else if (snapshot.hasError)
              _UnavailableCard(error: snapshot.error)
            else if (snapshot.data?.items.isEmpty ?? true)
              const _EmptyCard(
                title: 'No outstanding bills',
                message: 'Paid invoices will remain available in Tax Invoices.',
              )
            else
              ...snapshot.data!.items.map(
                (bill) => _BillCard(
                  bill: bill,
                  busy: _busyId == bill.id,
                  onPay: () => _pay(bill),
                  onInvoice: () => _invoice(bill),
                  onBillDocument: () => _billDocument(bill),
                  onDownloadBill: () => _billDocument(bill, download: true),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class PlatformBillsScreen extends ConsumerStatefulWidget {
  const PlatformBillsScreen({super.key});

  @override
  ConsumerState<PlatformBillsScreen> createState() =>
      _PlatformBillsScreenState();
}

class _PlatformBillsScreenState extends ConsumerState<PlatformBillsScreen> {
  late Future<BillingPage> _future;
  bool _busy = false;

  BillingRepository get bills => ref.read(billingRepositoryProvider);
  PlatformRepository get platform => ref.read(_platformRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = bills.superadminBills();
  }

  Future<void> _refresh() async {
    setState(() => _future = bills.superadminBills());
    await _future;
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        platform.tenants(perPage: 100),
        platform.billingSettings(),
      ]);
      final tenants = results[0] as PlatformPage<PlatformTenant>;
      final settings = results[1] as PlatformBillingSettings;
      if (!mounted) return;
      if (tenants.items.isEmpty) {
        _toast('Create a company before generating a bill.', error: true);
        return;
      }
      final draft = await showModalBottomSheet<PlatformBillDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: VistoraColors.background,
        builder: (_) => _BillEditorSheet(
          tenants: tenants.items,
          settings: settings,
          repository: bills,
        ),
      );
      if (draft == null) return;
      final result = await bills.createBill(draft);
      await _refresh();
      if (mounted) {
        _toast(
          result.emailSent
              ? 'Bill generated and emailed with PDF receipt.'
              : result.emailMessage ??
                    'Bill generated. The tenant can now see its due date.',
        );
      }
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPaid(PlatformBill bill) async {
    var mode = 'bank_transfer';
    final reference = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Mark ${bill.billNo} as paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Payment mode'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('Bank transfer'),
                  ),
                  DropdownMenuItem(value: 'neft', child: Text('NEFT')),
                  DropdownMenuItem(value: 'rtgs', child: Text('RTGS')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setDialog(() => mode = value ?? mode),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Mark paid'),
            ),
          ],
        ),
      ),
    );
    final refText = reference.text.trim();
    reference.dispose();
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await bills.markPaid(
        bill.id,
        mode: mode,
        reference: refText.isEmpty ? null : refText,
      );
      await _refresh();
      if (mounted) _toast('Bill marked paid and tax invoice generated.');
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailBill(PlatformBill bill) async {
    try {
      final page = await platform.tenants(perPage: 100);
      final matches = page.items
          .where((item) => item.corpId == bill.corpId)
          .toList();
      final tenant = matches.isEmpty ? null : matches.first;
      if (tenant == null)
        throw Exception('Tenant recipients could not be loaded.');
      final recipients = await bills.billRecipients(tenant.id);
      final selected = <String>{};
      final custom = TextEditingController();
      final chosen = await showDialog<List<String>>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: Text('Send ${bill.billNo}'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 430),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recipients.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No registered Admin/HR email found.'),
                      ),
                    for (final recipient in recipients)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(recipient.email),
                        title: Text(recipient.name),
                        subtitle: Text(
                          '${recipient.roleType} - ${recipient.email}',
                        ),
                        onChanged: (value) => setDialog(() {
                          if (value == true) {
                            selected.add(recipient.email);
                          } else {
                            selected.remove(recipient.email);
                          }
                        }),
                      ),
                    TextField(
                      controller: custom,
                      decoration: const InputDecoration(
                        labelText: 'Custom email(s)',
                        hintText: 'Separate multiple addresses with commas',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final extra = custom.text
                      .split(RegExp(r'[,;\s]+'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty);
                  Navigator.pop(dialog, {...selected, ...extra}.toList());
                },
                child: const Text('Send PDF'),
              ),
            ],
          ),
        ),
      );
      custom.dispose();
      if (chosen == null || chosen.isEmpty) return;
      final result = await bills.emailBill(bill.id, recipients: chosen);
      if (mounted)
        _toast(
          result.message ??
              (result.sent
                  ? 'Bill email sent.'
                  : 'Bill email could not be sent.'),
          error: !result.sent,
        );
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    }
  }

  Future<void> _gateway() async {
    try {
      final config = await bills.gatewaySettings();
      if (mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: VistoraColors.background,
          builder: (_) =>
              _GatewayEditorSheet(initial: config, repository: bills),
        );
      }
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    }
  }

  Future<void> _billDocument(PlatformBill bill, {bool download = false}) async {
    try {
      final document = await bills.billDocument(bill.id, superadmin: true);
      if (download) {
        await Printing.sharePdf(
          bytes: document.pdfBytes,
          filename: document.filename,
        );
      } else {
        await Printing.layoutPdf(onLayout: (_) async => document.pdfBytes);
      }
    } catch (error) {
      if (mounted) _toast(error.toString(), error: true);
    }
  }

  void _toast(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: error
              ? const Color(0xFF7B263B)
              : VistoraColors.surfaceRaised,
          content: Text(text),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client bills'),
          Text(
            'Due dates, online payment and invoices',
            style: TextStyle(fontSize: 12, color: VistoraColors.muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Payment gateway',
          onPressed: _gateway,
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<BillingPage>(
        future: _future,
        builder: (context, snapshot) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            _BillingHero(
              overdue:
                  snapshot.data?.items.where((bill) => bill.overdue).length ??
                  0,
              superadmin: true,
            ),
            const SizedBox(height: 16),
            _ActionButton(
              label: 'Generate bill invoice',
              icon: Icons.add_card_outlined,
              onPressed: _busy ? null : _create,
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const _LoadingCard()
            else if (snapshot.hasError)
              _UnavailableCard(error: snapshot.error)
            else if (snapshot.data?.items.isEmpty ?? true)
              const _EmptyCard(
                title: 'No bills generated',
                message:
                    'Generate a bill to notify a tenant about payment due.',
              )
            else
              ...snapshot.data!.items.map(
                (bill) => _BillCard(
                  bill: bill,
                  superadmin: true,
                  busy: _busy,
                  onMarkPaid: bill.status == 'due'
                      ? () => _markPaid(bill)
                      : null,
                  onBillDocument: () => _billDocument(bill),
                  onDownloadBill: () => _billDocument(bill, download: true),
                  onEmail: () => _emailBill(bill),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    this.superadmin = false,
    this.busy = false,
    this.onPay,
    this.onMarkPaid,
    this.onInvoice,
    this.onBillDocument,
    this.onDownloadBill,
    this.onEmail,
  });
  final PlatformBill bill;
  final bool superadmin;
  final bool busy;
  final VoidCallback? onPay;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onInvoice;
  final VoidCallback? onBillDocument;
  final VoidCallback? onDownloadBill;
  final VoidCallback? onEmail;

  @override
  Widget build(BuildContext context) {
    final paid = bill.status == 'paid';
    final statusColor = paid
        ? VistoraColors.green
        : bill.overdue
        ? VistoraColors.pink
        : VistoraColors.amber;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${bill.corpId} · ${bill.billNo}',
                        style: const TextStyle(
                          color: VistoraColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: bill.statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'TOTAL',
                    value: _money.format(bill.totalAmount),
                    color: VistoraColors.green,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'DUE DATE',
                    value: bill.dueDate == null
                        ? '—'
                        : _date.format(bill.dueDate!),
                    color: statusColor,
                  ),
                ),
              ],
            ),
            if (bill.gstAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Includes GST ${_money.format(bill.gstAmount)}',
                  style: const TextStyle(
                    color: VistoraColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onBillDocument != null)
                  OutlinedButton.icon(
                    onPressed: onBillDocument,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View bill'),
                  ),
                if (onDownloadBill != null)
                  OutlinedButton.icon(
                    onPressed: onDownloadBill,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download PDF'),
                  ),
                if (superadmin && onEmail != null)
                  OutlinedButton.icon(
                    onPressed: onEmail,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Email'),
                  ),
                if (!superadmin &&
                    bill.status == 'due' &&
                    bill.gateway.payNowAvailable)
                  FilledButton.icon(
                    onPressed: busy ? null : onPay,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: Text(busy ? 'Opening…' : 'Pay now'),
                  ),
                if (superadmin && onMarkPaid != null)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onMarkPaid,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Mark paid'),
                  ),
                if (paid && onInvoice != null)
                  OutlinedButton.icon(
                    onPressed: onInvoice,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Tax invoice'),
                  ),
                if (!superadmin &&
                    bill.status == 'due' &&
                    !bill.gateway.payNowAvailable)
                  const Text(
                    'Online payment is unavailable. Contact Vistora billing.',
                    style: TextStyle(color: VistoraColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillEditorSheet extends StatefulWidget {
  const _BillEditorSheet({
    required this.tenants,
    required this.settings,
    required this.repository,
  });
  final List<PlatformTenant> tenants;
  final PlatformBillingSettings settings;
  final BillingRepository repository;
  @override
  State<_BillEditorSheet> createState() => _BillEditorSheetState();
}

class _BillEditorSheetState extends State<_BillEditorSheet> {
  final amount = TextEditingController();
  final notes = TextEditingController();
  final email = TextEditingController();
  final cgstRate = TextEditingController();
  final sgstRate = TextEditingController();
  final igstRate = TextEditingController();
  final Set<String> selectedRecipients = <String>{};
  List<BillingRecipient> recipients = const [];
  late String corpId;
  var paymentType = 'period';
  var periodType = 'monthly';
  var gstType = 'cgst_sgst';
  var gstEnabled = false;
  var sendEmail = true;
  var issueDate = DateTime.now();
  var dueDate = DateTime.now().add(const Duration(days: 7));
  var busy = false;

  @override
  void initState() {
    super.initState();
    corpId = widget.tenants.first.corpId;
    email.clear();
    gstType = widget.settings.gstMode;
    cgstRate.text = widget.settings.cgstPercent.toString();
    sgstRate.text = widget.settings.sgstPercent.toString();
    igstRate.text = widget.settings.igstPercent.toString();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    try {
      final tenant = widget.tenants.firstWhere((item) => item.corpId == corpId);
      final loaded = await widget.repository.billRecipients(tenant.id);
      if (!mounted) return;
      setState(() {
        recipients = loaded;
        selectedRecipients
          ..clear()
          ..addAll(loaded.map((recipient) => recipient.email));
      });
    } catch (_) {
      if (mounted) setState(() => recipients = const []);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    email.dispose();
    cgstRate.dispose();
    sgstRate.dispose();
    igstRate.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool due) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
      initialDate: due ? dueDate : issueDate,
    );
    if (picked != null)
      setState(() => due ? dueDate = picked : issueDate = picked);
  }

  void _submit() {
    final value = double.tryParse(amount.text.trim());
    final cgst = double.tryParse(cgstRate.text.trim()) ?? 0;
    final sgst = double.tryParse(sgstRate.text.trim()) ?? 0;
    final igst = double.tryParse(igstRate.text.trim()) ?? 0;
    final recipientEmails = _recipientEmails();
    if (value == null ||
        value <= 0 ||
        dueDate.isBefore(issueDate) ||
        (gstEnabled &&
            ((gstType == 'cgst_sgst' && (cgst <= 0 || sgst <= 0)) ||
                (gstType == 'igst' && igst <= 0)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and due date.')),
      );
      return;
    }
    Navigator.pop(
      context,
      PlatformBillDraft(
        corpId: corpId,
        paymentType: paymentType,
        periodType: periodType,
        issueDate: issueDate,
        dueDate: dueDate,
        amount: value,
        gstEnabled: gstEnabled,
        gstType: gstType,
        cgstPercent: cgst,
        sgstPercent: sgst,
        igstPercent: igst,
        clientEmail: recipientEmails.isEmpty ? null : recipientEmails.first,
        recipients: recipientEmails,
        sendEmail: sendEmail,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
    );
  }

  List<String> _recipientEmails() {
    final custom = email.text
        .split(RegExp(r'[,;\s]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    return {...selectedRecipients, ...custom}.toList();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 18,
      right: 18,
      top: 18,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Generate bill invoice',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: corpId,
            decoration: const InputDecoration(labelText: 'Company'),
            items: [
              for (final tenant in widget.tenants)
                DropdownMenuItem(
                  value: tenant.corpId,
                  child: Text(
                    '${tenant.companyName} (${tenant.corpId})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              corpId = value ?? corpId;
              selectedRecipients.clear();
              recipients = const [];
              email.clear();
              setState(() {});
              _loadRecipients();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: paymentType,
            decoration: const InputDecoration(labelText: 'Purpose'),
            items: const [
              DropdownMenuItem(
                value: 'installation',
                child: Text('Installation'),
              ),
              DropdownMenuItem(value: 'initial', child: Text('Initial')),
              DropdownMenuItem(value: 'advance', child: Text('Advance')),
              DropdownMenuItem(value: 'period', child: Text('Period payment')),
            ],
            onChanged: (value) =>
                setState(() => paymentType = value ?? paymentType),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: periodType,
            decoration: const InputDecoration(labelText: 'Period'),
            items: const [
              DropdownMenuItem(value: 'one-time', child: Text('One-time')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
              DropdownMenuItem(
                value: 'half-yearly',
                child: Text('Half-yearly'),
              ),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (value) =>
                setState(() => periodType = value ?? periodType),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (INR)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'Issue date',
                  value: issueDate,
                  onTap: () => _pickDate(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateButton(
                  label: 'Due date',
                  value: dueDate,
                  onTap: () => _pickDate(true),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Apply GST'),
            value: gstEnabled,
            onChanged: (value) => setState(() => gstEnabled = value),
          ),
          if (gstEnabled)
            DropdownButtonFormField<String>(
              value: gstType,
              decoration: const InputDecoration(labelText: 'GST type'),
              items: const [
                DropdownMenuItem(
                  value: 'cgst_sgst',
                  child: Text('CGST + SGST'),
                ),
                DropdownMenuItem(value: 'igst', child: Text('IGST')),
              ],
              onChanged: (value) => setState(() => gstType = value ?? gstType),
            ),
          if (gstEnabled && gstType == 'cgst_sgst')
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cgstRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'CGST %'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: sgstRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'SGST %'),
                  ),
                ),
              ],
            ),
          if (gstEnabled && gstType == 'igst')
            TextField(
              controller: igstRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'IGST %'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Custom recipient email(s)',
              hintText: 'Optional; separate multiple addresses with commas',
            ),
          ),
          if (recipients.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Registered tenant recipients',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final recipient in recipients)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selectedRecipients.contains(recipient.email),
                title: Text(recipient.name),
                subtitle: Text('${recipient.roleType} - ${recipient.email}'),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selectedRecipients.add(recipient.email);
                  } else {
                    selectedRecipients.remove(recipient.email);
                  }
                }),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Send bill invoice by email'),
            subtitle: const Text(
              'Includes a colourful Vistora email and PDF receipt.',
            ),
            value: sendEmail,
            onChanged: (value) => setState(() => sendEmail = value),
          ),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : _submit,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate bill'),
          ),
        ],
      ),
    ),
  );
}

class _GatewayEditorSheet extends StatefulWidget {
  const _GatewayEditorSheet({required this.initial, required this.repository});
  final PaymentGatewayConfig initial;
  final BillingRepository repository;
  @override
  State<_GatewayEditorSheet> createState() => _GatewayEditorSheetState();
}

class _GatewayEditorSheetState extends State<_GatewayEditorSheet> {
  late bool enabled;
  late String provider;
  late String environment;
  final keyId = TextEditingController();
  final keySecret = TextEditingController();
  final webhook = TextEditingController();
  final appId = TextEditingController();
  final secret = TextEditingController();
  final cfWebhook = TextEditingController();
  var busy = false;
  @override
  void initState() {
    super.initState();
    enabled = widget.initial.enabled;
    provider = widget.initial.provider ?? 'razorpay';
    environment = widget.initial.cashfreeEnvironment;
    keyId.text = widget.initial.razorpayKeyId ?? '';
    appId.text = widget.initial.cashfreeAppId ?? '';
  }

  @override
  void dispose() {
    for (final c in [keyId, keySecret, webhook, appId, secret, cfWebhook]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await widget.repository.saveGatewaySettings(
        PaymentGatewayDraft(
          enabled: enabled,
          provider: provider,
          cashfreeEnvironment: environment,
          razorpayKeyId: keyId.text,
          razorpayKeySecret: keySecret.text,
          razorpayWebhookSecret: webhook.text,
          cashfreeAppId: appId.text,
          cashfreeSecretKey: secret.text,
          cashfreeWebhookSecret: cfWebhook.text,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment gateway settings saved.')),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 18,
      right: 18,
      top: 18,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Payment gateway settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Secrets are encrypted by the server and are never returned to the app.',
            style: TextStyle(color: VistoraColors.muted),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable online payments'),
            value: enabled,
            onChanged: (value) => setState(() => enabled = value),
          ),
          DropdownButtonFormField<String>(
            value: provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(value: 'razorpay', child: Text('Razorpay')),
              DropdownMenuItem(value: 'cashfree', child: Text('Cashfree')),
            ],
            onChanged: (value) => setState(() => provider = value ?? provider),
          ),
          const SizedBox(height: 12),
          if (provider == 'razorpay') ...[
            TextField(
              controller: keyId,
              decoration: const InputDecoration(labelText: 'Razorpay key ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keySecret,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Razorpay secret'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: webhook,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Webhook secret (optional)',
              ),
            ),
          ] else ...[
            TextField(
              controller: appId,
              decoration: const InputDecoration(labelText: 'Cashfree app ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: secret,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Cashfree secret'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cfWebhook,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Webhook secret (optional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: environment,
              decoration: const InputDecoration(labelText: 'Environment'),
              items: const [
                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')),
                DropdownMenuItem(
                  value: 'production',
                  child: Text('Production'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => environment = value ?? environment),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(busy ? 'Saving…' : 'Save gateway settings'),
          ),
        ],
      ),
    ),
  );
}

class _BillingHero extends StatelessWidget {
  const _BillingHero({required this.overdue, this.superadmin = false});
  final int overdue;
  final bool superadmin;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF291B45), Color(0xFF102A42)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: VistoraColors.cyan.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: VistoraColors.orange.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: VistoraColors.orange,
            size: 29,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                superadmin ? 'Client billing centre' : 'Your Vistora billing',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                superadmin
                    ? 'Generate, track and settle tenant invoices.'
                    : overdue == 0
                    ? 'Securely view your outstanding invoices.'
                    : '$overdue invoice${overdue == 1 ? '' : 's'} overdue. Please arrange payment.',
                style: const TextStyle(color: VistoraColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: VistoraColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(_date.format(value)),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: VistoraColors.muted,
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VistoraColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({this.error});
  final Object? error;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: VistoraColors.amber,
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'Billing is not available on this server version yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your existing Vistora features continue to work. Please update the Laravel deployment to enable this feature.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VistoraColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
