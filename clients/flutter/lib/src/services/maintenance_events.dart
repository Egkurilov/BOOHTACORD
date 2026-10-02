import 'dart:convert';

bool? parseMaintenanceEvent(String line) {
  if (!line.startsWith('data: ')) return null;
  final value = jsonDecode(line.substring(6));
  if (value is! Map<String, dynamic> || value['active'] is! bool) {
    throw const FormatException('Invalid maintenance status event.');
  }
  return value['active'] as bool;
}
