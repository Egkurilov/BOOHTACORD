import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show SemanticsRole, Tristate;
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/authenticated_avatar.dart';
import 'package:boohtacord_desktop/src/widgets/audio_device_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    show MediaDevice, Room, RemoteParticipant;
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUp(ComposerDraftMemory.clear);

  testWidgets('macOS shows an unsubscribed published screen and opens it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final room = _PublishedScreenRoom();
    // ignore: invalid_use_of_internal_member
    final created = await RemoteParticipant.createFromInfo(
      room: room,
      info: lk.ParticipantInfo(
        sid: 'remote-sid',
        identity: 'remote-screen',
        name: 'Streamer',
        tracks: [
          lk.TrackInfo(
            sid: 'screen-sid',
            type: lk.TrackType.VIDEO,
            source: lk.TrackSource.SCREEN_SHARE,
            muted: false,
          ),
        ],
      ),
    );
    room.members['remote-screen'] = created.participant;
    final state = _PublishedScreenState(room);
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(created.participant.videoTrackPublications.single.track, isNull);
    expect(
      find.widgetWithText(OutlinedButton, 'Смотреть экран'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Смотреть экран'));
    await tester.pump();
    expect(state.selectedScreen, 'remote-screen');
    expect(find.text('Подключаемся к демонстрации…'), findsOneWidget);
    expect(find.textContaining('Демонстрация завершена.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    await tester.runAsync(() => room.dispose());
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'mobile edge swipes open and close both workspace panels (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final state = AppState(_PortraitApi());
        await state.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.dragFrom(const Offset(0, 220), const Offset(140, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceScreen), findsOneWidget);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        await tester.dragFrom(const Offset(180, 220), const Offset(-120, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        await tester.dragFrom(const Offset(389, 220), const Offset(-140, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть участников'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceScreen), findsOneWidget);
        expect(find.byTooltip('Закрыть участников'), findsNothing);

        await tester.dragFrom(const Offset(220, 220), const Offset(120, 0));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть участников'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'mobile message swipes reply and pull down refreshes history (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final api = _PortraitApi(
          withHistory: true,
          historyCount: 2,
          includeDirectMessage: true,
        );
        final state = AppState(api);
        await state.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: state,
              builder: (_, _) => WorkspaceScreen(state: state),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textRow = find.text('Последнее сообщение');
        await tester.dragFrom(tester.getCenter(textRow), const Offset(95, 0));
        await tester.pumpAndSettle();
        expect(find.text('Ответ для @Участник'), findsOneWidget);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        final beforeTextRefresh = api.messagePageCalls;
        await tester.drag(
          find.byKey(const ValueKey('text-channel-messages')),
          const Offset(0, 280),
        );
        await tester.pumpAndSettle();
        expect(api.messagePageCalls, greaterThan(beforeTextRefresh));

        await state.openDirectConversation(state.directMessages.single);
        await tester.pumpAndSettle();
        await tester.dragFrom(
          tester.getCenter(find.text('Исходное личное сообщение')),
          const Offset(95, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ответ для Собеседник'), findsOneWidget);
        final beforeDirectRefresh = api.directMessagePageCalls;
        await tester.drag(
          find.text('Исходное личное сообщение'),
          const Offset(0, 280),
        );
        await tester.pumpAndSettle();
        expect(api.directMessagePageCalls, greaterThan(beforeDirectRefresh));

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('mobile PTT dock transmits only while mic is held', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..voiceChannel = _PortraitApi.voiceChannel
      ..selectedChannel = _PortraitApi.voiceChannel
      ..voicePhase = VoicePhase.connected
      ..audioActivationMode = AudioActivationMode.ptt;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ptt = find.byTooltip('Удерживайте, чтобы говорить');
    expect(ptt, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(ptt));
    await tester.pump();
    expect(state.pushToTalkPressed, isTrue);
    await gesture.up();
    await tester.pump();
    expect(state.pushToTalkPressed, isFalse);

    final cancelledGesture = await tester.startGesture(
      tester.getCenter(ptt),
      pointer: 7,
    );
    await tester.pump();
    expect(state.pushToTalkPressed, isTrue);
    await cancelledGesture.cancel();
    await tester.pump();
    expect(state.pushToTalkPressed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('restores a text-channel draft after switching channels', (
    tester,
  ) async {
    final secondChannel = GuildChannel(
      id: 'channel-2',
      name: 'второй',
      kind: ChannelKind.text,
      admissionClosed: false,
      unreadCount: 0,
      mentionCount: 0,
    );
    final state = AppState(_PortraitApi(extraVoiceChannels: [secondChannel]));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Написать сообщение…',
    );
    await tester.enterText(composer, 'неотправленный текст');
    await tester.pump();
    await state.selectChannel(secondChannel);
    await tester.pumpAndSettle();
    expect(state.selectedChannel?.id, 'channel-2');
    expect(find.text('второй'), findsOneWidget);
    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);

    await state.selectChannel(_PortraitApi.channel);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'неотправленный текст',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('opens native audio settings and processing controls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final scan = Completer<List<MediaDevice>>();
    final refreshScan = Completer<List<MediaDevice>>();
    var scanCount = 0;
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () {
        scanCount++;
        if (scanCount == 1) return scan.future;
        return refreshScan.future;
      },
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Настройки аудио'), findsOneWidget);
    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final audioScrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Микрофон'),
      160,
      scrollable: audioScrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Динамик'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('Микрофон'), findsOneWidget);
    expect(find.text('Динамик'), findsOneWidget);
    expect(find.text('Ищем устройства…'), findsNWidgets(2));
    expect(find.text('Микрофоны не найдены'), findsNothing);
    scan.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.text('Микрофоны не найдены'),
      160,
      scrollable: audioScrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Динамики не найдены'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('Ищем устройства…'), findsNothing);
    expect(find.text('Микрофоны не найдены'), findsOneWidget);
    expect(find.text('Динамики не найдены'), findsOneWidget);
    expect(state.audioDevicesLoading, isFalse);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere(
            (button) => button.tooltip == 'Обновить список устройств',
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Обновить список устройств'));
    await tester.pump();
    expect(scanCount, 2);
    expect(state.audioDevicesLoading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere(
            (button) => button.tooltip == 'Обновить список устройств',
          )
          .onPressed,
      isNull,
    );
    refreshScan.completeError(StateError('scan failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.audioDeviceScanFailed, isTrue);
    expect(find.text('Список недоступен'), findsNWidgets(2));
    expect(find.text('Микрофоны не найдены'), findsNothing);
    await tester.drag(audioList, const Offset(0, 640));
    await tester.pumpAndSettle();
    expect(find.text('Активация микрофона'), findsOneWidget);
    expect(find.text('Назначить PTT-клавишу'), findsOneWidget);
    expect(find.text('Подавление эха'), findsOneWidget);
    expect(find.textContaining('Нативный SDK не сообщает'), findsOneWidget);

    await tester.tap(find.text('Назначить PTT-клавишу'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(state.pushToTalkKeyId, LogicalKeyboardKey.keyA.keyId);
    expect(find.textContaining('Клавиша PTT'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<AudioActivationMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push-to-talk').last);
    await tester.pump();
    expect(state.audioActivationMode, AudioActivationMode.ptt);

    expect(find.byTooltip('Назад'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(state.workspacePanel, WorkspacePanel.none);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android audio settings configure PTT without a key binding', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final scrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Активация микрофона'),
      180,
      scrollable: scrollable,
    );

    expect(find.text('Назначить PTT-клавишу'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<AudioActivationMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push-to-talk').last);
    await tester.pumpAndSettle();

    expect(state.audioActivationMode, AudioActivationMode.ptt);
    expect(state.audioActivationError, isNull);
    expect(find.text('Назначить PTT-клавишу'), findsNothing);
    expect(find.textContaining('Удерживайте кнопку микрофона'), findsOneWidget);
    expect(
      find.textContaining('Удерживайте назначенную клавишу'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('audio settings test the devices shown in their selectors', (
    tester,
  ) async {
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [
        MediaDevice('input-1', 'USB microphone', 'audioinput', null),
        MediaDevice('output-1', 'USB speakers', 'audiooutput', null),
      ],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final audioScrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('audio-device-check')),
      160,
      scrollable: audioScrollable,
    );
    final check = tester.widget<AudioDeviceCheck>(
      find.byKey(const ValueKey('audio-device-check')),
    );
    expect(check.inputDeviceId, 'input-1');
    expect(check.inputDeviceLabel, 'USB microphone');
    expect(check.outputDeviceId, 'output-1');
    expect(check.outputDeviceLabel, 'USB speakers');
    expect(find.text('Проверить микрофон'), findsOneWidget);
    expect(find.text('Проверить динамик'), findsOneWidget);
    expect(
      find.text(
        'Проверка локальная: она не подтверждает слышимость у другого участника.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows named audio devices when the SDK has no default entry', (
    tester,
  ) async {
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [
        MediaDevice('usb-mic', 'USB Microphone', 'audioinput', null),
        MediaDevice('bt-output', 'Bluetooth headphones', 'audiooutput', null),
      ],
    );
    await state.initialize();
    await state.refreshAudioDevices();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    final audioScrollable = find.descendant(
      of: audioList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('USB Microphone'),
      160,
      scrollable: audioScrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Bluetooth headphones'),
      160,
      scrollable: audioScrollable,
    );
    expect(find.text('USB Microphone'), findsOneWidget);
    expect(find.text('Bluetooth headphones'), findsOneWidget);
    expect(find.textContaining('Системный выбор'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('announces when the selected audio device disconnects', (
    tester,
  ) async {
    const warning =
        'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.';
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [
        MediaDevice('mic-new', 'Built-in microphone', 'audioinput', null),
        MediaDevice('speaker', 'Speakers', 'audiooutput', null),
      ],
    );
    await state.initialize();
    state.audioDeviceWarning = warning;
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final audioList = find.byKey(const ValueKey('audio-settings-list'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('audio-device-warning')),
      160,
      scrollable: find.descendant(
        of: audioList,
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text(warning), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.key == const ValueKey('audio-device-warning') &&
            widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile panel matches web toolbar without a duplicate heading', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.profile);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.byTooltip('Открыть навигацию'), findsNothing);
    expect(find.byTooltip('Открыть участников'), findsNothing);
    expect(find.byTooltip('Назад'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile panel keeps Android Back and navigation actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.profile);

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.byTooltip('Назад'), findsOneWidget);
    expect(find.byTooltip('Открыть навигацию'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('Назад')).left, lessThan(24));
    expect(
      tester.getRect(find.byTooltip('Открыть навигацию')).left,
      greaterThan(330),
    );
    expect(find.byTooltip('Открыть участников'), findsNothing);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('compact workspace header actions match web 44 px targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    for (final tooltip in ['Открыть навигацию', 'Открыть участников']) {
      expect(tester.getSize(find.byTooltip(tooltip)), const Size(44, 44));
    }

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile panel restores the opening keyboard focus on close', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    final openingFocus = FocusNode(debugLabel: 'workspace-panel-opener');
    addTearDown(openingFocus.dispose);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: openingFocus,
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) => WorkspaceScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    openingFocus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(openingFocus));

    state.toggleWorkspacePanel(WorkspacePanel.profile);
    await tester.pumpAndSettle();
    final profileFocus = tester
        .widget<Focus>(find.byKey(const ValueKey('profile-screen-title-focus')))
        .focusNode!;
    profileFocus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(profileFocus));

    state.toggleWorkspacePanel(WorkspacePanel.none);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(openingFocus));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('offers to reopen a local screen from the participant view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.screenSharePhase = ScreenSharePhase.sharing;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Все в сборе'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Смотреть экран'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Участник показывает экран'), findsOneWidget);
    final grid = tester.widget<GridView>(
      find.byKey(const ValueKey('voice-participant-grid')),
    );
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    final selfCard = find.byKey(const ValueKey('voice-participant-card:self'));
    expect(tester.getSize(selfCard).height, 208);
    expect(tester.getSize(selfCard).width, greaterThanOrEqualTo(160));
    final selfCardRect = tester.getRect(selfCard);
    final screenShareBadgeRect = tester.getRect(
      find.bySemanticsLabel('Участник показывает экран'),
    );
    expect(selfCardRect.contains(screenShareBadgeRect.topLeft), isTrue);
    expect(selfCardRect.contains(screenShareBadgeRect.bottomRight), isTrue);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    final desktopGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('voice-participant-grid')),
    );
    expect(
      (desktopGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      ((tester
                      .getSize(
                        find.byKey(const ValueKey('voice-participant-grid')),
                      )
                      .width +
                  12) /
              172)
          .floor(),
    );
    expect(tester.getSize(selfCard).height, 208);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('deafened participant status stays centered on one line', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.deafened = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final status = find.text('Звук и микрофон выключены');
    final statusText = tester.widget<Text>(status);
    final card = find.byKey(const ValueKey('voice-participant-card:self'));
    expect(statusText.textAlign, TextAlign.center);
    expect(statusText.maxLines, 1);
    expect(statusText.overflow, TextOverflow.ellipsis);
    expect(
      tester.getRect(status).center.dx,
      closeTo(tester.getRect(card).center.dx, 0.1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows a retryable microphone-unavailable listener state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.listener;
    state.microphoneMuted = true;
    state.microphoneUnavailable = true;
    state.audioActivationMode = AudioActivationMode.vad;

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Микрофон недоступен'), findsNWidgets(2));
    expect(find.textContaining('подключены как слушатель'), findsOneWidget);
    expect(find.byTooltip('Повторить включение микрофона'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Android PTT listener guidance does not request a key', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.voiceChannel
      ..voiceChannel = _PortraitApi.voiceChannel
      ..voicePhase = VoicePhase.listener
      ..microphoneMuted = true
      ..microphoneUnavailable = true
      ..audioActivationMode = AudioActivationMode.ptt;

    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Удерживайте кнопку микрофона'), findsOneWidget);
    expect(find.textContaining('назначенную PTT-клавишу'), findsNothing);
    expect(find.text('Назначить PTT-клавишу'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('announces prejoin roster loading and errors as live status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    state
      ..voiceRosters = null
      ..voiceRosterError = null
      ..notifyListeners();
    await tester.pump();
    final loadingStatus = find.text('Проверяем, кто сейчас в комнате…');
    expect(loadingStatus, findsOneWidget);
    expect(find.text('Голосовой канал · проверяем состав'), findsOneWidget);
    expect(
      tester.getSemantics(loadingStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    state
      ..voiceRosterError = 'Нет связи со списком голосовых каналов.'
      ..notifyListeners();
    await tester.pump();
    final errorStatus = find.text(
      'Не удалось обновить состав комнаты. Повторяем попытку.',
    );
    expect(errorStatus, findsOneWidget);
    expect(find.text('Голосовой канал · состав недоступен'), findsOneWidget);
    expect(
      tester.getSemantics(errorStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    state
      ..voiceRosterError = null
      ..voiceRosters = const [
        VoiceRoomRoster(channelId: 'voice-1', participants: []),
      ]
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Голосовой канал · пока пусто'), findsOneWidget);

    state
      ..voiceRosters = const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Собеседник',
              screenSharing: false,
              microphoneMuted: true,
            ),
          ],
        ),
      ]
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Голосовой канал · сейчас: 1'), findsOneWidget);

    state
      ..selectedChannel = const GuildChannel(
        id: 'voice-1',
        name: 'голосовой',
        kind: ChannelKind.voice,
        admissionClosed: true,
      )
      ..voiceRosters = null
      ..voiceRosterError = 'Нет связи со списком голосовых каналов.'
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Голосовой канал · состав недоступен'), findsOneWidget);
    final closedNotice = find.text(
      'Вход в этот канал закрыт администратором. Отзыв media-доступа ещё подтверждается.',
    );
    expect(closedNotice, findsOneWidget);
    expect(
      tester.getSemantics(closedNotice).getSemanticsData().role,
      SemanticsRole.status,
    );
    expect(
      find.text(
        'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.',
      ),
      findsNothing,
    );
    expect(find.text('Подключиться без микрофона'), findsNothing);

    state
      ..voiceChannel = state.selectedChannel
      ..voicePhase = VoicePhase.connected
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Выйти из голосового канала'), findsOneWidget);
    expect(find.text('Все в сборе'), findsNothing);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('exposes text conversation errors with alert semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.channel
      ..error = 'Не удалось загрузить историю.';

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final error = find.text('Не удалось загрузить историю.');
    expect(error, findsOneWidget);
    final alert = find.ancestor(
      of: error,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.role == SemanticsRole.alert,
      ),
    );
    expect(
      tester.getSemantics(alert).getSemanticsData().role,
      SemanticsRole.alert,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('exposes Android conversation errors as polite live regions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final semantics = tester.ensureSemantics();
    final state = AppState(_PortraitApi());
    await state.initialize();
    state
      ..selectedChannel = _PortraitApi.channel
      ..error = 'Не удалось загрузить историю.';

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final error = find.text('Не удалось загрузить историю.');
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    expect(
      find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == SemanticsRole.alert,
        ),
      ),
      findsOneWidget,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows the voice roster before joining the room', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final api = _PortraitApi(
      voiceRosters: const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Мика',
              screenSharing: true,
              microphoneMuted: true,
            ),
          ],
        ),
      ],
    );
    final state = AppState(api);
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Вы не подключены'), findsOneWidget);
    expect(
      find.text(
        'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.',
      ),
      findsOneWidget,
    );
    expect(find.text('Сейчас в канале: 1'), findsOneWidget);
    expect(find.text('Мика'), findsNWidgets(2));
    expect(find.byTooltip('Показывает экран'), findsNWidgets(2));
    expect(find.text('Идёт трансляция'), findsOneWidget);
    final avatars = tester
        .widgetList<AuthenticatedAvatar>(find.byType(AuthenticatedAvatar))
        .where((avatar) => avatar.name == 'Мика');
    expect(avatars, hasLength(2));
    expect(avatars.map((avatar) => avatar.radius), everyElement(12));
    expect(
      avatars.map((avatar) => avatar.backgroundColor),
      everyElement(GcColors.avatarBlue),
    );
    expect(
      tester.widgetList<Icon>(find.byIcon(Icons.desktop_windows_outlined)),
      hasLength(2),
    );
    expect(state.voicePhase, VoicePhase.idle);
    expect(state.voiceChannel, isNull);

    state.voicePhase = VoicePhase.joining;
    state.notifyListeners();
    await tester.pump();

    expect(find.text('Подключаемся к голосовой комнате'), findsOneWidget);
    final joiningTitle = find.ancestor(
      of: find.text('Подключаемся к голосовой комнате'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(joiningTitle, findsOneWidget);
    expect(
      tester.widget<Semantics>(joiningTitle).properties.label,
      'Подключаемся к голосовой комнате',
    );
    expect(find.text('Соединение устанавливается.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Подключаемся…'),
          )
          .onPressed,
      isNull,
    );

    state.error = 'Не удалось подключиться к голосовому каналу';
    state.notifyListeners();
    await tester.pump();
    expect(find.text(state.error!), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(state.error!),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('text workspace geometry matches Design V2 breakpoints', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(withHistory: true, includeDirectMessage: true),
    );
    await state.initialize();
    state.messages = [
      ChatMessage(
        id: 'design-v2-first',
        channelId: _PortraitApi.channel.id,
        authorId: 'account-1',
        body: 'Первое сообщение Design V2',
        createdAt: DateTime.utc(2026, 9, 25, 12),
        deleted: false,
        revision: 1,
      ),
      ChatMessage(
        id: 'design-v2-second',
        channelId: _PortraitApi.channel.id,
        authorId: 'account-2',
        body: 'Второе сообщение Design V2',
        createdAt: DateTime.utc(2026, 9, 25, 12, 1),
        deleted: false,
        revision: 1,
      ),
    ];
    state.selectedChannel = _PortraitApi.channel;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final viewport in [
      (size: const Size(320, 640), mainLeft: 0.0, mainWidth: 320.0),
      (size: const Size(360, 800), mainLeft: 0.0, mainWidth: 360.0),
      (size: const Size(390, 844), mainLeft: 0.0, mainWidth: 390.0),
      (size: const Size(1024, 768), mainLeft: 280.0, mainWidth: 744.0),
      (size: const Size(1280, 800), mainLeft: 280.0, mainWidth: 752.0),
      (size: const Size(1440, 900), mainLeft: 280.0, mainWidth: 912.0),
    ]) {
      tester.view.physicalSize = viewport.size;
      await tester.pumpAndSettle();

      final compact = viewport.size.width < 1024;
      final header = tester.getRect(
        find.byKey(const ValueKey('workspace-header')),
      );
      expect(header.height, compact ? 56 : 64);
      final main = tester.getRect(
        find.byKey(const ValueKey('workspace-main-surface')),
      );
      expect(main.left, viewport.mainLeft);
      expect(main.width, viewport.mainWidth);
      if (!compact) {
        expect(
          tester
              .getRect(
                find.byKey(const ValueKey('workspace-channel-row:channel-1')),
              )
              .height,
          36,
        );
      }

      final messages = tester.widget<ListView>(
        find.byKey(const ValueKey('text-channel-messages')),
      );
      expect(
        messages.padding,
        compact
            ? const EdgeInsets.fromLTRB(12, 16, 12, 8)
            : EdgeInsets.fromLTRB(
                viewport.size.width < 1280 ? 20 : 24,
                20,
                viewport.size.width < 1280 ? 20 : 24,
                12,
              ),
      );
      final messageAvatars = tester.widgetList<AuthenticatedAvatar>(
        find.descendant(
          of: find.byKey(const ValueKey('text-channel-messages')),
          matching: find.byType(AuthenticatedAvatar),
        ),
      );
      expect(messageAvatars, hasLength(2));
      expect(
        messageAvatars.map((avatar) => avatar.radius),
        everyElement(compact ? 16 : 18),
      );
      final firstMessageRow = find.ancestor(
        of: find.text('Первое сообщение Design V2'),
        matching: find.byWidgetPredicate(
          (widget) => widget is KeyedSubtree && widget.key is GlobalKey,
        ),
      );
      final secondMessageRow = find.ancestor(
        of: find.text('Второе сообщение Design V2'),
        matching: find.byWidgetPredicate(
          (widget) => widget is KeyedSubtree && widget.key is GlobalKey,
        ),
      );
      expect(
        tester.getTopLeft(secondMessageRow.first).dy -
            tester.getBottomLeft(firstMessageRow.first).dy,
        compact ? 20 : 24,
      );
      final composer = tester.widget<Container>(
        find.byKey(const ValueKey('text-composer-wrap')),
      );
      final composerHorizontal = compact
          ? 8.0
          : viewport.size.width < 1280
          ? 20.0
          : 24.0;
      expect(
        composer.padding,
        compact
            ? const EdgeInsets.all(8)
            : EdgeInsets.fromLTRB(
                composerHorizontal,
                8,
                composerHorizontal,
                16,
              ),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('text-composer-wrap'))).height,
        compact ? 70 : 98,
      );
      expect(
        find.text('До 25 МБ на файл'),
        compact ? findsNothing : findsOneWidget,
      );
    }

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('mobile-sidebar'))).width,
        width < 360 ? width - 40 : 320,
      );
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('workspace-channel-row:channel-1')),
            )
            .height,
        44,
      );
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Закрыть навигацию'));
    await tester.pumpAndSettle();

    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpAndSettle();
    expect(state.selectedDirectMessage, isNotNull);
    expect(state.directMessageHistory, isNotEmpty);
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('direct-message-messages')),
          )
          .padding,
      const EdgeInsets.fromLTRB(12, 16, 12, 8),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('direct-message-composer-wrap')),
          )
          .padding,
      const EdgeInsets.all(8),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
          .height,
      70,
    );
    expect(find.text('До 25 МБ на файл'), findsNothing);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('direct-message-messages')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 20, 24, 12),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('direct-message-composer-wrap')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 8, 24, 16),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
          .height,
      98,
    );
    expect(find.text('До 25 МБ на файл'), findsOneWidget);

    const longDisplayName =
        'ОченьДлинноеИмяПользователяБезПробеловДляПроверкиЭллипсиса';
    await state.openDirectConversation(
      const DirectConversation(
        id: 'dm-1',
        participantId: 'account-2',
        displayName: longDisplayName,
        unreadCount: 0,
      ),
    );
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final longTitle = tester.widget<Text>(find.text(longDisplayName));
    expect(longTitle.maxLines, 1);
    expect(longTitle.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('voice prejoin matches web desktop spacing and card padding', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const ValueKey('voice-prejoin-card'));
    expect(
      tester.widget<Container>(cardFinder).padding,
      const EdgeInsets.all(44),
    );
    final scrollFinder = find
        .ancestor(of: cardFinder, matching: find.byType(SingleChildScrollView))
        .first;
    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).padding,
      const EdgeInsets.all(72),
    );
    final icon = tester.widget<Container>(
      find.byKey(const ValueKey('voice-prejoin-icon')),
    );
    final iconDecoration = icon.decoration! as BoxDecoration;
    expect(iconDecoration.color, GcColors.raised);
    expect(
      iconDecoration.border,
      Border.fromBorderSide(const BorderSide(color: GcColors.control)),
    );
    expect(
      tester.widget<Text>(find.text('Вы не подключены')).style?.fontSize,
      24,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('voice prejoin matches mobile padding without header overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const ValueKey('voice-prejoin-card'));
    expect(
      tester.widget<Container>(cardFinder).padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
    final scrollFinder = find
        .ancestor(of: cardFinder, matching: find.byType(SingleChildScrollView))
        .first;
    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).padding,
      const EdgeInsets.all(16),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('voice dock announces reconnect and deafen transition states', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('В голосовом канале'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label ==
                'В голосовом канале · ${state.voiceChannel!.name}',
      ),
      findsOneWidget,
    );
    final qualitySemantics = tester
        .widgetList<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    'Качество соединения: Нет данных · ping —',
          ),
        )
        .toList();
    expect(qualitySemantics, isNotEmpty);
    expect(
      qualitySemantics.every((item) => item.properties.liveRegion != true),
      isTrue,
    );
    expect(
      find.text('Вы можете открыть другой канал: голос останется активным.'),
      findsNothing,
    );
    final microphoneButton = tester.getSemantics(
      find.bySemanticsLabel('Выключить микрофон').first,
    );
    expect(microphoneButton.label, 'Выключить микрофон');
    expect(microphoneButton.flagsCollection.isToggled, Tristate.isTrue);
    final deafenSemantics = tester.getSemantics(
      find.byTooltip('Выключить удалённый звук'),
    );
    expect(deafenSemantics.label, 'Выключить удалённый звук');
    expect(deafenSemantics.flagsCollection.isToggled, Tristate.isFalse);
    final enabledSoundButton = find.byTooltip(
      'Выключить сигнал новых трансляций',
    );
    expect(enabledSoundButton, findsOneWidget);
    final enabledSoundSemantics = tester.getSemantics(enabledSoundButton);
    expect(enabledSoundSemantics.label, 'Звук начала трансляций включён');
    expect(enabledSoundSemantics.flagsCollection.isToggled, Tristate.isTrue);
    expect(
      enabledSoundSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    state.voiceStreamStartNotice = true;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('В канале началась демонстрация экрана'), findsOneWidget);
    await tester.tap(enabledSoundButton);
    await tester.pump();
    expect(state.voiceStreamSoundEnabled, isFalse);
    final disabledSoundButton = find.byTooltip(
      'Включить сигнал новых трансляций',
    );
    expect(disabledSoundButton, findsOneWidget);
    final disabledSoundSemantics = tester.getSemantics(disabledSoundButton);
    expect(disabledSoundSemantics.label, 'Звук начала трансляций выключен');
    expect(disabledSoundSemantics.flagsCollection.isToggled, Tristate.isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'voice-screen-start-sound:v1',
      ),
      isFalse,
    );
    expect(find.byTooltip('Начать демонстрацию экрана'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Начать демонстрацию экрана').first);
    await tester.pump();
    expect(find.text('Демонстрация экрана'), findsOneWidget);
    expect(find.text('Качество трансляции'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    state.voicePhase = VoicePhase.joining;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Подключаемся'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
    expect(find.text('Подключаемся к голосовому каналу'), findsOneWidget);
    expect(find.text('Соединяемся с голосовой комнатой.'), findsNothing);
    final dockShareAction = find.descendant(
      of: find.byTooltip('Начать демонстрацию экрана').first,
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(dockShareAction).onTap, isNull);

    state.deafenChanging = true;
    state.notifyListeners();
    await tester.pump();
    final deafenButton = find.descendant(
      of: find.byTooltip('Выключить удалённый звук'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(deafenButton).onTap, isNull);

    state.deafenChanging = false;
    state.voicePhase = VoicePhase.connected;
    state.deafened = true;
    state.notifyListeners();
    await tester.pump();
    final deafenedButton = tester.getSemantics(
      find.byTooltip('Включить удалённый звук'),
    );
    expect(deafenedButton.label, 'Включить удалённый звук');
    expect(deafenedButton.flagsCollection.isToggled, Tristate.isTrue);
    expect(
      find.text(
        'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
      ),
      findsNothing,
    );

    state.voicePhase = VoicePhase.reconnecting;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Восстанавливаем голосовое соединение'), findsOneWidget);
    expect(find.text('Ручной выход отменит ожидание.'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('Восстанавливаем голосовое соединение'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.',
      ),
      findsNothing,
    );

    state.voicePhase = VoicePhase.leaving;
    state.notifyListeners();
    await tester.pump();
    expect(find.text('Завершаем голосовое подключение'), findsOneWidget);
    expect(find.text('Ожидаем завершения голосовой сессии.'), findsNothing);
    expect(find.byTooltip('Выходим…'), findsOneWidget);
    final leaveButton = find.descendant(
      of: find.byTooltip('Выходим…'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(leaveButton).onTap, isNull);

    state.error = 'Голосовая сессия завершилась с ошибкой';
    state.notifyListeners();
    await tester.pump();
    expect(find.text(state.error!), findsOneWidget);
    final alert = find.ancestor(
      of: find.text(state.error!),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.role == SemanticsRole.alert,
      ),
    );
    expect(
      tester.getSemantics(alert).getSemanticsData().role,
      SemanticsRole.alert,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps voice controls in a compact bottom dock on Android', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.selectedChannel = _PortraitApi.voiceChannel;
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.connected;
    state.microphoneMuted = false;
    state.microphoneUnavailable = false;
    state.deafened = false;
    state.audioActivationMode = AudioActivationMode.vad;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final dock = find.byKey(const ValueKey('mobile-voice-dock'));
    expect(dock, findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Открыть навигацию')).left,
      lessThan(24),
    );
    expect(
      tester.getRect(find.text('В голосовом канале')).left,
      greaterThan(tester.getRect(dock).left + 32),
    );
    expect(find.byTooltip('Выключить микрофон'), findsOneWidget);
    expect(find.byTooltip('Выключить удалённый звук'), findsOneWidget);
    expect(
      find.descendant(
        of: dock,
        matching: find.byTooltip('Начать демонстрацию экрана'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Выйти из голосового канала'), findsOneWidget);
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(844));

    expect(find.byTooltip('Развернуть голосовую панель'), findsNothing);
    expect(find.byTooltip('Свернуть голосовую панель'), findsNothing);
    expect(find.textContaining('Вы можете открыть другой канал'), findsNothing);
    final dockHeight = tester.getRect(dock).height;
    await tester.drag(dock, const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(tester.getRect(dock).height, dockHeight);
    expect(find.textContaining('Вы можете открыть другой канал'), findsNothing);
    expect(state.voiceChannel, isNotNull);

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    expect(dock, findsOneWidget);
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(844));

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'resets viewer state through app rebuild on voice channel change',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final state = AppState(
        _PortraitApi(extraVoiceChannels: [_PortraitApi.secondVoiceChannel]),
      );
      await state.initialize();
      state.selectedChannel = _PortraitApi.voiceChannel;
      state.voiceChannel = _PortraitApi.voiceChannel;
      state.voicePhase = VoicePhase.connected;
      await tester.pumpWidget(BoohtacordApp(state: state));
      await tester.pumpAndSettle();

      final firstRoom = tester.state(
        find.byKey(const ValueKey('voice-room:voice-1')),
      );
      await state.selectChannel(_PortraitApi.secondVoiceChannel);
      await tester.pumpAndSettle();

      final secondRoom = tester.state(
        find.byKey(const ValueKey('voice-room:voice-2')),
      );
      expect(identical(firstRoom, secondRoom), isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('shows channel administration only for administrators', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();
    expect(find.text('Роли и доступ к этой гильдии'), findsOneWidget);
    expect(find.text('@peer'), findsOneWidget);
    expect(find.text('Сбросить пароль'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Каналы'));
    await tester.pumpAndSettle();
    final channelPicker = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(channelPicker);
    await tester.tap(channelPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('общий').last);
    await tester.pumpAndSettle();

    expect(find.text('Администрирование'), findsOneWidget);
    expect(find.text('Создать категорию'), findsOneWidget);
    expect(find.text('Создать канал'), findsOneWidget);
    expect(find.text('Категорию выше'), findsOneWidget);
    expect(find.text('Канал выше'), findsOneWidget);
    expect(find.text('Перенести канал'), findsNWidgets(2));
    expect(find.text('Текстовый канал для архивации'), findsOneWidget);
    expect(find.text('Голосовой канал для закрытия'), findsOneWidget);
    expect(find.text('Архивировать канал'), findsOneWidget);
    expect(find.text('Закрыть вход'), findsOneWidget);
    expect(find.byTooltip('Обновить список каналов'), findsOneWidget);

    final archivePicker = find.byKey(const ValueKey('archive-channel:null'));
    await tester.ensureVisible(archivePicker);
    await tester.tap(archivePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('общий').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архивировать канал'));
    await tester.pumpAndSettle();
    expect(find.textContaining('История сообщений сохранится'), findsOneWidget);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();

    final closePicker = find.byKey(const ValueKey('close-channel:null'));
    await tester.ensureVisible(closePicker);
    await tester.tap(closePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('комната').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрыть вход'));
    await tester.pumpAndSettle();
    expect(find.textContaining('отзыв media-доступа в SFU'), findsOneWidget);
    await tester.tap(find.text('Отмена').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аудит'));
    await tester.pumpAndSettle();
    expect(
      find.text('События управления без содержимого сообщений'),
      findsOneWidget,
    );
    expect(find.text('Создан канал'), findsOneWidget);
    expect(find.text('Инициатор · Admin (@admin)'), findsOneWidget);
    expect(find.text('Показать более ранние'), findsOneWidget);
    await tester.tap(find.text('Показать более ранние'));
    await tester.pumpAndSettle();
    expect(find.text('Завершён сброс пароля'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();

    final memberState = AppState(_PortraitApi());
    await memberState.initialize();
    memberState.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(state: memberState)),
    );
    expect(find.text('Создать категорию'), findsNothing);
    expect(find.text('Создать канал'), findsNothing);
    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    memberState.dispose();
  });

  testWidgets('preserves member drafts on failure and handles reset links', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    api.failAdminUpdate = true;
    final saveButton = find.byKey(const ValueKey('save-account:account-2'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Запрос отклонён сервером.'), findsOneWidget);
    expect(api.adminUpdates, [('account-2', 'ADMINISTRATOR', true)]);
    expect(find.text('Администратор'), findsWidgets);
    expect(find.byType(Switch).first, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).focusNode?.hasFocus, isTrue);

    api.failAdminUpdate = false;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Изменения для @peer сохранены.'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).focusNode?.hasFocus, isTrue);

    final resetButton = find.byKey(const ValueKey('reset-account:account-2'));
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(find.text('Одноразовая ссылка для @peer'), findsOneWidget);
    expect(
      find.text('https://v.bootybay.ru/reset-password#token=one-time'),
      findsOneWidget,
    );
    expect(find.textContaining('Истекает:'), findsOneWidget);

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Скопировать ссылку'));
    await tester.pumpAndSettle();
    expect(copiedText, 'https://v.bootybay.ru/reset-password#token=one-time');

    await tester.tap(find.byTooltip('Закрыть и удалить ссылку'));
    await tester.pumpAndSettle();
    expect(find.text('Одноразовая ссылка для @peer'), findsNothing);
    expect(
      find.text('https://v.bootybay.ru/reset-password#token=one-time'),
      findsNothing,
    );

    api.failResetLink = true;
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось создать ссылку.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('renders audit error, empty, and refreshed event states', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.reset);
    final api = _PortraitApi()..failAudit = true;
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Аудит'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить журнал аудита.'), findsOneWidget);

    api.failAudit = false;
    api.emptyAudit = true;
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Записей пока нет.'), findsOneWidget);

    api.emptyAudit = false;
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Создан канал'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows loading while audit pages are being fetched', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.reset);
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    api.auditGate = Completer<void>();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Аудит'));
    await tester.pump();
    expect(find.text('Загружаем аудит…'), findsOneWidget);
    api.auditGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Создан канал'), findsOneWidget);

    api.auditGate = Completer<void>();
    await tester.tap(find.text('Показать более ранние'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.auditGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Завершён сброс пароля'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('loads additional admin member pages using the cursor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.reset);
    final api = _PortraitApi()..paginateAdminAccounts = true;
    final state = AppState(api);
    await state.initialize();
    state.user = const SessionUser(
      accountId: 'account-1',
      role: 'ADMINISTRATOR',
    );
    state.toggleWorkspacePanel(WorkspacePanel.admin);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('@peer'), findsOneWidget);
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();
    expect(api.adminAccountCursors, [null, 'cursor-next']);
    expect(find.text('@peer-2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('announces when a voice connection is reconnecting', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi());
    await state.initialize();
    state.voiceChannel = _PortraitApi.voiceChannel;
    state.voicePhase = VoicePhase.reconnecting;
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));

    expect(find.text('Восстанавливаем голосовое соединение'), findsOneWidget);
    expect(find.text('комната'), findsWidgets);
    expect(find.textContaining('Участников в голосовом канале:'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('offers listener-only voice join before microphone access', (
    tester,
  ) async {
    final state = AppState(_PortraitApi());
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Подключиться к голосу'), findsOneWidget);
    expect(find.text('Подключиться без микрофона'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('opens text history at latest and advances its read cursor', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 40);
    final state = AppState(api);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(api.advancedMessageIds, contains('message-39'));

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    final messageList = find.byKey(const ValueKey('text-channel-messages'));
    final scrollController = tester.widget<ListView>(messageList).controller!;
    final initialOffset = scrollController.position.pixels;
    expect(initialOffset, greaterThan(0));
    final gesture = await tester.startGesture(tester.getCenter(messageList));
    for (var step = 0; step < 8; step++) {
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      scrollController.position.pixels,
      lessThan(initialOffset),
      reason: 'a downward touch drag should reveal older channel messages',
    );
    expect(api.advancedMessageIds, ['message-39']);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('preserves the visible text anchor when loading an older page', (
    tester,
  ) async {
    final api = _PortraitApi(
      withHistory: true,
      historyCount: 30,
      paginatedHistory: true,
    );
    final state = AppState(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.nextMessageCursor, 'older-page');
    expect(api.advancedMessageIds.last, 'message-29');
    final list = find.byKey(const ValueKey('text-channel-messages'));
    final scroll = tester.widget<ListView>(list).controller!;
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    final anchor = find.text('Сообщение 0');
    expect(anchor, findsOneWidget);
    final anchorTopBefore = tester.getTopLeft(anchor).dy;

    await tester.tap(find.text('Загрузить предыдущие сообщения'));
    await tester.pumpAndSettle();

    expect(api.messagePageCalls, 2);
    expect(state.messages.first.id, 'older-message-0');
    expect(
      tester.getTopLeft(anchor).dy,
      closeTo(anchorTopBefore, 1),
      reason: 'loading a page above the viewport must not move its visible row',
    );
    expect(api.advancedMessageIds, isNot(contains('older-message-0')));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('preserves the visible DM anchor when loading an older page', (
    tester,
  ) async {
    final api = _PortraitApi(
      includeDirectMessage: true,
      paginatedDirectHistory: true,
      directHistoryCount: 30,
    );
    final state = AppState(api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.nextDirectMessageCursor, 'older-dm-page');
    expect(api.advancedDirectMessageIds.last, 'dm-message-29');
    final anchor = find.text('Личное сообщение 0');
    expect(anchor, findsOneWidget);
    final anchorTopBefore = tester.getTopLeft(anchor).dy;

    await tester.tap(find.text('Загрузить предыдущие сообщения'));
    await tester.pumpAndSettle();

    expect(api.directMessagePageCalls, 2);
    expect(state.directMessageHistory.first.id, 'older-dm-message-0');
    expect(
      tester.getTopLeft(anchor).dy,
      closeTo(anchorTopBefore, 1),
      reason:
          'loading a DM page above the viewport must not move its visible row',
    );
    expect(api.advancedDirectMessageIds, ['dm-message-29']);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('selects a reply target and sends a reply in a text channel', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 2);
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();

    expect(find.text('Ответ для @Участник'), findsOneWidget);
    await tester.tap(find.byTooltip('Выбрать упоминание'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ответ из клиента');
    await tester.tap(find.byTooltip('Отправить сообщение'));
    await tester.pumpAndSettle();

    expect(api.sentReplyToId, 'message-1');
    expect(api.sentMentionIds, ['account-2']);
    expect(state.messages.last.body, 'Ответ из клиента');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('reply composer geometry matches Design V2 for text and DM', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      _PortraitApi(
        withHistory: true,
        historyCount: 2,
        includeDirectMessage: true,
      ),
    );
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> selectReplyTarget() async {
      await tester.tap(find.byTooltip('Действия с сообщением').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();
    }

    void expectReplyGeometry({required double fieldHeight}) {
      final wrapper = tester.widget<Container>(
        find.byKey(const ValueKey('text-composer-wrap')),
      );
      expect(wrapper.padding, const EdgeInsets.fromLTRB(24, 0, 24, 18));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('reply-target-banner')))
            .height,
        41,
      );
      final banner = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey('reply-target-banner')),
          matching: find.byType(Container),
        ),
      );
      expect(
        (banner.decoration! as BoxDecoration).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(10)),
      );
      expect((banner.decoration! as BoxDecoration).color, GcColors.surface);
      expect(tester.getRect(find.byType(TextField).last).height, fieldHeight);
      expect(
        tester.getRect(find.byKey(const ValueKey('text-composer-wrap'))).height,
        131,
      );
      expect(find.text('Отмена'), findsOneWidget);
      final decoration = tester
          .widget<TextField>(find.byType(TextField).last)
          .decoration!;
      expect(decoration.hintText, 'Написать сообщение…');
      expect(decoration.fillColor, GcColors.raised);
      expect(
        (decoration.enabledBorder as OutlineInputBorder).borderRadius,
        const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      );
    }

    void expectDirectReplyGeometry({required double fieldHeight}) {
      final wrapper = tester.widget<Container>(
        find.byKey(const ValueKey('direct-message-composer-wrap')),
      );
      expect(wrapper.padding, const EdgeInsets.fromLTRB(24, 0, 24, 18));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
            .height,
        131,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('reply-target-banner')))
            .height,
        41,
      );
      final decoration = tester
          .widget<TextField>(find.byType(TextField).last)
          .decoration!;
      expect(decoration.hintText, 'Написать сообщение…');
      expect(decoration.fillColor, GcColors.raised);
      expect(tester.getRect(find.byType(TextField).last).height, fieldHeight);
      expect(
        (decoration.enabledBorder as OutlineInputBorder).borderRadius,
        const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      );
    }

    await selectReplyTarget();
    expectReplyGeometry(fieldHeight: 54);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expectReplyGeometry(fieldHeight: 52);

    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpAndSettle();
    await selectReplyTarget();
    expectDirectReplyGeometry(fieldHeight: 52);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expectDirectReplyGeometry(fieldHeight: 54);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reply-target-banner')), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('direct-message-composer-wrap')))
          .height,
      70,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'opens a reply context when its target is outside loaded history',
    (tester) async {
      final api = _PortraitApi(withHistory: true)
        ..replyContextPage = ChatMessagePage(
          messages: [
            ChatMessage(
              id: 'older-reply-target',
              channelId: _PortraitApi.channel.id,
              authorId: 'account-2',
              body: 'Исходное сообщение из старой страницы',
              createdAt: DateTime.utc(2026, 9, 24),
              deleted: false,
              revision: 1,
            ),
          ],
        );
      final state = AppState(api);
      await state.initialize();
      state.messages = [
        ChatMessage(
          id: 'reply-message',
          channelId: _PortraitApi.channel.id,
          authorId: 'account-1',
          body: 'Ответ в текущей странице',
          createdAt: DateTime.utc(2026, 9, 25),
          deleted: false,
          revision: 1,
          replyToId: 'older-reply-target',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Исходное сообщение недоступно'));
      await tester.pumpAndSettle();

      expect(api.lastMessageAt, 'older-reply-target');
      expect(state.workspacePanel, WorkspacePanel.searchContext);
      expect(find.text('Контекст ответа'), findsOneWidget);
      expect(
        find.text('Исходное сообщение из старой страницы'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('message composer groups attachment and paste actions', (
    tester,
  ) async {
    final state = AppState(_PortraitApi());
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Вложение и вставка'));
    await tester.pumpAndSettle();

    expect(find.text('Прикрепить файл'), findsOneWidget);
    expect(find.text('Вставить из буфера'), findsOneWidget);
    expect(find.byTooltip('Выбрать упоминание'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'opens a DM reply context when its target is outside loaded history',
    (tester) async {
      final api = _PortraitApi(includeDirectMessage: true)
        ..directReplyContextPage = DirectChatMessagePage(
          messages: [
            DirectChatMessage(
              id: 'older-dm-reply-target',
              directMessageId: 'dm-1',
              authorId: 'account-2',
              body: 'Старое личное сообщение',
              createdAt: DateTime.utc(2026, 9, 24),
              deleted: false,
              revision: 1,
            ),
          ],
        );
      final state = AppState(api);
      await state.initialize();
      await state.openDirectConversation(state.directMessages.single);
      state.directMessageHistory = [
        DirectChatMessage(
          id: 'dm-reply-message',
          directMessageId: 'dm-1',
          authorId: 'account-1',
          body: 'Ответ в личной переписке',
          createdAt: DateTime.utc(2026, 9, 25),
          deleted: false,
          revision: 1,
          replyToId: 'older-dm-reply-target',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: state,
            builder: (_, _) => WorkspaceScreen(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Исходное сообщение недоступно'));
      await tester.pumpAndSettle();

      expect(api.lastDirectMessageAt, 'older-dm-reply-target');
      expect(state.workspacePanel, WorkspacePanel.searchContext);
      expect(find.text('Контекст ответа'), findsOneWidget);
      expect(find.text('Старое личное сообщение'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('text composer submits from the soft-keyboard send action', (
    tester,
  ) async {
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField).last;
    expect(
      tester.widget<TextField>(composer).textInputAction,
      TextInputAction.send,
    );
    await tester.enterText(composer, 'Отправка с клавиатуры');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(api.textSendIds, hasLength(1));
    expect(state.messages.last.body, 'Отправка с клавиатуры');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('text composer does not send on Shift+Enter', (tester) async {
    final api = _PortraitApi();
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField).last;
    await tester.tap(composer);
    await tester.enterText(composer, 'Первая строка');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(api.textSendIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('direct-message composer submits from the soft-keyboard action', (
    tester,
  ) async {
    final api = _PortraitApi(includeDirectMessage: true);
    final state = AppState(api);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: WorkspaceScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField).last;
    expect(
      tester.widget<TextField>(composer).textInputAction,
      TextInputAction.send,
    );
    await tester.enterText(composer, 'Личное сообщение с клавиатуры');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      state.directMessageHistory.last.body,
      'Личное сообщение с клавиатуры',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('shows a failed text send and retries the same client ID', (
    tester,
  ) async {
    final api = _PortraitApi()..failTextSends = 1;
    final state = AppState(api);
    await state.initialize();
    expect(await state.send('Повторяемое сообщение'), isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не отправлено · Повторить отправку'), findsOneWidget);
    expect(state.messages.last.sendStatus, MessageSendStatus.failed);
    await tester.tap(find.text('Не отправлено · Повторить отправку'));
    await tester.pumpAndSettle();

    expect(api.textSendIds, hasLength(2));
    expect(api.textSendIds.last, api.textSendIds.first);
    expect(state.messages.last.sendStatus, isNull);
    expect(find.text('Не отправлено · Повторить отправку'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps an edit draft through revision conflict and refresh', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 2)
      ..textEditConflicts = 1;
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Мой сохранённый черновик',
    );
    await tester.tap(find.byTooltip('Выбрать упоминание').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Обновите версию'),
      ),
      findsOneWidget,
    );
    expect(find.text('Мой сохранённый черновик'), findsOneWidget);
    expect(find.text('Обновить версию'), findsOneWidget);
    expect(state.messages, hasLength(2));

    await tester.tap(find.text('Обновить версию'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Версия обновлена'), findsOneWidget);
    expect(find.text('Мой сохранённый черновик'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();

    expect(api.textEditRevisions, [1, 2]);
    expect(api.textEditMentionIds, [
      ['account-2'],
      ['account-2'],
    ]);
    expect(state.messages.last.body, 'Мой сохранённый черновик');
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('keeps a deleted-during-edit draft available for copying', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 1)
      ..textEditConflicts = 1
      ..deleteTextOnConflict = true;
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Черновик для копирования',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обновить версию'));
    await tester.pumpAndSettle();

    expect(state.messages.single.deleted, isTrue);
    expect(find.text('Черновик для копирования'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('черновик сохранён для копирования'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('selects a reply target and sends a direct-message reply', (
    tester,
  ) async {
    final api = _PortraitApi(includeDirectMessage: true);
    final state = AppState(api);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Действия с сообщением'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();

    expect(find.text('Ответ для Собеседник'), findsOneWidget);
    await tester.tap(find.byTooltip('Выбрать упоминание'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Собеседник').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ответ в личке');
    await tester.tap(find.byTooltip('Отправить личное сообщение'));
    await tester.pumpAndSettle();

    expect(api.sentDirectReplyToId, 'dm-message-1');
    expect(api.sentDirectMentionIds, ['account-2']);
    expect(state.directMessageHistory.last.body, 'Ответ в личке');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search opens a hit in context and returns to the origin', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true, historyCount: 2);
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();
    expect(find.text('Область поиска'), findsOneWidget);
    final submitButton = find.widgetWithText(FilledButton, 'Найти');
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(api.lastSearchQuery, isNull);
    expect(find.text('Введите поисковый запрос.'), findsNothing);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'current',
    );
    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Слова или «точная фраза»',
      ),
      'найденный текст',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();
    expect(api.lastSearchQuery, 'найденный текст');
    expect(find.text('Открыть сообщение'), findsOneWidget);
    final resultStatus = find.text('Результатов: 1.');
    expect(resultStatus, findsOneWidget);
    expect(
      tester.getSemantics(resultStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    api.searchGate = Completer<SearchMessagePage>();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Слова или «точная фраза»',
      ),
      'следующий запрос',
    );
    await tester.tap(find.text('Найти'));
    await tester.pump();
    final loadingStatus = find.text('Ищем сообщения…');
    expect(loadingStatus, findsOneWidget);
    expect(
      tester.getSemantics(loadingStatus).flagsCollection.isLiveRegion,
      isTrue,
    );
    api.searchGate!.complete(
      SearchMessagePage(
        messages: [
          SearchMessage(
            id: 'message-1',
            kind: SearchMessageKind.channel,
            conversationId: _PortraitApi.channel.id,
            authorId: 'account-1',
            body: 'Найденный текст',
            createdAt: DateTime.utc(2026, 9, 25),
            revision: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Результатов: 1.'), findsOneWidget);

    await tester.tap(find.text('Открыть сообщение'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.searchContext);
    expect(find.text('Контекст найденного сообщения'), findsOneWidget);
    expect(find.text('Последнее сообщение'), findsOneWidget);

    await tester.tap(find.text('Вернуться к беседе'));
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(state.selectedChannel?.id, _PortraitApi.channel.id);
    expect(find.text('Последнее сообщение'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search announces an empty result state as a live region', (
    tester,
  ) async {
    final api = _PortraitApi(withHistory: true)..emptySearchResults = true;
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Слова или «точная фраза»',
      ),
      'нет совпадений',
    );
    await tester.pump();
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    final emptyStatus = find.text('Совпадений нет.');
    expect(emptyStatus, findsOneWidget);
    expect(
      tester.getSemantics(emptyStatus).flagsCollection.isLiveRegion,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Ctrl+K opens search but does not steal text input focus', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.search);
    expect(find.text('Последнее сообщение'), findsOneWidget);
    final searchScope =
        tester
                .widgetList<FocusScope>(find.byType(FocusScope))
                .firstWhere((scope) => scope.debugLabel == 'workspace-search')
                .focusNode!
            as FocusScopeNode;
    expect(searchScope.hasFocus, isTrue);
    expect(searchScope.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Поиск сообщений',
            ),
          )
          .focusNode!
          .hasPrimaryFocus,
      isTrue,
    );

    final composer = find.byType(TextField).first;
    await tester.tap(composer);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(state.workspacePanel, WorkspacePanel.none);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('wide search keeps the active conversation beside the panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(state.workspacePanel, WorkspacePanel.search);
    expect(find.text('Область поиска'), findsOneWidget);
    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 400,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Закрыть панель'), findsNothing);
    expect(
      tester
          .widgetList<FocusScope>(find.byType(FocusScope))
          .where((scope) => scope.debugLabel == 'workspace-search'),
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('medium desktop search uses the widened 360 px panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(state.workspacePanel, WorkspacePanel.search);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 360,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('wide voice search keeps its 320 px modal drawer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(_PortraitApi(withHistory: true, historyCount: 1));
    await state.initialize();
    await state.selectChannel(_PortraitApi.voiceChannel);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(state.workspacePanel, WorkspacePanel.search);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'all',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.width == 320,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 400,
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('search defaults to the active direct-message conversation', (
    tester,
  ) async {
    final state = AppState(_PortraitApi(includeDirectMessage: true));
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (_, _) => WorkspaceScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Открыть навигацию'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Поиск сообщений'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'current',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('portrait layout keeps the channel open behind drawers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final state = AppState(_PortraitApi());
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));

    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    expect(find.byTooltip('Открыть навигацию'), findsOneWidget);

    await tester.tap(find.byTooltip('Открыть навигацию'));
    final returnFocus = FocusManager.instance.primaryFocus;
    await tester.pumpAndSettle();

    final drawerScope = tester
        .widgetList<FocusScope>(find.byType(FocusScope))
        .firstWhere((scope) => scope.debugLabel == 'workspace-drawer');
    final drawerFocusScope = drawerScope.focusNode! as FocusScopeNode;
    expect(drawerFocusScope.hasFocus, isTrue);
    expect(
      drawerFocusScope.traversalEdgeBehavior,
      TraversalEdgeBehavior.closedLoop,
    );
    final drawerFocusables = drawerFocusScope.traversalDescendants
        .where((node) => node.context != null)
        .toList();
    expect(drawerFocusables, isNotEmpty);
    drawerFocusables.last.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(drawerFocusScope.hasFocus, isTrue);
    expect(drawerFocusables, contains(FocusManager.instance.primaryFocus));

    expect(find.text('Каналы'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('@2'), findsOneWidget);
    expect(find.text('9'), findsNothing);
    expect(find.text('@3'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Закрыть навигацию'));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(returnFocus));
    await tester.tap(find.byTooltip('Открыть участников'));
    await tester.pumpAndSettle();
    expect(find.text('УЧАСТНИКИ'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть участников'));
    await tester.pumpAndSettle();
    expect(find.text('Добро пожаловать в #общий'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('groups guild members by presence with web-equivalent counts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    const members = [
      GuildMember(
        id: '11111111-1111-4111-8111-111111111111',
        login: 'online',
        displayName: 'В сети',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
      GuildMember(
        id: '22222222-2222-4222-8222-222222222222',
        login: 'offline',
        displayName: 'Не в сети',
        role: 'MEMBER',
        presence: MemberPresence.offline,
      ),
      GuildMember(
        id: '33333333-3333-4333-8333-333333333333',
        login: 'unknown',
        displayName: 'Неизвестен',
        role: 'MEMBER',
        presence: MemberPresence.unknown,
      ),
    ];
    final api = _PortraitApi(
      membersResult: members,
      membersFailures: 1,
      memberProfileFailures: 1,
    );
    final state = AppState(api);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    final membersPanel = find.byKey(const ValueKey('members-panel'));
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Список участников временно недоступен.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('Повторить')),
      findsOneWidget,
    );
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(api.membersFailures, 0);
    expect(state.membersError, isNull);
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Список участников временно недоступен.'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('В сети — 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('Не в сети — 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Статус неизвестен — 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('Неизвестен')),
      findsOneWidget,
    );

    state.guildPresence.invalidate();
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: membersPanel,
        matching: find.text('Статус неизвестен — 3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: membersPanel, matching: find.text('В сети — 1')),
      findsNothing,
    );

    state.guildPresence.acceptSnapshot([
      '11111111-1111-4111-8111-111111111111',
    ]);
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: membersPanel, matching: find.text('В сети — 1')),
      findsOneWidget,
    );
    await tester.tap(find.text('Неизвестен'));
    await tester.pumpAndSettle();
    final profilePopover = find.byKey(const ValueKey('member-profile-popover'));
    expect(
      find.text('Не удалось загрузить профиль участника.'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: profilePopover, matching: find.text('Повторить')),
    );
    await tester.pumpAndSettle();
    expect(profilePopover, findsOneWidget);
    expect(find.text('@unknown'), findsOneWidget);
    final memberRow = find.ancestor(
      of: find.text('Неизвестен'),
      matching: find.byType(ListTile),
    );
    final rowRect = tester.getRect(memberRow);
    final popoverRect = tester.getRect(profilePopover);
    final membersPanelRect = tester.getRect(membersPanel);
    expect(popoverRect.width, closeTo(membersPanelRect.width - 32, 1));
    expect(popoverRect.width, 215);
    expect(popoverRect.top, closeTo(rowRect.top, 1));
    expect(popoverRect.right, closeTo(membersPanelRect.right - 16, 1));
    final profileAvatar = tester.widget<AuthenticatedAvatar>(
      find.descendant(
        of: profilePopover,
        matching: find.byType(AuthenticatedAvatar),
      ),
    );
    expect(profileAvatar.radius, 32);
    expect(profileAvatar.backgroundColor, GcColors.avatarViolet);
    expect(profileAvatar.fallbackFontSize, 20);
    final profileName = tester.widget<Text>(
      find.descendant(of: profilePopover, matching: find.text('Неизвестен')),
    );
    expect(profileName.style?.fontSize, 20);
    final messageButton = find.descendant(
      of: profilePopover,
      matching: find.widgetWithText(OutlinedButton, 'Сообщение'),
    );
    expect(messageButton, findsOneWidget);
    expect(tester.getSize(messageButton).width, popoverRect.width - 32);
    expect(tester.getSize(messageButton).width, 183);
    expect(tester.getSize(messageButton).height, 40);
    expect(
      popoverRect.right,
      lessThanOrEqualTo(tester.view.physicalSize.width),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(profilePopover, findsNothing);
    final profileTrigger = tester.widget<Focus>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Focus &&
            widget.focusNode?.debugLabel == 'member-profile-trigger',
      ),
    );
    expect(profileTrigger.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}

class _PublishedScreenRoom extends Room {
  final members = <String, RemoteParticipant>{};
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(members);
}

class _PublishedScreenState extends AppState {
  _PublishedScreenState(this.testRoom) : super(_PortraitApi());
  final Room testRoom;
  String? selectedScreen;
  @override
  Room get room => testRoom;
  @override
  Future<void> selectRemoteScreenForViewing(String? identity) async {
    selectedScreen = identity;
  }
}

class _PortraitApi extends ApiClient {
  _PortraitApi({
    this.withHistory = false,
    this.historyCount = 1,
    this.paginatedHistory = false,
    this.paginatedDirectHistory = false,
    this.directHistoryCount = 1,
    this.includeDirectMessage = false,
    this.voiceRosters = const [],
    this.extraVoiceChannels = const [],
    this.membersFailures = 0,
    this.memberProfileFailures = 0,
    this.membersResult = const [
      GuildMember(
        id: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
      GuildMember(
        id: 'account-2',
        login: 'peer',
        displayName: 'Собеседник',
        role: 'MEMBER',
        presence: MemberPresence.online,
      ),
    ],
  });
  final bool withHistory;
  final int historyCount;
  final bool paginatedHistory;
  final bool paginatedDirectHistory;
  final int directHistoryCount;
  final bool includeDirectMessage;
  final List<VoiceRoomRoster> voiceRosters;
  final List<GuildChannel> extraVoiceChannels;
  int membersFailures;
  int memberProfileFailures;
  final List<GuildMember> membersResult;
  final advancedMessageIds = <String>[];
  int messagePageCalls = 0;
  String? lastMessageAt;
  ChatMessagePage? replyContextPage;
  int directMessagePageCalls = 0;
  String? lastDirectMessageAt;
  DirectChatMessagePage? directReplyContextPage;
  final advancedDirectMessageIds = <String>[];
  String? sentReplyToId;
  String? sentDirectReplyToId;
  List<String> sentMentionIds = const [];
  List<String> sentDirectMentionIds = const [];
  List<String> sentAttachmentIds = const [];
  List<String> sentDirectAttachmentIds = const [];
  int failTextSends = 0;
  final textSendIds = <String>[];
  int textEditConflicts = 0;
  int latestTextRevision = 1;
  bool deleteTextOnConflict = false;
  bool latestTextDeleted = false;
  final textEditRevisions = <int>[];
  final textEditMentionIds = <List<String>>[];
  String? lastSearchQuery;
  Completer<SearchMessagePage>? searchGate;
  bool emptySearchResults = false;
  bool failAdminUpdate = false;
  bool failResetLink = false;
  bool failAudit = false;
  bool emptyAudit = false;
  Completer<void>? auditGate;
  bool paginateAdminAccounts = false;
  final adminAccountCursors = <String?>[];
  final adminUpdates = <(String, String, bool)>[];

  static const channel = GuildChannel(
    id: 'channel-1',
    name: 'общий',
    kind: ChannelKind.text,
    admissionClosed: false,
    unreadCount: 4,
    mentionCount: 2,
  );
  static const voiceChannel = GuildChannel(
    id: 'voice-1',
    name: 'комната',
    kind: ChannelKind.voice,
    admissionClosed: false,
    unreadCount: 9,
    mentionCount: 3,
  );
  static const secondVoiceChannel = GuildChannel(
    id: 'voice-2',
    name: 'комната 2',
    kind: ChannelKind.voice,
    admissionClosed: false,
    unreadCount: 0,
    mentionCount: 0,
  );

  @override
  bool get realtimeEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<http.StreamedResponse> maintenanceEvents() async =>
      http.StreamedResponse(
        const Stream<List<int>>.empty(),
        200,
        headers: {'content-type': 'text/event-stream'},
      );

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'account-1', role: 'MEMBER');
  @override
  Future<PermissionSnapshot> loadPermissions() async => PermissionSnapshot(
    accountId: 'account-1',
    role: GuildRole.member,
    revision: 1,
    values: {for (final permission in GuildPermission.values) permission: true},
  );

  @override
  Future<OwnProfile> ownProfile() async => const OwnProfile(
    accountId: 'account-1',
    login: 'member',
    displayName: 'Участник',
    role: 'MEMBER',
  );

  @override
  Future<ChannelTopology> topology() async => ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-1',
        name: 'Текстовые каналы',
        channels: [channel, voiceChannel, ...extraVoiceChannels],
      ),
    ],
  );

  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() async => voiceRosters;

  @override
  Future<http.StreamedResponse> voiceRosterEvents() async {
    final payload = jsonEncode({
      'channels': voiceRosters
          .map(
            (room) => {
              'channel_id': room.channelId,
              'participants': room.participants
                  .map(
                    (member) => {
                      'account_id': member.accountId,
                      'display_name': member.displayName,
                      'screen_sharing': member.screenSharing,
                      'microphone_muted': member.microphoneMuted,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: $payload\n\n')),
      200,
    );
  }

  @override
  Future<List<GuildMember>> members() async {
    if (membersFailures > 0) {
      membersFailures--;
      throw const ApiFailure('Список участников временно недоступен.');
    }
    return membersResult;
  }

  @override
  Future<GuildMember> memberProfile(String accountId) async {
    if (memberProfileFailures > 0) {
      memberProfileFailures--;
      throw const ApiFailure('Не удалось загрузить профиль участника.');
    }
    return membersResult.firstWhere((member) => member.id == accountId);
  }

  @override
  Future<SearchMessagePage> searchMessages(
    String query, {
    String? channelId,
    String? directMessageId,
    String? before,
    int limit = 20,
  }) async {
    lastSearchQuery = query;
    final gate = searchGate;
    if (gate != null) return gate.future;
    return SearchMessagePage(
      messages: emptySearchResults
          ? const []
          : [
              SearchMessage(
                id: 'message-1',
                kind: SearchMessageKind.channel,
                conversationId: channelId ?? channel.id,
                authorId: 'account-1',
                body: 'Найденный текст',
                createdAt: DateTime.utc(2026, 9, 25),
                revision: 1,
              ),
            ],
    );
  }

  @override
  Future<AdminAuditPage> listAdminAudit({
    String? before,
    int limit = 100,
  }) async {
    await auditGate?.future;
    if (failAudit) {
      throw const ApiFailure('Не удалось загрузить журнал аудита.');
    }
    if (emptyAudit) return const AdminAuditPage(events: []);
    return before == null
        ? AdminAuditPage(
            events: [
              AdminAuditEvent(
                id: 'event-1',
                eventType: 'CHANNEL_CREATED',
                createdAt: DateTime.utc(2026, 9, 26, 10),
                actorUserId: 'account-1',
                actorDisplayName: 'Admin',
                actorLogin: 'admin',
              ),
            ],
            nextCursor: 'cursor-older',
          )
        : AdminAuditPage(
            events: [
              AdminAuditEvent(
                id: 'event-older',
                eventType: 'PASSWORD_RESET_APPLIED',
                createdAt: DateTime.utc(2026, 9, 25, 10),
              ),
            ],
          );
  }

  @override
  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) async {
    adminAccountCursors.add(cursor);
    return AdminAccountPage(
      accounts: [
        AdminAccount(
          accountId: cursor == null ? 'account-2' : 'account-3',
          login: cursor == null ? 'peer' : 'peer-2',
          displayName: cursor == null ? 'Собеседник' : 'Другой собеседник',
          role: 'MEMBER',
          blocked: false,
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      ],
      nextCursor: paginateAdminAccounts && cursor == null
          ? 'cursor-next'
          : null,
    );
  }

  @override
  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
  }) async {
    adminUpdates.add((accountId, role, blocked));
    if (failAdminUpdate) {
      throw const ApiFailure('Запрос отклонён сервером.');
    }
  }

  @override
  Future<AdminPasswordResetLink> createAdminPasswordResetLink(
    String accountId,
  ) async {
    if (failResetLink) throw const ApiFailure('Не удалось создать ссылку.');
    return AdminPasswordResetLink(
      url: 'https://v.bootybay.ru/reset-password#token=one-time',
      expiresAt: DateTime.utc(2026, 9, 26, 12),
    );
  }

  @override
  Future<List<DirectConversation>> directMessages() async =>
      includeDirectMessage
      ? const [
          DirectConversation(
            id: 'dm-1',
            participantId: 'account-2',
            displayName: 'Собеседник',
            unreadCount: 1,
          ),
        ]
      : const [];

  @override
  Future<List<DirectChatMessage>> directMessageHistory(String id) async =>
      List.generate(
        paginatedDirectHistory ? directHistoryCount : 1,
        (index) => DirectChatMessage(
          id: paginatedDirectHistory ? 'dm-message-$index' : 'dm-message-1',
          directMessageId: id,
          authorId: 'account-2',
          body: paginatedDirectHistory
              ? 'Личное сообщение $index'
              : 'Исходное личное сообщение',
          createdAt: DateTime.utc(2026, 9, 25).add(Duration(minutes: index)),
          deleted: false,
          revision: 1,
        ),
      );

  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async {
    directMessagePageCalls++;
    if (at != null) {
      lastDirectMessageAt = at;
      if (directReplyContextPage != null) return directReplyContextPage!;
    }
    if (paginatedDirectHistory && before != null) {
      return DirectChatMessagePage(
        messages: List.generate(
          12,
          (index) => DirectChatMessage(
            id: 'older-dm-message-$index',
            directMessageId: id,
            authorId: 'account-2',
            body: index == 0
                ? 'Более старое личное сообщение 0 ${'длинный текст ' * 16}'
                : 'Более старое личное сообщение $index',
            createdAt: DateTime.utc(2026, 9, 24).add(Duration(minutes: index)),
            deleted: false,
            revision: 1,
          ),
        ),
        nextCursor: 'oldest-dm-page',
      );
    }
    return DirectChatMessagePage(
      messages: await directMessageHistory(id),
      nextCursor: paginatedDirectHistory ? 'older-dm-page' : null,
    );
  }

  @override
  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) async {
    advancedDirectMessageIds.add(messageId);
  }

  @override
  Future<DirectChatMessage> sendDirectMessage(
    String directMessageId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    sentDirectReplyToId = replyToId;
    sentDirectMentionIds = mentionUserIds;
    sentDirectAttachmentIds = attachmentIds;
    return DirectChatMessage(
      id: 'sent-dm-message',
      directMessageId: directMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 25),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<List<ChatMessage>> messages(String channelId) async => withHistory
      ? List.generate(
          historyCount,
          (index) => ChatMessage(
            id: 'message-$index',
            channelId: channelId,
            authorId: 'account-1',
            body: latestTextDeleted
                ? ''
                : index == historyCount - 1
                ? 'Последнее сообщение'
                : 'Сообщение $index',
            createdAt: DateTime.utc(2026, 9, 25).add(Duration(minutes: index)),
            deleted: latestTextDeleted,
            revision: latestTextRevision,
          ),
        )
      : const [];

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    messagePageCalls++;
    if (at != null) {
      lastMessageAt = at;
      if (replyContextPage != null) return replyContextPage!;
    }
    if (paginatedHistory && before != null) {
      return ChatMessagePage(
        messages: List.generate(
          12,
          (index) => ChatMessage(
            id: 'older-message-$index',
            channelId: channelId,
            authorId: 'account-2',
            body: index == 0
                ? 'Более старое сообщение 0 ${'длинный текст ' * 16}'
                : 'Более старое сообщение $index',
            createdAt: DateTime.utc(2026, 9, 24).add(Duration(minutes: index)),
            deleted: false,
            revision: 1,
          ),
        ),
        nextCursor: 'oldest-page',
      );
    }
    return ChatMessagePage(
      messages: await messages(channelId),
      nextCursor: paginatedHistory ? 'older-page' : null,
    );
  }

  @override
  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    textSendIds.add(clientMessageId);
    if (failTextSends > 0) {
      failTextSends--;
      throw const ApiFailure('Отправка не подтверждена.');
    }
    sentReplyToId = replyToId;
    sentMentionIds = mentionUserIds;
    sentAttachmentIds = attachmentIds;
    return ChatMessage(
      id: 'sent-message',
      channelId: channelId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 25, 1),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    textEditRevisions.add(expectedRevision);
    textEditMentionIds.add(mentionUserIds);
    if (textEditConflicts > 0) {
      textEditConflicts--;
      latestTextRevision = expectedRevision + 1;
      latestTextDeleted = deleteTextOnConflict;
      throw const ApiFailure('Конфликт редакции', status: 409);
    }
    return ChatMessage(
      id: messageId,
      channelId: channelId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 25, 1),
      deleted: false,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) async {
    advancedMessageIds.add(messageId);
  }
}
