import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';
import 'package:boohtacord_desktop/src/features/admin/voice_timeout/model.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'compact safe dialog exposes reason/duration, denial retry and focus',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          requests++;
          return requests == 1
              ? http.Response('{}', 403)
              : http.Response(
                  jsonEncode({
                    'active': false,
                    'revoked_leases': 0,
                    'revocation_pending': false,
                  }),
                  200,
                );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAdminVoiceTimeout(
                  context,
                  api: api,
                  accountId: '11111111-1111-4111-8111-111111111111',
                  displayName: 'Synthetic member',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Обновить состояние'));
      await tester.tap(find.text('Обновить состояние'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      await tester.ensureVisible(find.text('Длительность'));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24 часа').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<VoiceTimeoutReason>),
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<VoiceTimeoutReason>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Спам').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      final dialog = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(dialog.left, greaterThanOrEqualTo(16));
      expect(dialog.right, lessThanOrEqualTo(304));
      expect(tester.takeException(), isNull);
    },
  );
}
