/// Readers for the handful of shapes the API sends a field in.
///
/// Mongo documents reach the app with `_id` rather than `id`, optional strings
/// arrive as `null`, `''` or whitespace depending on how they were written, and
/// numbers can be either JSON numbers or strings. Parsing that in one place
/// keeps every model's `fromJson` down to a list of field names.
class JsonField {
  const JsonField._();

  /// Mongo sends `_id`; a `toJSON` transform sends `id`. Both appear.
  static String id(Map<String, dynamic> json) {
    final value = json['id'] ?? json['_id'];
    return value is String ? value : value?.toString() ?? '';
  }

  /// An optional string, treating blank as absent.
  static String? text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int? integer(Object? value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };

  static double? decimal(Object? value) => switch (value) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value),
    _ => null,
  };

  /// A referenced document's id, whether the route sent the raw ObjectId or
  /// populated the whole document in its place.
  static String reference(Object? value) => switch (value) {
    final String value => value,
    final Map<String, dynamic> value => id(value),
    _ => value?.toString() ?? '',
  };
}
