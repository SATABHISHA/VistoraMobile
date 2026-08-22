import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/leave/domain/leave_models.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_providers.dart';
import 'package:vistora_mobile/features/leave/presentation/leave_screen.dart';

void main() {
  testWidgets('leave screen shows balance and opens application form', (
    tester,
  ) async {
    const summary = LeaveSummary(
      creditedTotal: 12,
      usedTotal: 2,
      remainingTotal: 10,
      pendingCount: 1,
      approvedCount: 2,
      rejectedCount: 0,
      absentMonth: 0,
      types: [
        LeaveTypeBalance(
          id: 1,
          code: 'CL',
          name: 'Casual Leave',
          credited: 12,
          used: 2,
          remaining: 10,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveSummaryProvider.overrideWith((ref) async => summary),
          leaveRequestsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: LeaveScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10.0'), findsOneWidget);
    expect(find.text('Casual Leave (CL)'), findsOneWidget);
    await tester.tap(find.text('Apply Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Apply for leave'), findsOneWidget);
    expect(find.text('Submit Request'), findsOneWidget);
  });
}
