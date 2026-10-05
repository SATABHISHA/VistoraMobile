import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/performance/domain/performance_models.dart';

void main() {
  test('parses a review with KPI scores and reviewer', () {
    final review = PerformanceReviewItem.fromJson({
      'id': 4,
      'employee_id': 18,
      'review_month': 10,
      'review_year': 2026,
      'quality': 9,
      'timeliness': 8,
      'teamwork': 9,
      'initiative': 7,
      'communication': 8,
      'overall_score': '8.2',
      'comment': 'Strong delivery.',
      'employee': {
        'emp_code': 'EMP018',
        'first_name': 'Meera',
        'last_name': 'Das',
      },
      'supervisor': {
        'first_name': 'Priya',
        'last_name': 'Gupta',
      },
    });

    expect(review.employeeName, 'Meera Das');
    expect(review.periodLabel, 'October 2026');
    expect(review.score('quality'), 9);
    expect(review.overallScore, 8.2);
    expect(review.reviewerName, 'Priya Gupta');
  });
}
