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
    required this.attendanceHoursVisibleToSelf,
    required this.geofenceRadiusMeters,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpEncryption,
    required this.smtpFromEmail,
    required this.smtpFromName,
    this.officeLatitude,
    this.officeLongitude,
    this.geofenceEmployeeIds = const [],
    this.geofenceEmployees = const [],
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
  final bool attendanceHoursVisibleToSelf;
  final double? officeLatitude;
  final double? officeLongitude;
  final int geofenceRadiusMeters;
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpEncryption;
  final String smtpFromEmail;
  final String smtpFromName;
  final List<int> geofenceEmployeeIds;
  final List<GeofenceEmployee> geofenceEmployees;

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
    attendanceHoursVisibleToSelf:
        json['attendance_hours_visible_to_self'] == null ||
        json['attendance_hours_visible_to_self'] == true ||
        asInt(json['attendance_hours_visible_to_self']) == 1,
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
    geofenceEmployeeIds: asList(
      json['geofence_employee_ids'],
    ).map((item) => asInt(item)).where((id) => id > 0).toList(),
    geofenceEmployees: asList(
      json['geofence_employees'],
    ).map((item) => GeofenceEmployee.fromJson(asMap(item))).toList(),
  );
}

class GeofenceEmployee {
  const GeofenceEmployee({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
  });

  final int id;
  final String code;
  final String name;
  final String status;

  factory GeofenceEmployee.fromJson(Map<String, dynamic> json) {
    final name = [json['first_name'], json['middle_name'], json['last_name']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ');
    return GeofenceEmployee(
      id: asInt(json['id']),
      code: json['emp_code']?.toString() ?? '',
      name: name.isEmpty ? 'Employee' : name,
      status: json['status']?.toString() ?? 'active',
    );
  }
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
