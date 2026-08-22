import 'package:vistora_mobile/core/api/api_parsing.dart';

class MrOption {
  const MrOption({required this.id, required this.name, this.code});
  final int id;
  final String name;
  final String? code;

  factory MrOption.fromJson(Map<String, dynamic> json) => MrOption(
    id: asInt(json['id']),
    name: (json['name'] ?? json['label'] ?? json['doctor_name'] ?? '')
        .toString(),
    code: asNullableString(json['code'] ?? json['emp_code']),
  );
}

class MrEmployeeOption extends MrOption {
  const MrEmployeeOption({
    required super.id,
    required super.name,
    super.code,
    this.stateId,
    this.branchId,
    this.businessUnitId,
  });

  final int? stateId;
  final int? branchId;
  final int? businessUnitId;

  factory MrEmployeeOption.fromJson(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    return MrEmployeeOption(
      id: asInt(json['id']),
      name: ('$first $last').trim().isEmpty
          ? (json['name']?.toString() ?? 'Employee')
          : ('$first $last').trim(),
      code: asNullableString(json['emp_code']),
      stateId: _nullableInt(json['state_id']),
      branchId: _nullableInt(json['branch_id']),
      businessUnitId: _nullableInt(json['business_unit_id']),
    );
  }
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return int.tryParse(value.toString());
}

class MrMetadata {
  const MrMetadata({
    required this.states,
    required this.branches,
    required this.businessUnits,
    required this.employees,
  });
  final List<MrOption> states;
  final List<MrOption> branches;
  final List<MrOption> businessUnits;
  final List<MrEmployeeOption> employees;

  factory MrMetadata.fromJson(Map<String, dynamic> json) => MrMetadata(
    states: _options(json['states']),
    branches: _options(json['branches']),
    businessUnits: _options(json['businessUnits'] ?? json['business_units']),
    employees: asList(
      json['employees'],
    ).map((item) => MrEmployeeOption.fromJson(asMap(item))).toList(),
  );

  static List<MrOption> _options(Object? value) =>
      asList(value).map((item) => MrOption.fromJson(asMap(item))).toList();
}

class MrDoctor {
  const MrDoctor({
    required this.id,
    required this.name,
    required this.status,
    this.specialization,
    this.phone,
    this.email,
  });
  final int id;
  final String name;
  final String status;
  final String? specialization;
  final String? phone;
  final String? email;

  factory MrDoctor.fromJson(Map<String, dynamic> json) => MrDoctor(
    id: asInt(json['id']),
    name: json['doctor_name']?.toString() ?? 'Doctor',
    status: json['status']?.toString() ?? 'active',
    specialization: asNullableString(json['specialization']),
    phone: asNullableString(json['phone']),
    email: asNullableString(json['email']),
  );
}

class MrLocation {
  const MrLocation({
    required this.id,
    required this.address,
    required this.stateId,
    required this.status,
    this.city,
    this.stateName,
    this.latitude,
    this.longitude,
    this.radiusMeters = 100,
  });
  final int id;
  final String address;
  final String? city;
  final int stateId;
  final String? stateName;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final String status;

