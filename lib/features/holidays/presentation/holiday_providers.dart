import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/holidays/data/holiday_repository.dart';
import 'package:vistora_mobile/features/holidays/domain/holiday.dart';

final holidayRepositoryProvider = Provider<HolidayRepository>(
  (ref) => HolidayRepository(ref.watch(apiClientProvider)),
);

final holidaysProvider = FutureProvider.family<List<Holiday>, int>(
  (ref, year) => ref.watch(holidayRepositoryProvider).list(year: year),
);

final upcomingHolidaysProvider = FutureProvider<List<Holiday>>(
  (ref) => ref.watch(holidayRepositoryProvider).list(upcoming: true),
);
