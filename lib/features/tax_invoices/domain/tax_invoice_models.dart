import 'package:vistora_mobile/core/api/api_parsing.dart';

class TaxInvoicePage {
  const TaxInvoicePage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<TaxInvoiceSummary> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class TaxInvoiceSummary {
  const TaxInvoiceSummary({
    required this.id,
    required this.paymentId,
    required this.corpId,
    required this.invoiceNo,
    required this.clientName,
    required this.paymentType,
    required this.periodType,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentMode,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    this.invoiceDate,
    this.periodStart,
    this.periodEnd,
    this.paymentReference,
    this.notes,
  });

  final int id;
  final int paymentId;
  final String corpId;
  final String invoiceNo;
  final String clientName;
  final String paymentType;
  final String periodType;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String paymentMode;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final DateTime? invoiceDate;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? paymentReference;
  final String? notes;

  factory TaxInvoiceSummary.fromJson(Map<String, dynamic> json) {
    final payment = asMap(json['payment']);
    Object? pick(String key) => json[key] ?? payment[key];

    return TaxInvoiceSummary(
      id: asInt(json['id']),
      paymentId: asInt(json['payment_id'] ?? payment['id']),
      corpId: pick('corp_id')?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? 'Invoice',
      clientName:
          json['client_name']?.toString() ??
          payment['company_name']?.toString() ??
          pick('corp_id')?.toString() ??
          'Company',
      paymentType: pick('payment_type')?.toString() ?? 'period',
      periodType: pick('period_type')?.toString() ?? 'monthly',
      subtotal: asDouble(json['subtotal'] ?? payment['package_amount']),
      gstAmount: asDouble(pick('gst_amount')),
      totalAmount: asDouble(pick('total_amount')),
      paymentMode: pick('payment_mode')?.toString() ?? 'online',
      cgstPercent: asDouble(pick('cgst_percent')),
      sgstPercent: asDouble(pick('sgst_percent')),
      igstPercent: asDouble(pick('igst_percent')),
      cgstAmount: asDouble(pick('cgst_amount')),
      sgstAmount: asDouble(pick('sgst_amount')),
      igstAmount: asDouble(pick('igst_amount')),
      invoiceDate: asDateTime(json['invoice_date'] ?? payment['payment_date']),
      periodStart: asDateTime(pick('period_start')),
      periodEnd: asDateTime(pick('period_end')),
      paymentReference: asNullableString(
        json['payment_reference'] ??
            payment['cheque_no'] ??
            payment['transaction_reference'],
      ),
      notes: asNullableString(payment['notes']),
    );
  }
}

class InvoiceParty {
  const InvoiceParty({
    required this.companyName,
    this.productName,
    this.corpId,
    this.gstin,
    this.address,
    this.website,
    this.email,
    this.phone,
    this.sealUrl,
  });

  final String companyName;
  final String? productName;
  final String? corpId;
  final String? gstin;
  final String? address;
  final String? website;
  final String? email;
  final String? phone;
  final String? sealUrl;

  factory InvoiceParty.fromJson(Map<String, dynamic> json) => InvoiceParty(
    companyName: json['company_name']?.toString() ?? 'Company',
    productName: asNullableString(json['product_name']),
    corpId: asNullableString(json['corp_id']),
    gstin: asNullableString(json['gstin']),
    address: asNullableString(json['address']),
    website: asNullableString(json['website']),
    email: asNullableString(json['email']),
    phone: asNullableString(json['phone']),
    sealUrl: asNullableString(json['seal_url']),
  );
}

class TaxInvoiceDetail {
  const TaxInvoiceDetail({
    required this.invoice,
    required this.provider,
    required this.client,
  });

  final TaxInvoiceSummary invoice;
  final InvoiceParty provider;
  final InvoiceParty client;

  factory TaxInvoiceDetail.fromJson(Map<String, dynamic> json) {
    final invoice = asMap(json['invoice']);
    final payment = asMap(json['payment']);
    return TaxInvoiceDetail(
      invoice: TaxInvoiceSummary.fromJson({
        ...payment,
        ...invoice,
        'payment': payment,
      }),
      provider: InvoiceParty.fromJson(asMap(json['provider'])),
      client: InvoiceParty.fromJson(asMap(json['client'])),
    );
  }
}
