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

/// Reads a tenant-local ISO value without shifting its wall-clock time to the
/// device timezone. Falls back to the normal instant parser for older APIs.
DateTime? asTenantLocalDateTime(Object? localValue, [Object? fallback]) {
  final raw = localValue?.toString().trim();
  if (raw != null && raw.isNotEmpty) {
    final wallClock = raw.replaceFirst(RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$'), '');
    final parsed = DateTime.tryParse(wallClock);
    if (parsed != null) return parsed;
  }
  return asDateTime(fallback ?? localValue);
}

String? asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
