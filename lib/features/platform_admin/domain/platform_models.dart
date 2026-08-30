import 'package:vistora_mobile/core/api/api_parsing.dart';

class PlatformPage<T> {
  const PlatformPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class PlatformTenant {
  const PlatformTenant({
    required this.id,
    required this.corpId,
    required this.companyName,
    required this.status,
    required this.employeeCount,
    required this.adminCount,
    required this.storageUsedBytes,
    required this.storageQuotaMb,
    required this.mrEnabled,
    required this.projectsEnabled,
    required this.fileManagerEnabled,
    required this.financeHubEnabled,
    this.gstin,
    this.phone,
    this.registeredAddress,
    this.timezone,
    this.locale,
  });

  final int id;
  final String corpId;
  final String companyName;
  final String status;
  final int employeeCount;
  final int adminCount;
  final int storageUsedBytes;
  final int storageQuotaMb;
  final bool mrEnabled;
  final bool projectsEnabled;
  final bool fileManagerEnabled;
  final bool financeHubEnabled;
  final String? gstin;
  final String? phone;
  final String? registeredAddress;
  final String? timezone;
  final String? locale;

  factory PlatformTenant.fromJson(Map<String, dynamic> json) => PlatformTenant(
    id: asInt(json['id']),
    corpId: json['corp_id']?.toString() ?? '',
    companyName: json['company_name']?.toString() ?? 'Company',
    status: json['status']?.toString() ?? 'inactive',
    employeeCount: asInt(json['employee_count']),
    adminCount: asInt(json['admin_count']),
    storageUsedBytes: asInt(json['storage_used_bytes']),
    storageQuotaMb: asInt(json['storage_quota_mb']),
    mrEnabled: json['mr_enabled'] == true || asInt(json['mr_enabled']) == 1,
    projectsEnabled:
        json['project_management_enabled'] == true ||
        asInt(json['project_management_enabled']) == 1,
    fileManagerEnabled:
        json['file_manager_enabled'] == true ||
        asInt(json['file_manager_enabled']) == 1,
    financeHubEnabled:
        json['finance_hub_enabled'] == true ||
        asInt(json['finance_hub_enabled']) == 1,
    gstin: asNullableString(json['gstin']),
    phone: asNullableString(json['phone']),
    registeredAddress: asNullableString(json['registered_address']),
    timezone: asNullableString(json['timezone']),
    locale: asNullableString(json['locale']),
  );
}

class PlatformPayment {
  const PlatformPayment({
    required this.id,
    required this.corpId,
    required this.packageAmount,
    required this.gstAmount,
    required this.totalAmount,
    required this.periodType,
    required this.status,
    this.companyName,
    this.invoiceNo,
    this.paymentType = 'period',
    this.periodStart,
    this.periodEnd,
    this.gstEnabled = false,
    this.gstType = 'none',
    this.gstPercent = 0,
    this.cgstPercent = 0,
    this.sgstPercent = 0,
    this.igstPercent = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.paymentMode = 'online',
    this.chequeNo,
    this.transactionReference,
    this.notes,
    this.paymentDate,
  });

  final int id;
  final String corpId;
  final double packageAmount;
  final double gstAmount;
  final double totalAmount;
  final String periodType;
  final String status;
  final String? companyName;
  final String? invoiceNo;
  final String paymentType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool gstEnabled;
  final String gstType;
  final double gstPercent;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final String paymentMode;
  final String? chequeNo;
  final String? transactionReference;
  final String? notes;
  final DateTime? paymentDate;

  factory PlatformPayment.fromJson(Map<String, dynamic> json) =>
      PlatformPayment(
        id: asInt(json['id']),
        corpId: json['corp_id']?.toString() ?? '',
        packageAmount: asDouble(json['package_amount']),
        gstAmount: asDouble(json['gst_amount']),
        totalAmount: asDouble(json['total_amount']),
        periodType: json['period_type']?.toString() ?? 'monthly',
        status: json['status']?.toString() ?? 'recorded',
        companyName: asNullableString(json['company_name']),
        invoiceNo: asNullableString(json['invoice_no']),
        paymentType: json['payment_type']?.toString() ?? 'period',
        periodStart: asDateTime(json['period_start']),
        periodEnd: asDateTime(json['period_end']),
        gstEnabled:
            _asBool(json['gst_enabled']) || asDouble(json['gst_amount']) > 0,
        gstType:
            json['gst_type']?.toString() ??
            (asDouble(json['gst_amount']) > 0 ? 'cgst_sgst' : 'none'),
        gstPercent: asDouble(json['gst_percent']),
        cgstPercent: asDouble(json['cgst_percent']),
        sgstPercent: asDouble(json['sgst_percent']),
        igstPercent: asDouble(json['igst_percent']),
        cgstAmount: asDouble(json['cgst_amount']),
        sgstAmount: asDouble(json['sgst_amount']),
        igstAmount: asDouble(json['igst_amount']),
        paymentMode: json['payment_mode']?.toString() ?? 'online',
        chequeNo: asNullableString(json['cheque_no']),
        transactionReference: asNullableString(json['transaction_reference']),
        notes: asNullableString(json['notes']),
        paymentDate: asDateTime(json['payment_date']),
      );
}

class PlatformBillingSettings {
  const PlatformBillingSettings({
    required this.providerCompanyName,
    required this.productName,
    required this.contactEmail,
    required this.website,
    required this.gstEnabled,
    required this.gstMode,
    required this.gstPercent,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    this.providerGstin,
    this.providerAddress,
    this.contactPhone,
    this.sealPath,
    this.sealUrl,
  });

