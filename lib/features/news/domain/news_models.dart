import 'package:vistora_mobile/core/api/api_parsing.dart';

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.message,
    required this.publishedAt,
    this.linkUrl,
    this.targetScope = 'tenant',
    this.status = 'published',
    this.tenantName,
    this.corpId,
    this.recipientCount = 0,
  });

  final int id;
  final String title;
  final String message;
  final DateTime? publishedAt;
  final String? linkUrl;
  final String targetScope;
  final String status;
  final String? tenantName;
  final String? corpId;
  final int recipientCount;

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    id: asInt(json['id']),
    title: json['title']?.toString() ?? 'Vistora update',
    message: json['message']?.toString() ?? '',
    publishedAt: asDateTime(json['published_at']),
    linkUrl: asNullableString(json['link_url']),
    targetScope: json['target_scope']?.toString() ?? 'tenant',
    status: json['status']?.toString() ?? 'published',
    tenantName: asNullableString(json['tenant_name']),
    corpId: asNullableString(json['corp_id']),
    recipientCount: asInt(json['recipient_count']),
  );
}

class NewsPage {
  const NewsPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<NewsItem> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < lastPage;
}

class NewsEmployee {
  const NewsEmployee({
    required this.id,
    required this.name,
    required this.empCode,
    this.email,
    this.corpId,
    this.userId,
  });

  final int id;
  final String name;
  final String empCode;
  final String? email;
  final String? corpId;
  final int? userId;

  factory NewsEmployee.fromJson(Map<String, dynamic> json) => NewsEmployee(
    id: asInt(json['id']),
    name: json['name']?.toString() ?? 'Employee',
    empCode: json['emp_code']?.toString() ?? '',
    email: asNullableString(json['email']),
    corpId: asNullableString(json['corp_id']),
    userId: _nullableInt(json['user_id']),
  );

  static int? _nullableInt(Object? value) => switch (value) {
    int number => number,
    String text => int.tryParse(text),
    _ => null,
  };
}

class NewsTenantTarget {
  const NewsTenantTarget({
    required this.id,
    required this.corpId,
    required this.companyName,
  });

  final int id;
  final String corpId;
  final String companyName;

  factory NewsTenantTarget.fromJson(Map<String, dynamic> json) =>
      NewsTenantTarget(
        id: asInt(json['id']),
        corpId: json['corp_id']?.toString() ?? '',
        companyName: json['company_name']?.toString() ?? 'Tenant',
      );
}
