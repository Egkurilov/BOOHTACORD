import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/widgets/desktop_window_chrome.dart';

void main() {
  testWidgets('desktop chrome updates the full accessible guild name', (
    tester,
  ) async {
    final name = List.filled(80, 'Ж').join();
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.macOS,
          title: name,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text(name), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopWindowChrome(
          platform: TargetPlatform.macOS,
          title: 'Новое имя',
          child: SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text('Новое имя'), findsOneWidget);
    expect(find.text(name), findsNothing);
  });
}
