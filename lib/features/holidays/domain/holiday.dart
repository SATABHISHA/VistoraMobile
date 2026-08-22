import 'package:vistora_mobile/core/api/api_parsing.dart';

class Holiday {
  const Holiday({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
  });

  final int id;
  final DateTime date;
  final String name;
  final String type;

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    id: asInt(json['id']),
    date: asDateTime(json['date']) ?? DateTime.now(),
    name: json['name']?.toString() ?? 'Holiday',
    type: json['type']?.toString() ?? 'Company',
  );
}
