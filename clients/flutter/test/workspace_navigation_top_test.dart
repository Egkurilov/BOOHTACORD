import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/top.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R14 keeps guild, search and tabs on the HTML grid', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    var searches = 0;
    var channels = 0;
    var directMessages = 0;
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: WorkspaceNavigationTop(
                memberCount: 6,
                channelsSelected: true,
                onSearch: () => searches++,
                onChannels: () => channels++,
                onDirectMessages: () => directMessages++,
                onClose: () => closes++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('navigation-guild-header'))),
      const Rect.fromLTWH(0, 0, 320, 64),
    );
    final guildHeaderSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('navigation-guild-header-surface')),
    );
    expect(
      (guildHeaderSurface.decoration as BoxDecoration).border!.bottom.color,
      GcColors.borderSubtle,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('navigation-search'))),
      const Rect.fromLTWH(12, 76, 296, 36),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('navigation-tabs'))),
      const Rect.fromLTWH(12, 124, 296, 40),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('navigation-tab-channels'))),
      const Rect.fromLTWH(16, 128, 142, 32),
    );
    expect(find.text('6 участников'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('navigation-guild-chevron')),
      findsOneWidget,
    );
    final searchButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('navigation-search')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      searchButton.style!.shape!.resolve(<WidgetState>{}),
      isA<RoundedRectangleBorder>(),
    );
    expect(
      (searchButton.style!.shape!.resolve(
        <WidgetState>{},
      ) as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(8),
    );
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('navigation-search')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .clipBehavior,
      Clip.antiAlias,
    );
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.tap(find.text('Каналы'));
    await tester.tap(find.text('Личные'));
    await tester.tap(find.byTooltip('Закрыть навигацию'));
    expect((searches, channels, directMessages, closes), (1, 1, 1, 1));
  });

  testWidgets('wide sidebar uses the desktop search offset', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 280,
              child: WorkspaceNavigationTop(
                memberCount: 6,
                channelsSelected: false,
                onSearch: () {},
                onChannels: () {},
                onDirectMessages: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('navigation-search'))),
      const Rect.fromLTWH(12, 80, 256, 36),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('navigation-tabs'))),
      const Rect.fromLTWH(12, 128, 256, 40),
    );
    expect(find.byTooltip('Закрыть навигацию'), findsNothing);
    expect(
      find.byKey(const ValueKey('navigation-guild-chevron')),
      findsOneWidget,
    );
  });
}
