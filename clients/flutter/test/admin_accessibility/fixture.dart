import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/theme.dart';

import 'api_fixture.dart';
export 'api_fixture.dart';

Future<void> revealAdminControl(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

Future<AppState> mountAdmin(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets insets = EdgeInsets.zero,
  bool reducedMotion = false,
  AccessibleAdminApi? api,
  TargetPlatform? platform,
  VisualDensity? density,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final backend = api ?? AccessibleAdminApi();
  final app = AppState(backend)..topology = backend.current;
  addTearDown(app.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: guildTheme().copyWith(platform: platform, visualDensity: density),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: padding,
          viewPadding: padding,
          viewInsets: insets,
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(body: AdminScreen(state: app)),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}
