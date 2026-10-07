import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/hr_operations/data/hr_operations_repository.dart';
import 'package:vistora_mobile/features/hr_operations/domain/hr_operations_models.dart';
import 'package:vistora_mobile/features/hr_operations/presentation/hr_operations_screen.dart';

class _RecruitmentRepository extends Fake implements HrOperationsRepository {
  String currentStatus = 'selected';
  final actions = <String>[];
  final loads = <({String? status, String? view, int page})>[];

  @override
  Future<HrPage<RecruitmentCandidate>> candidates({
    String? query,
    String? status,
    String? interviewView,
    String? interviewMode,
    String? interviewDateFrom,
    String? interviewDateTo,
    int page = 1,
    int perPage = 10,
  }) async {
    loads.add((status: status, view: interviewView, page: page));
    final candidate = RecruitmentCandidate(
      id: 1,
      name: 'Anita Singh',
      email: 'anita@example.test',
      status: currentStatus,
      interviews: [
        RecruitmentInterview(
          id: 9,
          scheduledAt: DateTime(2026, 10, 7, 10),
          mode: 'phone',
          status: 'feedback_received',
          panelists: const [],
          feedback: const [
            RecruitmentFeedback(
              panelistUserId: 2,
              panelistName: 'Panelist',
              rating: 5,
              recommendation: 'select',
              feedback: 'Recommended',
            ),
          ],
        ),
      ],
    );
    return HrPage(items: [candidate], page: 1, lastPage: 1, total: 1);
  }

  @override
  Future<Map<String, dynamic>> pipelineActionResult(
    int candidateId,
    String action,
  ) async {
    actions.add(action);
    currentStatus = 'interview';
    return {
      'success': true,
      'data': {
        'candidate': {'id': candidateId, 'status': currentStatus},
      },
    };
  }
}

Future<void> _openSelected(
  WidgetTester tester,
  _RecruitmentRepository repository,
) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hrOperationsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: HrOperationsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Selected candidates'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Rollback'));
  await tester.tap(find.text('Rollback'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(repository.actions, isEmpty);
}

void main() {
  testWidgets('Cancel leaves selected candidate and current list unchanged', (
    tester,
  ) async {
    final repository = _RecruitmentRepository();
    await _openSelected(tester, repository);
    final loadsBeforeCancel = repository.loads.length;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.actions, isEmpty);
    expect(repository.loads.length, loadsBeforeCancel);
    expect(repository.currentStatus, 'selected');
    expect(find.text('Anita Singh'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OK rolls back once and refreshes the completed destination', (
    tester,
  ) async {
    final repository = _RecruitmentRepository();
    await _openSelected(tester, repository);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(repository.actions, ['back']);
    expect(repository.loads.last, (
      status: 'interview',
      view: 'completed',
      page: 1,
    ));
    expect(find.text('Anita Singh'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    final stage = tester.widget<DropdownButtonFormField<String?>>(
      find.byKey(const ValueKey<String?>('interview')),
    );
    expect(stage.initialValue, 'interview');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
