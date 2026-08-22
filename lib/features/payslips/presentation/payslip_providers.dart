import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/features/payslips/data/payslip_repository.dart';
import 'package:vistora_mobile/features/payslips/domain/payslip.dart';
import 'package:vistora_mobile/features/payroll/data/payroll_repository.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';

final payslipRepositoryProvider = Provider<PayslipRepository>(
  (ref) => PayslipRepository(ref.watch(apiClientProvider)),
);

final payslipsProvider = FutureProvider.family<PayslipCollection, int>(
  (ref, year) => ref.watch(payslipRepositoryProvider).mine(year: year),
);

final adminPayrollProvider = FutureProvider.family<PayrollCollection, String>((
  ref,
  period,
) {
  final parts = period.split('-');
  return PayrollRepository(
    ref.watch(apiClientProvider),
  ).cycles(year: int.parse(parts[0]), month: int.parse(parts[1]));
});
