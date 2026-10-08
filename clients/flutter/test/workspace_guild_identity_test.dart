import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/top.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guild logo semantics follows the configured long guild name', (
    tester,
  ) async {
    final name = List.filled(80, 'Ж').join();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceNavigationTop(
              guildName: name,
              memberCount: 6,
              channelsSelected: true,
              onSearch: () {},
              onChannels: () {},
              onDirectMessages: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(name), findsOneWidget);
    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('Логотип') ?? false),
    );
    expect(logo, findsOneWidget);
    expect(
      tester.widget<Semantics>(logo).properties.label,
      'Логотип гильдии $name',
    );
    expect(tester.takeException(), isNull);
  });
}
