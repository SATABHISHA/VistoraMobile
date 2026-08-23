import 'package:vistora_mobile/core/api/api_parsing.dart';

class TenantSettings {
  const TenantSettings({
    required this.companyName,
    required this.corpId,
    required this.registeredAddress,
    required this.gstin,
    required this.timezone,
    required this.fiscalYearStartMonth,
    required this.employeeCodePrefix,
    required this.employeeCodeNext,
    required this.employeeCodePadding,
    required this.geofenceEnabled,
    required this.geofenceRadiusMeters,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpEncryption,
    required this.smtpFromEmail,
    required this.smtpFromName,
    this.officeLatitude,
    this.officeLongitude,
  });

  final String companyName;
  final String corpId;
  final String registeredAddress;
  final String gstin;
  final String timezone;
  final int fiscalYearStartMonth;
  final String employeeCodePrefix;
  final int employeeCodeNext;
  final int employeeCodePadding;
  final bool geofenceEnabled;
  final double? officeLatitude;
  final double? officeLongitude;
  final int geofenceRadiusMeters;
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpEncryption;
  final String smtpFromEmail;
  final String smtpFromName;

  factory TenantSettings.fromJson(Map<String, dynamic> json) => TenantSettings(
    companyName: json['company_name']?.toString() ?? '',
    corpId: json['corp_id']?.toString() ?? '',
    registeredAddress: json['registered_address']?.toString() ?? '',
    gstin: json['gstin']?.toString() ?? '',
    timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
    fiscalYearStartMonth: asInt(json['fiscal_year_start_month'], 4),
    employeeCodePrefix: json['employee_code_prefix']?.toString() ?? 'EMP',
    employeeCodeNext: asInt(json['employee_code_next'], 1),
    employeeCodePadding: asInt(json['employee_code_padding'], 3),
    geofenceEnabled:
        json['geofence_enabled'] == true ||
        asInt(json['geofence_enabled']) == 1,
    officeLatitude: json['office_latitude'] == null
        ? null
        : asDouble(json['office_latitude']),
    officeLongitude: json['office_longitude'] == null
        ? null
        : asDouble(json['office_longitude']),
    geofenceRadiusMeters: asInt(json['geofence_radius_meters'], 200),
    smtpHost: json['smtp_host']?.toString() ?? '',
    smtpPort: asInt(json['smtp_port'], 587),
    smtpUsername: json['smtp_username']?.toString() ?? '',
    smtpEncryption: json['smtp_encryption']?.toString() ?? 'tls',
    smtpFromEmail: json['smtp_from_email']?.toString() ?? '',
    smtpFromName: json['smtp_from_name']?.toString() ?? '',
  );
}

class MasterItem {
  const MasterItem({required this.id, required this.name, this.code});

  final int id;
  final String name;
  final String? code;

  factory MasterItem.fromJson(Map<String, dynamic> json) => MasterItem(
    id: asInt(json['id']),
    name: json['name']?.toString() ?? 'Item',
    code: asNullableString(json['code']),
  );
}
