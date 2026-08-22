import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/features/attendance/domain/attendance_models.dart';

class AttendanceRepository {
  const AttendanceRepository(this._api);

  final ApiClient _api;

  Future<TodayAttendance> today() async =>
      TodayAttendance.fromResponse(await _api.get('/attendance/me/today'));

  Future<TodayAttendance> punch({
    required bool clockIn,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    await _api.post(
      clockIn ? '/attendance/clock-in' : '/attendance/clock-out',
      data: {
        'latitude': ?latitude,
        'longitude': ?longitude,
        'accuracy_meters': ?accuracyMeters,
        'client_timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return today();
  }

  Future<AttendanceCalendar> calendar({
    required int employeeId,
    required int month,
    required int year,
  }) async => AttendanceCalendar.fromResponse(
    await _api.get(
      '/attendance/calendar',
      queryParameters: {
        'employee_id': employeeId,
        'month': month,
        'year': year,
      },
    ),
  );

  Future<void> regularize({
    required int attendanceId,
    required String reason,
  }) => _api.post(
    '/attendance/$attendanceId/regularize',
    data: {'reason': reason},
  );

  Future<AttendanceRoster> roster({
    required DateTime date,
    String? query,
  }) async => AttendanceRoster.fromResponse(
    await _api.get(
      '/attendance',
      queryParameters: {
        'roster': 1,
        'date': _date(date),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    ),
  );

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
