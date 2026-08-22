import 'package:vistora_mobile/features/auth/domain/app_user.dart';

class TenantFeatures {
  const TenantFeatures({
    this.fileManager = false,
    this.mr = false,
    this.projects = false,
    this.geofence = false,
  });

  final bool fileManager;
  final bool mr;
  final bool projects;
  final bool geofence;

  factory TenantFeatures.fromJson(Map<String, dynamic>? json) {
    return TenantFeatures(
      fileManager: json?['file_manager'] == true,
      mr: json?['mr'] == true,
      projects: json?['projects'] == true,
      geofence: json?['geofence'] == true,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.permissions,
    required this.features,
    this.employeeId,
    this.employeeCode,
    this.companyName,
  });

  final AppUser user;
  final List<String> permissions;
  final TenantFeatures features;
  final int? employeeId;
  final String? employeeCode;
  final String? companyName;

  bool hasPermission(String permission) => permissions.contains(permission);

  factory AuthSession.fromMeResponse(Map<String, dynamic> response) {
    final data = _map(response['data']);
    final employee = _mapOrNull(data['employee']);
    final tenant = _mapOrNull(data['tenant']);
    final permissions = data['permissions'];
    return AuthSession(
      user: AppUser.fromJson(_map(data['user'])),
      permissions: permissions is List
          ? permissions.map((item) => item.toString()).toList(growable: false)
          : const [],
      features: TenantFeatures.fromJson(_mapOrNull(data['features'])),
      employeeId: _nullableInt(employee?['id']),
      employeeCode: employee?['emp_code']?.toString(),
      companyName: tenant?['company_name']?.toString(),
    );
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static int? _nullableInt(Object? value) => switch (value) {
    int number => number,
    String text => int.tryParse(text),
    _ => null,
  };
}
