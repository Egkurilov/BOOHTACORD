import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('opens native audio settings and processing controls', (
    tester,
  ) async {
    final state = AppState(
      _PortraitApi(),
      audioDeviceLoader: () async => const [],
    );
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Настройки аудио'), findsOneWidget);
    expect(find.text('Микрофон'), findsOneWidget);
    expect(find.text('Динамик'), findsOneWidget);
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

    expect(find.text('USB Microphone'), findsOneWidget);
    expect(find.text('Bluetooth headphones'), findsOneWidget);
    expect(find.textContaining('Системный выбор'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('offers to reopen a local screen from the participant view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
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
    expect(find.widgetWithText(OutlinedButton, 'Смотреть'), findsOneWidget);

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

  testWidgets('shows the voice roster before joining the room', (tester) async {
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

    expect(find.text('Сейчас в канале: 1'), findsOneWidget);
    expect(find.text('Мика'), findsNWidgets(2));
    expect(find.byTooltip('Показывает экран'), findsNWidgets(2));
    expect(find.text('Идёт трансляция'), findsOneWidget);
    expect(state.voicePhase, VoicePhase.idle);
    expect(state.voiceChannel, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Последнее сообщение'), findsOneWidget);
    expect(api.advancedMessageIds, contains('message-39'));

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 480));
    await tester.pumpAndSettle();
    expect(api.advancedMessageIds, ['message-39']);

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
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();
    expect(api.lastSearchQuery, 'найденный текст');
    expect(find.text('Открыть сообщение'), findsOneWidget);

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
    expect((popoverRect.top - rowRect.top).abs(), lessThan(16));
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

class _PortraitApi extends ApiClient {
  _PortraitApi({
    this.withHistory = false,
    this.historyCount = 1,
    this.includeDirectMessage = false,
    this.voiceRosters = const [],
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
  final bool includeDirectMessage;
  final List<VoiceRoomRoster> voiceRosters;
  int membersFailures;
  int memberProfileFailures;
  final List<GuildMember> membersResult;
  final advancedMessageIds = <String>[];
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

  @override
  bool get realtimeEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> maintenanceActive() async => false;

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'account-1', role: 'MEMBER');

  @override
  Future<OwnProfile> ownProfile() async => const OwnProfile(
    accountId: 'account-1',
    login: 'member',
    displayName: 'Участник',
    role: 'MEMBER',
  );

  @override
  Future<ChannelTopology> topology() async => const ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-1',
        name: 'Текстовые каналы',
        channels: [channel, voiceChannel],
      ),
    ],
  );

  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() async => voiceRosters;

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
    return SearchMessagePage(
      messages: [
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
  Future<List<DirectChatMessage>> directMessageHistory(String id) async => [
    DirectChatMessage(
      id: 'dm-message-1',
      directMessageId: id,
      authorId: 'account-2',
      body: 'Исходное личное сообщение',
      createdAt: DateTime.utc(2026, 9, 24),
      deleted: false,
      revision: 1,
    ),
  ];

  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async => DirectChatMessagePage(messages: await directMessageHistory(id));

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
  }) async => ChatMessagePage(messages: await messages(channelId));

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
