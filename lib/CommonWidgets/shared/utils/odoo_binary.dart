/// Odoo 20 returns binary fields (e.g. `image_1920`) as
/// `{'content': <base64>, 'size': n}` instead of a plain base64 string.
/// These helpers flatten them so older code paths keep working.
dynamic unwrapOdooBinary(dynamic value) {
  if (value is Map) {
    final content = value['content'];
    return content is String ? content : false;
  }
  return value;
}

/// Flattens the given binary [keys] of every record in [records], in place.
List<Map<String, dynamic>> unwrapOdooBinaries(
  List<Map<String, dynamic>> records, [
  List<String> keys = const ['image_1920', 'image_128', 'avatar_128'],
]) {
  for (final rec in records) {
    for (final key in keys) {
      if (rec.containsKey(key)) rec[key] = unwrapOdooBinary(rec[key]);
    }
  }
  return records;
}
