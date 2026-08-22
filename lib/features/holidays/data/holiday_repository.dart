import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/holidays/domain/holiday.dart';

class HolidayRepository {
  const HolidayRepository(this._api);
  final ApiClient _api;

  Future<List<Holiday>> list({int? year, bool upcoming = false}) async {
    final response = await _api.get(
      '/holidays',
      queryParameters: {
        'year': ?year,
        if (upcoming) 'upcoming': 1,
        'perPage': 100,
      },
    );
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return asList(
      page['data'] ?? data['items'],
    ).map((item) => Holiday.fromJson(asMap(item))).toList();
  }

  Future<void> save({
    int? id,
    required DateTime date,
    required String name,
    required String type,
  }) {
    final body = {'date': _date(date), 'name': name.trim(), 'type': type};
    return id == null
        ? _api.post('/holidays', data: body)
        : _api.put('/holidays/$id', data: body);
  }

  Future<void> remove(int id) => _api.delete('/holidays/$id');

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
