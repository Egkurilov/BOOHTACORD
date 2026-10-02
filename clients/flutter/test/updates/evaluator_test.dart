import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/updates/evaluator.dart';
import 'package:boohtacord_desktop/src/features/updates/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = jsonDecode(
    File('../../contracts/client-update-evaluator.fixtures.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final value in document['cases'] as List<dynamic>) {
    final fixture = value as Map<String, dynamic>;
    test(fixture['name'] as String, () {
      final local = fixture['local'] == null
          ? null
          : LocalUpdateIdentity.fromJson(fixture['local'] as Map<String, dynamic>);
      final policy = UpdatePolicy.fromJson(fixture['policy'] as Map<String, dynamic>);
      final environment = UpdateEnvironment.fromJson(
        fixture['environment'] as Map<String, dynamic>,
      );
      expect(evaluateUpdate(local, policy, environment).wireName, fixture['want']);
    });
  }
}
