class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.roleType,
    this.corpId,
    this.username,
    this.email,
    this.status,
  });

  final int id;
  final String? corpId;
  final String name;
  final String? username;
  final String? email;
  final String roleType;
  final String? status;

  String get normalizedRole => roleType.toLowerCase();
  bool get isSuperadmin => normalizedRole == 'superadmin';
  bool get isCompanyManager =>
      const {'admin', 'hr', 'superadmin'}.contains(normalizedRole);
  bool get isSupervisor => normalizedRole == 'supervisor';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _asInt(json['id']),
      corpId: (json['corp_id'] ?? json['corpId'])?.toString(),
      name: json['name']?.toString() ?? 'Vistora User',
      username: json['username']?.toString(),
      email: json['email']?.toString(),
      roleType:
          (json['role_type'] ?? json['roleType'])?.toString() ?? 'Employee',
      status: json['status']?.toString(),
    );
  }

  static int _asInt(Object? value) => switch (value) {
    int number => number,
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}
