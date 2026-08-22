import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/features/holidays/domain/holiday.dart';

void main() {
  test('parses a tenant holiday API item', () {
    final holiday = Holiday.fromJson({
      'id': '17',
      'date': '2026-10-02',
      'name': 'Gandhi Jayanti',
      'type': 'National',
    });

    expect(holiday.id, 17);
    expect(holiday.date, DateTime(2026, 10, 2));
    expect(holiday.name, 'Gandhi Jayanti');
    expect(holiday.type, 'National');
  });
}
