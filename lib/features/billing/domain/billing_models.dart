import 'dart:convert';
import 'dart:typed_data';

import 'package:vistora_mobile/core/api/api_parsing.dart';

class BillingPage {
  const BillingPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<PlatformBill> items;
  final int page;
  final int lastPage;
  final int total;
  bool get hasMore => page < lastPage;
}

class BillCreationResult {
  const BillCreationResult({
    required this.bill,
    required this.emailSent,
    this.emailMessage,
  });

  final PlatformBill bill;
  final bool emailSent;
  final String? emailMessage;
}

class BillEmailResult {
  const BillEmailResult({required this.sent, this.message});

  final bool sent;
  final String? message;
}

class BillingRecipient {
  const BillingRecipient({
    required this.id,
    required this.name,
    required this.email,
    required this.roleType,
  });

  final int id;
  final String name;
  final String email;
  final String roleType;

  factory BillingRecipient.fromJson(
    Map<String, dynamic> json,
  ) => BillingRecipient(
    id: asInt(json['id']),
    name: json['name']?.toString() ?? json['email']?.toString() ?? 'Recipient',
    email: json['email']?.toString() ?? '',
    roleType: json['role_type']?.toString() ?? 'Admin',
  );
}

class BillDocument {
  const BillDocument({
    required this.html,
    required this.pdfBytes,
    required this.filename,
  });

  final String html;
  final Uint8List pdfBytes;
  final String filename;

  factory BillDocument.fromJson(Map<String, dynamic> json) => BillDocument(
    html: json['html']?.toString() ?? '',
    pdfBytes: base64Decode(json['pdf_base64']?.toString() ?? ''),
    filename: json['filename']?.toString() ?? 'Vistora-bill.pdf',
  );
}

class PlatformBill {
  const PlatformBill({
    required this.id,
    required this.billNo,
    required this.corpId,
    required this.companyName,
    required this.periodType,
    required this.issueDate,
    required this.dueDate,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.status,
    required this.statusLabel,
    required this.overdue,
    required this.gateway,
    this.paymentType = 'period',
    this.invoiceNo,
    this.taxInvoiceId,
    this.paidAt,
  });

  final int id;
  final String billNo;
  final String corpId;
  final String companyName;
  final String periodType;
  final String paymentType;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String status;
  final String statusLabel;
  final bool overdue;
  final BillGateway gateway;
  final String? invoiceNo;
  final int? taxInvoiceId;
  final DateTime? paidAt;

  factory PlatformBill.fromJson(Map<String, dynamic> raw) {
    final nested = asMap(raw['bill']);
    final json = nested.isNotEmpty ? nested : raw;
    final gatewayJson = asMap(raw['gateway']).isNotEmpty
        ? asMap(raw['gateway'])
        : asMap(json['gateway']);
    final tenant = asMap(json['tenant']);
    return PlatformBill(
      id: asInt(json['id']),
      billNo: json['bill_no']?.toString() ?? 'Bill',
      corpId: json['corp_id']?.toString() ?? '',
      companyName:
          tenant['company_name']?.toString() ??
          json['company_name']?.toString() ??
          json['corp_id']?.toString() ??
          'Company',
      periodType: json['period_type']?.toString() ?? 'one-time',
      paymentType: json['payment_type']?.toString() ?? 'period',
      issueDate: asDateTime(json['issue_date']),
      dueDate: asDateTime(json['due_date']),
      subtotal: asDouble(json['subtotal']),
      gstAmount: asDouble(json['gst_amount']),
      totalAmount: asDouble(json['total_amount']),
      status: json['status']?.toString() ?? 'due',
      statusLabel:
          raw['status_label']?.toString() ??
          json['status']?.toString() ??
          'due',
      overdue: raw['is_overdue'] == true || json['is_overdue'] == true,
      gateway: BillGateway.fromJson(gatewayJson),
      invoiceNo: asNullableString(
        asMap(json['tax_invoice'])['invoice_no'] ?? json['invoice_no'],
      ),
      taxInvoiceId:
          asInt(json['tax_invoice_id'] ?? asMap(json['tax_invoice'])['id']) == 0
          ? null
          : asInt(json['tax_invoice_id'] ?? asMap(json['tax_invoice'])['id']),
      paidAt: asDateTime(json['paid_at']),
    );
  }
}

class BillGateway {
  const BillGateway({
    this.enabled = false,
    this.provider,
    this.payNowAvailable = false,
  });

  final bool enabled;
  final String? provider;
  final bool payNowAvailable;

  factory BillGateway.fromJson(Map<String, dynamic> json) => BillGateway(
    enabled: json['enabled'] == true || asInt(json['enabled']) == 1,
    provider: asNullableString(json['provider']),
    payNowAvailable:
        json['pay_now_available'] == true ||
        asInt(json['pay_now_available']) == 1,
  );
}

class BillCheckout {
  const BillCheckout({
    required this.provider,
    required this.checkoutUrl,
    this.orderId,
    this.paymentSessionId,
  });

  final String provider;
  final String checkoutUrl;
  final String? orderId;
  final String? paymentSessionId;