  factory MrLocation.fromJson(Map<String, dynamic> json) {
    final state = asMap(json['state']);
    return MrLocation(
      id: asInt(json['id']),
      address: json['address']?.toString() ?? 'Location',
      city: asNullableString(json['city']),
      stateId: asInt(json['state_id'] ?? state['id']),
      stateName: asNullableString(state['name']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      radiusMeters: asInt(json['geofence_radius_meters'], 100),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class MrTerritory {
  const MrTerritory({
    required this.id,
    required this.doctorId,
    required this.stateId,
    required this.branchId,
    required this.businessUnitId,
    required this.isActive,
    this.doctorName,
    this.stateName,
    this.branchName,
    this.businessUnitName,
  });
  final int id;
  final int doctorId;
  final int stateId;
  final int branchId;
  final int businessUnitId;
  final bool isActive;
  final String? doctorName;
  final String? stateName;
  final String? branchName;
  final String? businessUnitName;

  factory MrTerritory.fromJson(Map<String, dynamic> json) {
    final doctor = asMap(json['doctor']);
    final state = asMap(json['state']);
    final branch = asMap(json['branch']);
    final unit = asMap(json['business_unit'] ?? json['businessUnit']);
    return MrTerritory(
      id: asInt(json['id']),
      doctorId: asInt(json['doctor_id'] ?? doctor['id']),
      stateId: asInt(json['state_id'] ?? state['id']),
      branchId: asInt(json['branch_id'] ?? branch['id']),
      businessUnitId: asInt(json['business_unit_id'] ?? unit['id']),
      isActive: json['is_active'] != false && json['is_active'] != 0,
      doctorName: asNullableString(doctor['doctor_name']),
      stateName: asNullableString(state['name']),
      branchName: asNullableString(branch['name']),
      businessUnitName: asNullableString(unit['name']),
    );
  }
}

class MrAssignment {
  const MrAssignment({
    required this.id,
    required this.employeeId,
    required this.doctorId,
    required this.locationId,
    required this.territoryId,
    required this.visitDate,
    required this.status,
    required this.visitingStatus,
    this.employeeName,
    this.employeeCode,
    this.doctorName,
    this.locationAddress,
    this.instructions,
    this.report,
  });
  final int id;
  final int employeeId;
  final int doctorId;
  final int locationId;
  final int territoryId;
  final DateTime visitDate;
  final String status;
  final String visitingStatus;
  final String? employeeName;
  final String? employeeCode;
  final String? doctorName;
  final String? locationAddress;
  final String? instructions;
  final MrVisitReport? report;

  factory MrAssignment.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final doctor = asMap(json['doctor']);
    final location = asMap(json['location']);
    final reportJson = asMap(json['visit_report'] ?? json['visitReport']);
    final employeeName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return MrAssignment(
      id: asInt(json['id']),
      employeeId: asInt(json['employee_id'] ?? employee['id']),
      doctorId: asInt(json['doctor_id'] ?? doctor['id']),
      locationId: asInt(json['location_id'] ?? location['id']),
      territoryId: asInt(json['doctor_territory_id']),
      visitDate: asDateTime(json['visit_date']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'planned',
      visitingStatus: json['visiting_status']?.toString() ?? 'not visited',
      employeeName: employeeName.isEmpty
          ? asNullableString(employee['name'])
          : employeeName,
      employeeCode: asNullableString(employee['emp_code']),
      doctorName: asNullableString(doctor['doctor_name']),
      locationAddress: asNullableString(location['address']),
      instructions: asNullableString(json['instructions']),
      report: reportJson.isEmpty ? null : MrVisitReport.fromJson(reportJson),
    );
  }
}

class MrVisitReport {
  const MrVisitReport({
    required this.id,
    required this.assignmentId,
    required this.employeeId,
    required this.status,
    this.visitedAt,
    this.doctorName,
    this.locationAddress,
    this.employeeName,
    this.notes,
    this.outcome,
    this.reviewNotes,
    this.checkInSource,
    this.distanceMeters,
  });
  final int id;
  final int assignmentId;
  final int employeeId;
  final String status;
  final DateTime? visitedAt;
  final String? doctorName;
  final String? locationAddress;
  final String? employeeName;
  final String? notes;
  final String? outcome;
  final String? reviewNotes;
  final String? checkInSource;
  final double? distanceMeters;

  factory MrVisitReport.fromJson(Map<String, dynamic> json) {
    final assignment = asMap(json['assignment']);
    final doctor = asMap(assignment['doctor']);
    final location = asMap(assignment['location']);
    final employee = asMap(json['employee']);
    final employeeName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return MrVisitReport(
      id: asInt(json['id']),
      assignmentId: asInt(json['assignment_id'] ?? assignment['id']),
      employeeId: asInt(json['employee_id'] ?? employee['id']),
      status: json['status']?.toString() ?? 'draft',
      visitedAt: asDateTime(json['visited_at']),
      doctorName: asNullableString(doctor['doctor_name']),
      locationAddress: asNullableString(location['address']),
      employeeName: employeeName.isEmpty
          ? asNullableString(employee['name'])
          : employeeName,
      notes: asNullableString(json['notes']),
      outcome: asNullableString(json['outcome']),
      reviewNotes: asNullableString(json['review_notes']),
      checkInSource: asNullableString(json['check_in_source']),
      distanceMeters: _nullableDouble(json['distance_meters']),
    );
  }
}

double? _nullableDouble(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text),
  _ => null,
};
