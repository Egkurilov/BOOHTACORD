import 'package:boohtacord_desktop/src/features/conversation/delivery/status.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'checking is announced and explicit errors disable retry but allow discard',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryStatus(status: MessageSendStatus.checking),
          ),
        ),
      );
      expect(find.text('Проверяем доставку…'), findsOneWidget);
      var discarded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryStatus(
              status: MessageSendStatus.failed,
              retryBlocked: true,
              onRetry: () {},
              onDiscard: () {
                discarded = true;
              },
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Повторить отправку'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Убрать из очереди'));
      expect(discarded, isTrue);
    },
  );
}
