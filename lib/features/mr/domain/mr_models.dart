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

class MrSettings {
  const MrSettings({this.maxLocationsPerDoctor = 2});

  final int maxLocationsPerDoctor;

  factory MrSettings.fromJson(Map<String, dynamic> json) => MrSettings(
    maxLocationsPerDoctor: asInt(
      json['max_locations_per_doctor'],
      2,
    ).clamp(1, 50),
  );
}

class MrMetadata {
  const MrMetadata({
    required this.states,
    required this.branches,
    required this.businessUnits,
    required this.employees,
    required this.settings,
  });

  final List<MrOption> states;
  final List<MrOption> branches;
  final List<MrOption> businessUnits;
  final List<MrEmployeeOption> employees;
  final MrSettings settings;

  factory MrMetadata.fromJson(Map<String, dynamic> json) => MrMetadata(
    states: _options(json['states']),
    branches: _options(json['branches']),
    businessUnits: _options(json['businessUnits'] ?? json['business_units']),
    employees: asList(
      json['employees'],
    ).map((item) => MrEmployeeOption.fromJson(asMap(item))).toList(),
    settings: MrSettings.fromJson(asMap(json['settings'])),
  );

  static List<MrOption> _options(Object? value) =>
      asList(value).map((item) => MrOption.fromJson(asMap(item))).toList();
}

