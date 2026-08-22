Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> asList(Object? value) => value is List ? value : const [];

int asInt(Object? value, [int fallback = 0]) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};

double asDouble(Object? value, [double fallback = 0]) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text) ?? fallback,
  _ => fallback,
};

DateTime? asDateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

String? asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
