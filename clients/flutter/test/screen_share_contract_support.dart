import 'dart:convert';
import 'dart:io';

Map<String, dynamic> readScreenShareContract(String name) => jsonDecode(
      File('../../contracts/screen-share-profile-v1.$name.json')
          .readAsStringSync(),
    );

bool acceptsScreenShareDescriptor(
  Map<String, dynamic> value,
  Map<String, dynamic> schema,
) {
  final properties = schema['properties'] as Map<String, dynamic>;
  final required = (schema['required'] as List).every(value.containsKey);
  final knownKeys = value.keys.every(properties.containsKey);
  bool allowed(String key) =>
      properties[key]['enum']?.contains(value[key]) ?? true;
  final scope = value['scope'] as Map<String, dynamic>? ?? {};
  final scopeSchema = properties['scope'] as Map<String, dynamic>;
  final scopeProperties = scopeSchema['properties'] as Map<String, dynamic>;
  final validScope = scope.keys.every(scopeProperties.containsKey) &&
      (scopeSchema['required'] as List).every((key) {
        final item = scope[key];
        return (item is String && item.isNotEmpty) ||
            (item is int && item >= 0);
      });
  final layers =
      value['effective_profile']?['encoding']?['layers'] as List? ?? [];
  final profile = value['requested_profile_id'] as String? ?? '';
  final mode = value['mode'];
  final profileMatchesMode = profile.startsWith('text-')
      ? mode == 'text'
      : !profile.startsWith('motion-') || mode == 'motion';
  final reasonCodes = properties['reason_codes']['items']['enum'];
  final maxLayers = properties['effective_profile']['properties']['encoding']
      ['properties']['layers']['maxItems'];
  return required &&
      knownKeys &&
      value['schema_version'] == properties['schema_version']['const'] &&
      allowed('mode') &&
      allowed('publisher_state') &&
      allowed('viewer_state') &&
      allowed('layer_topology') &&
      allowed('requested_profile_id') &&
      validScope &&
      (value['reason_codes'] as List)
          .every((code) => reasonCodes.contains(code)) &&
      profileMatchesMode &&
      value['profile_revision'] >= 0 &&
      layers.isNotEmpty &&
      layers.length <= maxLayers;
}