  final String providerCompanyName;
  final String productName;
  final String? providerGstin;
  final String? providerAddress;
  final String contactEmail;
  final String? contactPhone;
  final String website;
  final bool gstEnabled;
  final String gstMode;
  final double gstPercent;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final String? sealPath;
  final String? sealUrl;

  factory PlatformBillingSettings.fromJson(Map<String, dynamic> json) =>
      PlatformBillingSettings(
        providerCompanyName:
            json['provider_company_name']?.toString() ??
            'Ahanova AI Technologies Private Limited',
        productName: json['product_name']?.toString() ?? 'Vistora',
        providerGstin: asNullableString(json['provider_gstin']),
        providerAddress: asNullableString(json['provider_address']),
        contactEmail: json['contact_email']?.toString() ?? 'wecare@ahanova.in',
        contactPhone: asNullableString(json['contact_phone']),
        website: json['website']?.toString() ?? 'https://ahanova.in',
        gstEnabled: _asBool(json['gst_enabled']),
        gstMode: json['gst_mode']?.toString() ?? 'cgst_sgst',
        gstPercent: asDouble(json['gst_percent'], 18),
        cgstPercent: asDouble(json['cgst_percent'], 9),
        sgstPercent: asDouble(json['sgst_percent'], 9),
        igstPercent: asDouble(json['igst_percent'], 18),
        sealPath: asNullableString(json['seal_path']),
        sealUrl: asNullableString(json['seal_url']),
      );

  Map<String, dynamic> toJson() => {
    'provider_company_name': providerCompanyName,
    'product_name': productName,
    'provider_gstin': providerGstin,
    'provider_address': providerAddress,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'website': website,
    'gst_enabled': gstEnabled,
    'gst_mode': gstMode,
    'gst_percent': gstPercent,
    'cgst_percent': cgstPercent,
    'sgst_percent': sgstPercent,
    'igst_percent': igstPercent,
  };
}

class PlatformPaymentDraft {
  const PlatformPaymentDraft({
    required this.corpId,
    required this.amount,
    required this.paymentType,
    required this.periodType,
    required this.paymentDate,
    required this.gstEnabled,
    required this.gstType,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    required this.paymentMode,
    this.periodStart,
    this.periodEnd,
    this.chequeNo,
    this.transactionReference,
    this.notes,
  });

  final String corpId;
  final double amount;
  final String paymentType;
  final String periodType;
  final DateTime paymentDate;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool gstEnabled;
  final String gstType;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final String paymentMode;
  final String? chequeNo;
  final String? transactionReference;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'corp_id': corpId,
    'package_amount': amount,
    'payment_type': paymentType,
    'period_type': paymentType == 'period' ? periodType : 'one-time',
    'payment_date': _date(paymentDate),
    if (paymentType == 'period' && periodType == 'custom') ...{
      'period_start': _date(periodStart!),
      'period_end': _date(periodEnd!),
    },
    'gst_enabled': gstEnabled,
    'gst_type': gstEnabled ? gstType : 'none',
    'cgst_percent': gstType == 'cgst_sgst' ? cgstPercent : 0,
    'sgst_percent': gstType == 'cgst_sgst' ? sgstPercent : 0,
    'igst_percent': gstType == 'igst' ? igstPercent : 0,
    'payment_mode': paymentMode,
    if (paymentMode == 'cheque') 'cheque_no': chequeNo,
    if (paymentMode != 'cheque') 'transaction_reference': transactionReference,
    'notes': notes,
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class PlatformOverview {
  const PlatformOverview({
    required this.activeTenants,
    required this.inactiveTenants,
    required this.recentPayments,
  });

  final int activeTenants;
  final int inactiveTenants;
  final List<PlatformPayment> recentPayments;

  factory PlatformOverview.fromJson(Map<String, dynamic> json) =>
      PlatformOverview(
        activeTenants: asInt(json['activeTenants']),
        inactiveTenants: asInt(json['inactiveTenants']),
        recentPayments: asList(
          json['recentPayments'],
        ).map((item) => PlatformPayment.fromJson(asMap(item))).toList(),
      );
}

class PlatformOnboardingItem {
  const PlatformOnboardingItem({
    required this.id,
    required this.submissionId,
    required this.status,
    this.reviewNotes,
    this.createdAt,
  });

  final int id;
  final int submissionId;
  final String status;
  final String? reviewNotes;
  final DateTime? createdAt;

  factory PlatformOnboardingItem.fromJson(Map<String, dynamic> json) =>
      PlatformOnboardingItem(
        id: asInt(json['id']),
        submissionId: asInt(json['submission_id']),
        status: json['status']?.toString() ?? 'pending',
        reviewNotes: asNullableString(json['review_notes']),
        createdAt: asDateTime(json['created_at']),
      );
}

bool _asBool(Object? value) => switch (value) {
  true => true,
  int number => number == 1,
  String text => const {'1', 'true', 'yes', 'on'}.contains(text.toLowerCase()),
  _ => false,
};
