import 'package:boohtacord_desktop/src/widgets/voice_connection_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('announces reconnecting without claiming the room is connected', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VoiceConnectionBadge(reconnecting: true)),
      ),
    );

    expect(find.text('Восстанавливаем связь'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Восстанавливаем связь',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VoiceConnectionBadge(reconnecting: false)),
      ),
    );
    expect(find.text('Подключено'), findsOneWidget);
    expect(find.text('Восстанавливаем связь'), findsNothing);
    semantics.dispose();
  });
}
