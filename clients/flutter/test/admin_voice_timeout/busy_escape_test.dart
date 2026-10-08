import 'dart:async';

import 'package:boohtacord_desktop/src/features/admin/voice_timeout/model.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'launch_fixture.dart';

class PendingTimeoutRead extends TimeoutLaunchApi {
  final pendingTimeout = Completer<VoiceTimeoutState>();
  @override
  Future<VoiceTimeoutState> getVoiceTimeout(String id) {
    reads++;
    return pendingTimeout.future;
  }
}

void main() {
  testWidgets('Escape respects actual timeout busy PopScope', (tester) async {
    final api = PendingTimeoutRead();
    addTearDown(() {
      if (!api.pendingTimeout.isCompleted) {
        api.pendingTimeout.complete(
          const VoiceTimeoutState(false, null, null, 0, false),
        );
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdminVoiceTimeout(
                context,
                api: api,
                accountId: target,
                displayName: 'Synthetic member',
              ),
              child: const Text('Open timeout'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open timeout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Dialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Dialog), findsOneWidget);
    api.pendingTimeout.complete(
      const VoiceTimeoutState(false, null, null, 0, false),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(api.reads, 1);
    expect(tester.takeException(), isNull);
  });
}
