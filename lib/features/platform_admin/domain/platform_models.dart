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
    this.paymentDate,
  });

  final int id;
  final String corpId;
  final double packageAmount;
  final double gstAmount;
  final double totalAmount;
  final String periodType;
  final String status;
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
        paymentDate: asDateTime(json['payment_date']),
      );
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
