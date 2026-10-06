import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/telemetry/flow_contract/validate.dart';

void main() {
  test('shared privacy and boundary fixtures', () {
    final rows = jsonDecode(
      File('../../contracts/telemetry-flow-v1.fixtures.json')
          .readAsStringSync(),
    ) as List;
    for (final row in rows) {
      expect(
        validFlowField(row['key'], row['value']),
        row['valid'],
        reason: row['key'],
      );
    }
  });
}
