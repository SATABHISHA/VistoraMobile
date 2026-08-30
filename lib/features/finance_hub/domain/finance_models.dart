import 'package:vistora_mobile/core/api/api_parsing.dart';

class FinanceComponent {
  const FinanceComponent({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.hsnSac,
    this.amount = 0,
  });
  final String description;
  final String? hsnSac;
  final double quantity;
  final double unitPrice;
  final double amount;
  factory FinanceComponent.fromJson(Map<String, dynamic> j) => FinanceComponent(
    description: j['description']?.toString() ?? '',
    hsnSac: asNullableString(j['hsn_sac']),
    quantity: asDouble(j['quantity']),
    unitPrice: asDouble(j['unit_price']),
    amount: asDouble(j['amount']),
  );
  Map<String, dynamic> toJson() => {
    'description': description,
    'hsn_sac': hsnSac,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.category,
    required this.paymentMode,
    required this.subtotal,
    required this.total,
    required this.components,
    this.partyName,
    this.partyEmail,
    this.partyGstin,
    this.partyAddress,
    this.referenceNo,
    this.chequeNo,
    this.bankName,
    this.cardIssuer,
    this.cardHolderName,
    this.cardLastFour,
    this.description,
    this.gstType = 'none',
    this.cgstPercent = 0,
    this.sgstPercent = 0,
    this.igstPercent = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.invoice,
  });
  final int id;
  final String type;
  final DateTime date;
  final String category;
  final String paymentMode;
  final double subtotal;
  final double total;
  final List<FinanceComponent> components;
  final String? partyName,
      partyEmail,
      partyGstin,
      partyAddress,
      referenceNo,
      chequeNo,
      bankName,
      cardIssuer,
      cardHolderName,
      cardLastFour,
      description;
  final String gstType;
  final double cgstPercent,
      sgstPercent,
      igstPercent,
      cgstAmount,
      sgstAmount,
      igstAmount;
  final Map<String, dynamic>? invoice;
  factory FinanceEntry.fromJson(Map<String, dynamic> j) => FinanceEntry(
    id: asInt(j['id']),
    type: j['entry_type']?.toString() ?? 'expense',
    date: DateTime.parse(j['entry_date'].toString()),
    category: j['category']?.toString() ?? '',
    paymentMode: j['payment_mode']?.toString() ?? '',
    subtotal: asDouble(j['subtotal']),
    total: asDouble(j['total_amount']),
    components: asList(
      j['components'],
    ).map((x) => FinanceComponent.fromJson(asMap(x))).toList(),
    partyName: asNullableString(j['party_name']),
    partyEmail: asNullableString(j['party_email']),
    partyGstin: asNullableString(j['party_gstin']),
    partyAddress: asNullableString(j['party_address']),
    referenceNo: asNullableString(j['reference_no']),
    chequeNo: asNullableString(j['cheque_no']),
    bankName: asNullableString(j['bank_name']),
    cardIssuer: asNullableString(j['card_issuer']),
    cardHolderName: asNullableString(j['card_holder_name']),
    cardLastFour: asNullableString(j['card_last_four']),
    description: asNullableString(j['description']),
    gstType: j['gst_type']?.toString() ?? 'none',
    cgstPercent: asDouble(j['cgst_percent']),
    sgstPercent: asDouble(j['sgst_percent']),
    igstPercent: asDouble(j['igst_percent']),
    cgstAmount: asDouble(j['cgst_amount']),
    sgstAmount: asDouble(j['sgst_amount']),
    igstAmount: asDouble(j['igst_amount']),
    invoice: j['invoice'] is Map ? asMap(j['invoice']) : null,
  );
}

class FinancePage {
  const FinancePage(
    this.items,
    this.page,
    this.lastPage,
    this.total, {
    this.filteredTotalAmount = 0,
  });
  final List<FinanceEntry> items;
  final int page, lastPage, total;
  final double filteredTotalAmount;
}

class FinanceSettings {
  const FinanceSettings({
    this.email,
    this.website,
    this.address,
    this.prefix = 'FH',
    this.gstEnabled = false,
    this.cgst = 9,
    this.sgst = 9,
    this.igst = 18,
  });
  final String? email, website, address;
  final String prefix;
  final bool gstEnabled;
  final double cgst, sgst, igst;
  factory FinanceSettings.fromJson(Map<String, dynamic> j) => FinanceSettings(
    email: asNullableString(j['contact_email']),
    website: asNullableString(j['website']),
    address: asNullableString(j['billing_address']),
    prefix: j['invoice_prefix']?.toString() ?? 'FH',
    gstEnabled: j['gst_enabled'] == true || asInt(j['gst_enabled']) == 1,
    cgst: asDouble(j['cgst_percent'], 9),
    sgst: asDouble(j['sgst_percent'], 9),
    igst: asDouble(j['igst_percent'], 18),
  );
  Map<String, dynamic> toJson() => {
    'contact_email': email,
    'website': website,
    'billing_address': address,
    'invoice_prefix': prefix,
    'gst_enabled': gstEnabled,
    'cgst_percent': cgst,
    'sgst_percent': sgst,
    'igst_percent': igst,
  };
}
