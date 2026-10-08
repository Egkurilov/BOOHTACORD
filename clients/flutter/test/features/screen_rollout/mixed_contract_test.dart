import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/descriptor.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/policy.dart';

void main() {
  final fixtures = jsonDecode(File('../../contracts/screen-share-profile-v1.fixtures.json').readAsStringSync());
  const disabled = bool.fromEnvironment('QA_SCREEN_DISABLED');
  test('native typed parser probes the same mixed-client fixtures as Web', () {
    expect(const ScreenMediaRollout().descriptor, !disabled);
    expect(const ScreenMediaRollout().jpegPreview, !disabled);
    for (final item in fixtures['descriptorCases']) {
      final raw = <String, dynamic>{...fixtures['validDescriptor'], ...item['overrides']};
      final parsed = parseScreenShareDescriptor(jsonEncode(raw));
      expect(parsed != null, !disabled && item['accepted'] == true, reason: item['name']);
    }
    expect(parseScreenShareDescriptor(null), null);
    expect(parseScreenShareDescriptor('{}'), null);
  });
}