class MrDoctor {
  const MrDoctor({
    required this.id,
    required this.name,
    required this.status,
    required this.locations,
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
  final List<MrLocation> locations;

  int get locationCount => locations.length;

  factory MrDoctor.fromJson(Map<String, dynamic> json) => MrDoctor(
    id: asInt(json['id']),
    name: json['doctor_name']?.toString() ?? 'Doctor',
    status: json['status']?.toString() ?? 'active',
    specialization: asNullableString(json['specialization']),
    phone: asNullableString(json['phone']),
    email: asNullableString(json['email']),
    locations: asList(
      json['locations'],
    ).map((item) => MrLocation.fromJson(asMap(item))).toList(),
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
    this.branchId,
    this.branchName,
    this.businessUnitId,
    this.businessUnitName,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.doctorNames = const [],
  });

  final int id;
  final String address;
  final String? city;
  final int stateId;
  final String? stateName;
  final int? branchId;
  final String? branchName;
  final int? businessUnitId;
  final String? businessUnitName;
  final double? latitude;
  final double? longitude;
  final int? radiusMeters;
  final String status;
  final List<String> doctorNames;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasGeofence => hasCoordinates && radiusMeters != null;

  factory MrLocation.fromJson(Map<String, dynamic> json) {
    final state = asMap(json['state']);
    final branch = asMap(json['branch']);
    final unit = asMap(json['business_unit'] ?? json['businessUnit']);
    return MrLocation(
      id: asInt(json['id']),
      address: json['address']?.toString() ?? 'Location',
      city: asNullableString(json['city']),
      stateId: asInt(json['state_id'] ?? state['id']),
      stateName: asNullableString(state['name']),
      branchId: _nullableInt(json['branch_id'] ?? branch['id']),
      branchName: asNullableString(branch['name']),
      businessUnitId: _nullableInt(json['business_unit_id'] ?? unit['id']),
      businessUnitName: asNullableString(unit['name']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      radiusMeters: _nullableInt(json['geofence_radius_meters']),
      status: json['status']?.toString() ?? 'active',
      doctorNames: asList(json['doctors'])
          .map((item) => asMap(item)['doctor_name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(),
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
    required this.visitDate,
    required this.status,
    required this.visitingStatus,
    required this.location,
    required this.canEdit,
    required this.canDelete,
    required this.geofenceRequired,
    this.territoryId,
    this.employeeName,
    this.employeeCode,
    this.doctorName,
    this.doctorSpecialization,
    this.locationAddress,
    this.instructions,
    this.assignedByName,
    this.report,
  });

  final int id;
  final int employeeId;
  final int doctorId;
  final int locationId;
  final int? territoryId;
  final DateTime visitDate;
  final String status;
  final String visitingStatus;
  final String? employeeName;
  final String? employeeCode;
  final String? doctorName;
  final String? doctorSpecialization;
  final String? locationAddress;
  final String? instructions;
  final String? assignedByName;
  final MrLocation location;
  final bool canEdit;
  final bool canDelete;
  final bool geofenceRequired;
  final MrVisitReport? report;

  factory MrAssignment.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final doctor = asMap(json['doctor']);
    final locationJson = asMap(json['location']);
    final reportJson = asMap(json['visit_report'] ?? json['visitReport']);
    final assigner = asMap(json['assigner']);
    final employeeName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    final location = MrLocation.fromJson(locationJson);
    return MrAssignment(
      id: asInt(json['id']),
      employeeId: asInt(json['employee_id'] ?? employee['id']),
      doctorId: asInt(json['doctor_id'] ?? doctor['id']),
      locationId: asInt(json['location_id'] ?? locationJson['id']),
      territoryId: _nullableInt(json['doctor_territory_id']),
      visitDate: asDateTime(json['visit_date']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'planned',
      visitingStatus: json['visiting_status']?.toString() ?? 'not visited',
      employeeName: employeeName.isEmpty
          ? asNullableString(employee['name'])
          : employeeName,
      employeeCode: asNullableString(employee['emp_code']),
      doctorName: asNullableString(doctor['doctor_name']),
      doctorSpecialization: asNullableString(doctor['specialization']),
      locationAddress: asNullableString(locationJson['address']),
      instructions: asNullableString(json['instructions']),
      assignedByName: asNullableString(assigner['name']),
      location: location,
      canEdit: json['can_edit'] != false,
      canDelete: json['can_delete'] != false,
      geofenceRequired: json['geofence_required'] == true,
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
    required this.submissionCount,
    this.visitedAt,
    this.submittedAt,
    this.rolledBackAt,
    this.doctorName,
    this.locationAddress,
    this.employeeName,
    this.employeeCode,
    this.notes,
    this.outcome,
    this.reviewNotes,
    this.rollbackNotes,
    this.reviewerName,
    this.rollbackActorName,
    this.checkInSource,
    this.capturedAddress,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.accuracyMeters,
  });

  final int id;
  final int assignmentId;
  final int employeeId;
  final String status;
  final int submissionCount;
  final DateTime? visitedAt;
  final DateTime? submittedAt;
  final DateTime? rolledBackAt;
  final String? doctorName;
  final String? locationAddress;
  final String? employeeName;
  final String? employeeCode;
  final String? notes;
  final String? outcome;
  final String? reviewNotes;
  final String? rollbackNotes;
  final String? reviewerName;
  final String? rollbackActorName;
  final String? checkInSource;
  final String? capturedAddress;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final double? accuracyMeters;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory MrVisitReport.fromJson(Map<String, dynamic> json) {
    final assignment = asMap(json['assignment']);
    final doctor = asMap(assignment['doctor']);
    final location = asMap(assignment['location']);
    final employee = asMap(json['employee']);
    final reviewer = asMap(json['reviewer']);
    final rollbackActor = asMap(
      json['rollback_actor'] ?? json['rollbackActor'],
    );
    final employeeName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return MrVisitReport(
      id: asInt(json['id']),
      assignmentId: asInt(json['assignment_id'] ?? assignment['id']),
      employeeId: asInt(json['employee_id'] ?? employee['id']),
      status: json['status']?.toString() ?? 'draft',
      submissionCount: asInt(json['submission_count']),
      visitedAt: asDateTime(json['visited_at']),
      submittedAt: asDateTime(json['submitted_at']),
      rolledBackAt: asDateTime(json['rolled_back_at']),
      doctorName: asNullableString(doctor['doctor_name']),
      locationAddress: asNullableString(location['address']),
      employeeName: employeeName.isEmpty
          ? asNullableString(employee['name'])
          : employeeName,
      employeeCode: asNullableString(employee['emp_code']),
      notes: asNullableString(json['notes']),
      outcome: asNullableString(json['outcome']),
      reviewNotes: asNullableString(json['review_notes']),
      rollbackNotes: asNullableString(json['rollback_notes']),
      reviewerName: asNullableString(reviewer['name']),
      rollbackActorName: asNullableString(rollbackActor['name']),
      checkInSource: asNullableString(json['check_in_source']),
      capturedAddress: asNullableString(json['captured_address']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      distanceMeters: _nullableDouble(json['distance_meters']),
      accuracyMeters: _nullableDouble(json['location_accuracy_meters']),
    );
  }
}

class MrAuditEvent {
  const MrAuditEvent({
    required this.id,
    required this.action,
    required this.entityType,
    required this.occurredAt,
    this.entityId,
    this.actorName,
    this.actorRole,
    this.employeeName,
    this.employeeCode,
    this.oldValues = const {},
    this.newValues = const {},
  });

  final int id;
  final String action;
  final String entityType;
  final int? entityId;
  final DateTime occurredAt;
  final String? actorName;
  final String? actorRole;
  final String? employeeName;
  final String? employeeCode;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;

  factory MrAuditEvent.fromJson(Map<String, dynamic> json) {
    final actor = asMap(json['actor']);
    final employee = asMap(json['subject_employee'] ?? json['subjectEmployee']);
    final employeeName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return MrAuditEvent(
      id: asInt(json['id']),
      action: json['action']?.toString() ?? 'mr.updated',
      entityType: json['entity_type']?.toString() ?? 'MR record',
      entityId: _nullableInt(json['entity_id']),
      occurredAt: asDateTime(json['occurred_at']) ?? DateTime.now(),
      actorName: asNullableString(actor['name']),
      actorRole: asNullableString(json['actor_role']),
      employeeName: employeeName.isEmpty ? null : employeeName,
      employeeCode: asNullableString(employee['emp_code']),
      oldValues: asMap(json['old_values_json']),
      newValues: asMap(json['new_values_json']),
    );
  }
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _nullableDouble(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text),
  _ => null,
};
