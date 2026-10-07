import 'generated.dart';

bool validFlowField(String key, Object? value) {
  final field = flowFields[key];
  if (field == null) return false;
  bool validLength(String value) =>
      value.length >= (field['minLength'] as int? ?? 0) &&
      value.length <= (field['maxLength'] as int? ?? 0x7fffffff);
  switch (field['type']) {
    case 'id':
      return value is String &&
          validLength(value) &&
          RegExp(field['pattern'] as String).hasMatch(value) &&
          value != '00000000000000000000000000000000';
    case 'version':
      return value is String &&
          validLength(value) &&
          RegExp(field['pattern'] as String).hasMatch(value);
    case 'enum':
      return value is String &&
          validLength(value) &&
          (field['values'] as List).contains(value);
    default:
      return value is num &&
          value.isFinite &&
          value >= (field['min'] as num) &&
          value <= (field['max'] as num) &&
          (field['type'] != 'integer' || value == value.truncate());
  }
}
