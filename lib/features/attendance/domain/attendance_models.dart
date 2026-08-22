import 'package:vistora_mobile/core/api/api_parsing.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.status,
    required this.workedMinutes,
    this.date,
    this.checkInAt,
    this.checkOutAt,
    this.isLive = false,
    this.geofenceStatus = false,
  });

  final int id;
  final int employeeId;
  final String status;
  final int workedMinutes;
  final DateTime? date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final bool isLive;
  final bool geofenceStatus;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: asInt(json['id']),
        employeeId: asInt(json['employee_id']),
        status: json['status']?.toString() ?? 'unknown',
        workedMinutes: asInt(
          json['worked_minutes_live'] ?? json['worked_minutes'],
        ),
        date: asDateTime(json['attendance_date']),
        checkInAt: asDateTime(json['check_in_at']),
        checkOutAt: asDateTime(json['check_out_at']),
        isLive: json['is_live'] == true,
        geofenceStatus: json['geofence_status'] == true,
      );
}

class GeofenceInfo {
  const GeofenceInfo({
    required this.enabled,
    this.inside,
    this.distanceMeters,
    this.radiusMeters,
  });

  final bool enabled;
  final bool? inside;
  final double? distanceMeters;
  final double? radiusMeters;

  factory GeofenceInfo.fromJson(Map<String, dynamic> json) => GeofenceInfo(
    enabled: json['enabled'] == true,
    inside: json['inside'] as bool?,
    distanceMeters: json['distance_meters'] == null
        ? null
        : asDouble(json['distance_meters']),
    radiusMeters: json['radius_meters'] == null
        ? null
        : asDouble(json['radius_meters']),
  );
}

class TodayAttendance {
  const TodayAttendance({
    required this.canClockIn,
    required this.canClockOut,
    required this.serverTime,
    required this.geofence,
    this.attendance,
  });

  final bool canClockIn;
  final bool canClockOut;
  final DateTime? serverTime;
  final GeofenceInfo geofence;
  final AttendanceRecord? attendance;

  factory TodayAttendance.fromResponse(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    final attendance = data['attendance'];
    return TodayAttendance(
      canClockIn: data['canClockIn'] == true,
      canClockOut: data['canClockOut'] == true,
      serverTime: asDateTime(data['serverTime']),
      geofence: GeofenceInfo.fromJson(asMap(data['geofence'])),
      attendance: attendance is Map
          ? AttendanceRecord.fromJson(asMap(attendance))
          : null,
    );
  }
}

class AttendanceDay {
  const AttendanceDay({
    required this.id,
    required this.date,
    required this.day,
    required this.weekday,
    required this.status,
    required this.workedMinutes,
    this.checkInAt,
    this.checkOutAt,
    this.leaveName,
  });

  final int? id;
  final DateTime date;
  final int day;
  final String weekday;
  final String? status;
  final int workedMinutes;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String? leaveName;

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
    id: json['id'] == null ? null : asInt(json['id']),
    date: asDateTime(json['date']) ?? DateTime.now(),
    day: asInt(json['day']),
    weekday: json['weekday']?.toString() ?? '',
    status: asNullableString(json['status']),
    workedMinutes: asInt(json['worked_minutes']),
    checkInAt: asDateTime(json['check_in_at']),
    checkOutAt: asDateTime(json['check_out_at']),
    leaveName: asNullableString(json['leave_name']),
  );
}

class AttendanceCalendar {
  const AttendanceCalendar({required this.days, required this.summary});

  final List<AttendanceDay> days;
  final Map<String, int> summary;

  factory AttendanceCalendar.fromResponse(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    final rawSummary = asMap(data['summary']);
    return AttendanceCalendar(
      days: asList(
        data['days'],
      ).map((item) => AttendanceDay.fromJson(asMap(item))).toList(),
      summary: rawSummary.map((key, value) => MapEntry(key, asInt(value))),
    );
  }
}

class AttendanceRosterItem {
  const AttendanceRosterItem({
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.status,
    required this.workedMinutes,
    this.employeeEmail,
    this.employeeMobile,
    this.checkInAt,
    this.checkOutAt,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.isLive = false,
  });

  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String? employeeEmail;
  final String? employeeMobile;
  final String status;
  final int workedMinutes;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final bool isLive;

  factory AttendanceRosterItem.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final name =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return AttendanceRosterItem(
      employeeId: asInt(json['employee_id']),
      employeeName: name.isEmpty ? 'Employee' : name,
      employeeCode: employee['emp_code']?.toString() ?? '—',
      employeeEmail: asNullableString(employee['work_email']),
      employeeMobile: asNullableString(employee['mobile']),
      status: json['status']?.toString() ?? 'absent',
      workedMinutes: asInt(json['worked_minutes']),
      checkInAt: asDateTime(json['check_in_at']),
      checkOutAt: asDateTime(json['check_out_at']),
      latitude: json['latitude'] == null ? null : asDouble(json['latitude']),
      longitude: json['longitude'] == null ? null : asDouble(json['longitude']),
      locationAddress: asNullableString(json['location_address']),
      isLive: json['is_live'] == true,
    );
  }
}

class AttendanceRoster {
  const AttendanceRoster({required this.items, required this.summary});
  final List<AttendanceRosterItem> items;
  final Map<String, int> summary;

  factory AttendanceRoster.fromResponse(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    return AttendanceRoster(
      items: asList(
        data['items'],
      ).map((item) => AttendanceRosterItem.fromJson(asMap(item))).toList(),
      summary: asMap(
        data['summary'],
      ).map((key, value) => MapEntry(key, asInt(value))),
    );
  }
}
