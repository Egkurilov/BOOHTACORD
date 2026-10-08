import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/model.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'guild settings loading is announced and name draft survives resize',
    (tester) async {
      final api = AccessibleAdminApi()
        ..pendingGuild = Completer<GuildSettings>();
      await mountAdmin(tester, api: api);
      final guild = find.byKey(const ValueKey('admin-section-tab-guild'));
      await tester.ensureVisible(guild);
      await tester.tap(guild);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.liveRegion == true &&
              widget.properties.label == 'Загружаем настройки гильдии…',
        ),
        findsOneWidget,
      );
      api.pendingGuild!.complete(const GuildSettings('Гильдия', 1, null));
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Название гильдии',
      );
      await tester.enterText(name, 'Несохранённый черновик');
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Несохранённый черновик',
      );
    },
  );
}
