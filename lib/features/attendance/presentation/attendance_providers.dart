import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/attendance/data/attendance_repository.dart';
import 'package:vistora_mobile/features/attendance/data/location_service.dart';
import 'package:vistora_mobile/features/attendance/domain/attendance_models.dart';
import 'package:vistora_mobile/features/auth/presentation/auth_controller.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(ref.watch(apiClientProvider)),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

final todayAttendanceProvider = FutureProvider<TodayAttendance>(
  (ref) => ref.watch(attendanceRepositoryProvider).today(),
);

class AttendanceMonth {
  const AttendanceMonth(this.year, this.month);
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is AttendanceMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

final attendanceCalendarProvider =
    FutureProvider.family<AttendanceCalendar, AttendanceMonth>((ref, period) {
      final employeeId = ref.watch(
        authControllerProvider.select((state) => state.session?.employeeId),
      );
      if (employeeId == null) {
        throw const FormatException(
          'No employee profile is linked to this login.',
        );
      }
      return ref
          .watch(attendanceRepositoryProvider)
          .calendar(
            employeeId: employeeId,
            month: period.month,
            year: period.year,
          );
    });