  factory BillCheckout.fromJson(Map<String, dynamic> json) => BillCheckout(
    provider: json['provider']?.toString() ?? '',
    checkoutUrl: json['checkout_url']?.toString() ?? '',
    orderId: asNullableString(json['order_id']),
    paymentSessionId: asNullableString(json['payment_session_id']),
  );
}

class BillCheckoutResult {
  const BillCheckoutResult({required this.bill, required this.checkout});
  final PlatformBill bill;
  final BillCheckout checkout;

  factory BillCheckoutResult.fromJson(Map<String, dynamic> json) =>
      BillCheckoutResult(
        bill: PlatformBill.fromJson(asMap(json['bill'])),
        checkout: BillCheckout.fromJson(asMap(json['checkout'])),
      );
}

class PaymentGatewayConfig {
  const PaymentGatewayConfig({
    required this.enabled,
    this.provider,
    this.razorpayKeyId,
    this.cashfreeAppId,
    this.cashfreeEnvironment = 'sandbox',
    this.available = false,
  });

  final bool enabled;
  final String? provider;
  final String? razorpayKeyId;
  final String? cashfreeAppId;
  final String cashfreeEnvironment;
  final bool available;

  factory PaymentGatewayConfig.fromJson(Map<String, dynamic> json) {
    final razorpay = asMap(json['razorpay']);
    final cashfree = asMap(json['cashfree']);
    return PaymentGatewayConfig(
      enabled: json['enabled'] == true || asInt(json['enabled']) == 1,
      provider: asNullableString(json['provider']),
      razorpayKeyId: asNullableString(razorpay['key_id']),
      cashfreeAppId: asNullableString(cashfree['app_id']),
      cashfreeEnvironment: cashfree['environment']?.toString() ?? 'sandbox',
      available: json['available'] == true || asInt(json['available']) == 1,
    );
  }
}

class PaymentGatewayDraft {
  const PaymentGatewayDraft({
    required this.enabled,
    required this.provider,
    required this.cashfreeEnvironment,
    this.razorpayKeyId,
    this.razorpayKeySecret,
    this.razorpayWebhookSecret,
    this.cashfreeAppId,
    this.cashfreeSecretKey,
    this.cashfreeWebhookSecret,
    this.cashfreeApiVersion = '2025-01-01',
  });

  final bool enabled;
  final String provider;
  final String cashfreeEnvironment;
  final String? razorpayKeyId;
  final String? razorpayKeySecret;
  final String? razorpayWebhookSecret;
  final String? cashfreeAppId;
  final String? cashfreeSecretKey;
  final String? cashfreeWebhookSecret;
  final String cashfreeApiVersion;

  Map<String, dynamic> toJson() => {
    'payment_gateway_enabled': enabled,
    'payment_gateway_provider': provider,
    'cashfree_environment': cashfreeEnvironment,
    'cashfree_api_version': cashfreeApiVersion,
    if (razorpayKeyId?.trim().isNotEmpty == true)
      'razorpay_key_id': razorpayKeyId!.trim(),
    if (razorpayKeySecret?.trim().isNotEmpty == true)
      'razorpay_key_secret': razorpayKeySecret!.trim(),
    if (razorpayWebhookSecret?.trim().isNotEmpty == true)
      'razorpay_webhook_secret': razorpayWebhookSecret!.trim(),
    if (cashfreeAppId?.trim().isNotEmpty == true)
      'cashfree_app_id': cashfreeAppId!.trim(),
    if (cashfreeSecretKey?.trim().isNotEmpty == true)
      'cashfree_secret_key': cashfreeSecretKey!.trim(),
    if (cashfreeWebhookSecret?.trim().isNotEmpty == true)
      'cashfree_webhook_secret': cashfreeWebhookSecret!.trim(),
  };
}

class PlatformBillDraft {
  const PlatformBillDraft({
    required this.corpId,
    required this.paymentType,
    required this.periodType,
    required this.issueDate,
    required this.dueDate,
    required this.amount,
    required this.gstEnabled,
    required this.gstType,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    required this.sendEmail,
    this.periodStart,
    this.periodEnd,
    this.clientEmail,
    this.recipients = const [],
    this.notes,
  });

  final String corpId;
  final String paymentType;
  final String periodType;
  final DateTime issueDate;
  final DateTime dueDate;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double amount;
  final bool gstEnabled;
  final String gstType;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final bool sendEmail;
  final String? clientEmail;
  final List<String> recipients;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'corp_id': corpId,
    'payment_type': paymentType,
    'period_type': periodType,
    'issue_date': _date(issueDate),
    'due_date': _date(dueDate),
    if (periodType == 'custom') ...{
      'period_start': _date(periodStart!),
      'period_end': _date(periodEnd!),
    },
    'package_amount': amount,
    'gst_enabled': gstEnabled,
    'gst_type': gstEnabled ? gstType : 'none',
    'cgst_percent': gstType == 'cgst_sgst' ? cgstPercent : 0,
    'sgst_percent': gstType == 'cgst_sgst' ? sgstPercent : 0,
    'igst_percent': gstType == 'igst' ? igstPercent : 0,
    'client_email': clientEmail,
    'recipients': recipients,
    'send_email': sendEmail,
    'notes': notes,
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
