import 'package:boohtacord_desktop/src/widgets/voice_connection_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;

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

  testWidgets('shows connection quality and measured ping', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceConnectionBadge(
            reconnecting: false,
            quality: ConnectionQuality.excellent,
            pingMs: 42,
          ),
        ),
      ),
    );

    expect(find.text('Подключено'), findsOneWidget);
    expect(find.text('42 мс'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Подключено',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion != true &&
            widget.properties.label ==
                'Качество соединения: Отличное · ping 42 мс',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows unavailable RTT without inventing a ping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceQualityIndicator(
            quality: ConnectionQuality.good,
            pingMs: null,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 мс'), findsNothing);
  });
}
