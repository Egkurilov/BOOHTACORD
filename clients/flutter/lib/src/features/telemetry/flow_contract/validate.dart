import 'generated.dart';

bool validFlowField(String key, Object? value) {
  final field = flowFields[key];
  if (field == null) return false;
  switch (field['type']) {
    case 'id':
      return value is String &&
          RegExp(r'^[0-9a-f]{32}$').hasMatch(value) &&
          value != '00000000000000000000000000000000';
    case 'version':
      return value is String &&
          RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.+_-]{0,31}$').hasMatch(value);
    case 'enum':
      return value is String && (field['values'] as List).contains(value);
    default:
      return value is num &&
          value.isFinite &&
          value >= (field['min'] as num) &&
          value <= (field['max'] as num) &&
          (field['type'] != 'integer' || value == value.truncate());
  }
}
