import 'dart:ui' show SemanticsRole, Tristate;

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

class _SequentialMediaApi extends TopologyTestApi {
  _SequentialMediaApi(this.firstPage);

  final List<AdminScreenSample> firstPage;
  int requests = 0;

  @override
  Future<List<AdminScreenSample>> listAdminScreenMetrics() async {
    requests++;
    return requests == 1 ? firstPage : const [];
  }
}

Future<AppState> _openMedia(WidgetTester tester, TopologyTestApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  final state = AppState(api)..topology = api.current;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AdminScreen(state: state)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('admin-section-tab-media')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('admin-section-tab-media')));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('admin section tabs match the web horizontal tab strip', (
    tester,
  ) async {
    final api = TopologyTestApi();
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    final tabKeys = [
      'guild',
      'members',
      'roles',
      'channels',
      'audit',
      'media',
      'readiness',
    ].map((name) => ValueKey('admin-section-tab-$name'));
    final tabTopPositions = tabKeys
        .map((key) => tester.getTopLeft(find.byKey(key)).dy)
        .toSet();
    expect(
      tabTopPositions,
      hasLength(1),
      reason: 'web keeps all administration tabs on one horizontally scrollable row',
    );

    final scroll = find.byKey(const ValueKey('admin-section-tabs-scroll'));
    expect(scroll, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(scroll).scrollDirection,
      Axis.horizontal,
    );
    await tester.drag(scroll, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-section-tab-media')).hitTestable(),
      findsNothing,
    );
    await tester.drag(scroll, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-section-tab-media')).hitTestable(),
      findsOneWidget,
      reason: 'the final tab remains reachable by horizontal scrolling',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-section-tab-readiness')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-section-tab-readiness')).hitTestable(),
      findsOneWidget,
      reason: 'the readiness tab remains reachable after the media tab',
    );
  });

  testWidgets('desktop admin tab divider fills its centered panel width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('admin-section-tabs-scroll')))
          .width,
      880,
      reason: 'the tab strip must fill the centered 880 px admin panel',
    );
    expect(
      find.byKey(const ValueKey('admin-section-tab-readiness')),
      findsOneWidget,
      reason: 'desktop must expose the readiness tab in the admin tab strip',
    );
  });

  testWidgets('media tab shows the web-equivalent empty state and polls', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final semantics = tester.ensureSemantics();
    final api = TopologyTestApi();
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('admin-section-tabs-semantics')),
          )
          .getSemanticsData()
          .role,
      SemanticsRole.tabBar,
    );
    final mediaTab = tester.getSemantics(
      find.byKey(const ValueKey('admin-section-tab-media')),
    );
    for (final (section, label) in [
      ('guild', 'Гильдия'),
      ('members', 'Участники'),
      ('roles', 'Роли'),
      ('channels', 'Каналы'),
      ('audit', 'Аудит'),
      ('media', 'Медиа'),
      ('readiness', 'Статус'),
    ]) {
      final semantics = tester.getSemantics(
        find.byKey(ValueKey('admin-section-tab-$section')),
      );
      expect(
        semantics.getSemanticsData().role,
        SemanticsRole.tab,
        reason: section,
      );
      expect(semantics.getSemanticsData().label, label, reason: section);
    }
    expect(
      mediaTab.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );

    expect(api.screenMetricsLoads, 1);
    expect(
      find.text(
        'Свежих показателей пока нет. Откройте демонстрацию у зрителя.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('без имён и идентификаторов участников'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(api.screenMetricsLoads, 2);

    await tester.tap(find.byKey(const ValueKey('admin-section-tab-channels')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(api.screenMetricsLoads, 2);
    semantics.dispose();
  });

  testWidgets('media tab renders anonymous receiver metrics responsively', (
    tester,
  ) async {
    final api = TopologyTestApi()
      ..screenMetrics = [
        AdminScreenSample(
          platform: 'android_native',
          direction: 'receiver',
          state: 'stalled',
          sampledAtUtc: DateTime.now().toUtc(),
          frameWidth: 540,
          frameHeight: 1170,
          decodedFps: 14.5,
          presentedFps: 12,
          bitrateKbps: 109.5,
          jitterMs: 4,
          packetsLost: 2,
          droppedFrames: 1,
          rttMs: 36,
        ),
      ];
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    expect(find.text('Android · приложение · приём'), findsOneWidget);
    expect(find.text('Состояние: Кадры остановились'), findsOneWidget);
    expect(find.text('540 × 1170'), findsOneWidget);
    expect(find.text('14.5 FPS'), findsOneWidget);
    expect(find.textContaining('Битрейт · 109.5 кбит/с'), findsNothing);
    expect(find.textContaining('RTT · 36 мс'), findsNothing);
    final advanced = find.text('Дополнительные измерения');
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    final bitrate = find.textContaining('Битрейт · 109.5 кбит/с');
    await tester.ensureVisible(bitrate);
    await tester.pumpAndSettle();
    expect(bitrate, findsOneWidget);
    expect(find.textContaining('RTT · 36 мс'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale media measurements stay stale after an empty refresh', (
    tester,
  ) async {
    final staleSample = AdminScreenSample(
      platform: 'android_native',
      direction: 'receiver',
      state: 'playing',
      sampledAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
      frameWidth: 540,
      frameHeight: 1170,
    );
    final api = _SequentialMediaApi([staleSample]);
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    expect(
      find.textContaining('Состояние: Данные устарели · свежих образцов: 0'),
      findsOneWidget,
    );
    expect(find.textContaining('Последнее измерение:'), findsOneWidget);
    expect(find.text('540 × 1170'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    expect(
      find.textContaining('Состояние: Данные устарели · свежих образцов: 0'),
      findsOneWidget,
    );
    expect(find.textContaining('Последнее измерение:'), findsOneWidget);
  });

  testWidgets('media loading failures are announced and can be retried', (
    tester,
  ) async {
    final api = TopologyTestApi()
      ..screenMetricsFailure = Exception('private server detail');
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    expect(find.text('Не удалось загрузить показатели.'), findsOneWidget);
    expect(find.textContaining('private server detail'), findsNothing);
    api.screenMetricsFailure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pumpAndSettle();

    expect(api.screenMetricsLoads, 2);
    expect(
      find.text(
        'Свежих показателей пока нет. Откройте демонстрацию у зрителя.',
      ),
      findsOneWidget,
    );
  });
}
