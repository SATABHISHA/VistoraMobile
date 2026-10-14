import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/news/domain/news_models.dart';

class NewsRepository {
  const NewsRepository(this._api);
  final ApiClient _api;

  Future<NewsPage> list({
    int page = 1,
    int perPage = 5,
    int? year,
    int? month,
    DateTime? date,
  }) async {
    final response = await _api.get(
      '/news',
      queryParameters: {
        'page': page,
        'perPage': perPage,
        if (year != null) 'year': year,
        if (month != null) 'month': month,
        if (date != null) 'date': _date(date),
      },
    );
    return _page(asMap(asMap(response['data'])['items']));
  }

  Future<NewsItem?> popup() async {
    final response = await _api.get('/news/popup');
    final raw = asMap(response['data'])['news'];
    return raw is Map ? NewsItem.fromJson(asMap(raw)) : null;
  }

  Future<void> dismiss(int id) => _api.post('/news/$id/dismiss');

  Future<NewsPage> adminList({
    int page = 1,
    int perPage = 5,
    int? year,
    int? month,
    DateTime? date,
    String? status,
  }) async {
    final response = await _api.get(
      '/superadmin/news',
      queryParameters: {
        'page': page,
        'perPage': perPage,
        if (year != null) 'year': year,
        if (month != null) 'month': month,
        if (date != null) 'date': _date(date),
        if (status?.isNotEmpty == true) 'status': status,
      },
    );
    return _page(asMap(asMap(response['data'])['items']));
  }

  Future<NewsTargets> targets({
    String? corpId,
    String? query,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _api.get(
      '/superadmin/news/targets',
      queryParameters: {
        'page': page,
        'perPage': perPage,
        if (corpId?.isNotEmpty == true) 'corp_id': corpId,
        if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
      },
    );
    final data = asMap(response['data']);
    final employees = asMap(data['employees']);
    return NewsTargets(
      tenants: asList(
        data['tenants'],
      ).map((item) => NewsTenantTarget.fromJson(asMap(item))).toList(),
      employees: asList(
        employees['data'],
      ).map((item) => NewsEmployee.fromJson(asMap(item))).toList(),
      page: asInt(employees['current_page'], 1),
      lastPage: asInt(employees['last_page'], 1),
      total: asInt(employees['total']),
    );
  }

  Future<void> publish({
    required String title,
    required String message,
    required String scope,
    String? corpId,
    String? linkUrl,
    List<int> employeeIds = const [],
  }) => _api.post(
    '/superadmin/news',
    data: {
      'title': title.trim(),
      'message': message.trim(),
      'target_scope': scope,
      'status': 'published',
      if (corpId?.isNotEmpty == true) 'corp_id': corpId,
      if (linkUrl?.trim().isNotEmpty == true) 'link_url': linkUrl!.trim(),
      if (scope == 'employee') 'employee_ids': employeeIds,
    },
  );

  Future<void> setStatus(int id, String status) =>
      _api.post('/superadmin/news/$id/$status');

  NewsPage _page(Map<String, dynamic> paginator) => NewsPage(
    items: asList(
      paginator['data'],
    ).map((item) => NewsItem.fromJson(asMap(item))).toList(),
    page: asInt(paginator['current_page'], 1),
    lastPage: asInt(paginator['last_page'], 1),
    total: asInt(paginator['total']),
  );

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class NewsTargets {
  const NewsTargets({
    required this.tenants,
    required this.employees,
    required this.page,
    required this.lastPage,
    required this.total,
  });
  final List<NewsTenantTarget> tenants;
  final List<NewsEmployee> employees;
  final int page;
  final int lastPage;
  final int total;
  bool get hasPrevious => page > 1;
  bool get hasNext => page < lastPage;
}
