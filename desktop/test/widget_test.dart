import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'mobile drawer lists General text and voice without filters (${platform.name})',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const audioDeviceChannel = MethodChannel('boohtacord/audio_devices');
        if (platform == TargetPlatform.android) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            audioDeviceChannel,
            (_) async => null,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(audioDeviceChannel, null),
          );
        }
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        const textChannel = GuildChannel(
          id: 'text-1',
          name: 'общий',
          kind: ChannelKind.text,
          admissionClosed: false,
        );
        const voiceChannel = GuildChannel(
          id: 'voice-1',
          name: 'Комната команды',
          kind: ChannelKind.voice,
          admissionClosed: false,
        );
        final api = _VoiceEntryApi();
        final state = AppState(api)
          ..phase = AppPhase.ready
          ..user = const SessionUser(accountId: 'account-1', role: 'MEMBER')
          ..selectedChannel = textChannel
          ..topology = const ChannelTopology(
            revision: 1,
            categories: [
              ChannelCategory(
                id: 'category-1',
                name: 'General',
                channels: [textChannel, voiceChannel],
              ),
            ],
          );
        await tester.pumpWidget(BoohtacordApp(state: state));
        await tester.pumpAndSettle();

        final drawer = find.byKey(const ValueKey('mobile-sidebar'));
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);
        expect(
          find.descendant(of: drawer, matching: find.text('GENERAL')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: drawer, matching: find.text('общий')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: drawer, matching: find.text('Комната команды')),
          findsOneWidget,
        );
        expect(find.text('Куда пойдём?'), findsNothing);
        expect(find.text('Чаты'), findsNothing);
        expect(find.text('Голос'), findsNothing);
        await tester.tap(find.text('Комната команды'));
        await tester.pumpAndSettle();
        expect(state.selectedChannel?.id, voiceChannel.id);
        expect(api.voiceCredentialCalls, 1);
        expect(state.voicePhase, VoicePhase.error);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);
        expect(find.byKey(const ValueKey('workspace-header')), findsOneWidget);

        await tester.dragFrom(const Offset(180, 240), const Offset(110, 28));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);
        await tester.tap(find.text('общий'));
        await tester.pumpAndSettle();
        expect(state.selectedChannel?.id, textChannel.id);
        expect(find.byTooltip('Закрыть навигацию'), findsNothing);

        await tester.dragFrom(const Offset(30, 240), const Offset(110, 28));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Закрыть навигацию'), findsOneWidget);
        await tester.tap(find.text('Личные'));
        await tester.pumpAndSettle();
        expect(find.text('ЛИЧНЫЕ СООБЩЕНИЯ'), findsOneWidget);
        expect(find.text('GENERAL'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('mobile drawer fits 320 dp with no channels', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())
      ..phase = AppPhase.ready
      ..user = const SessionUser(accountId: 'account-1', role: 'MEMBER')
      ..topology = const ChannelTopology(revision: 1, categories: []);
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Каналы пока не созданы.'), findsOneWidget);
    expect(find.text('Куда пойдём?'), findsNothing);
    expect(find.text('Чаты'), findsNothing);
    expect(find.text('Голос'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows a branded loading state while session is restored', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    await tester.pumpWidget(BoohtacordApp(state: state));
    expect(find.text('Подключаемся к гильдии…'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('shows maintenance banner without blocking the client', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..maintenanceActive = true;
    await tester.pumpWidget(BoohtacordApp(state: state));

    expect(
      find.text(
        'Идёт обновление: новые входы и подключения к голосу временно приостановлены.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('maintenance-banner'))).height,
      44,
    );
    expect(find.text('Подключаемся к гильдии…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('matches web maintenance banner geometry on mobile width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..maintenanceActive = true;
    await tester.pumpWidget(BoohtacordApp(state: state));

    final notice = find.textContaining('Идёт обновление:');
    final text = tester.widget<Text>(notice);
    expect(text.style?.fontSize, 14);
    expect(text.style?.height, 20 / 14);
    expect(text.style?.decoration, TextDecoration.none);
    expect(text.maxLines, isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('maintenance-banner'))).height,
      greaterThan(44),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('maintenance banner has no safe-area gap before workspace', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    tester.view.viewPadding = const FakeViewPadding(top: 48);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())
      ..maintenanceActive = true
      ..phase = AppPhase.ready;
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.pumpAndSettle();

    final banner = tester.getRect(
      find.byKey(const ValueKey('maintenance-banner')),
    );
    final header = tester.getRect(
      find.byKey(const ValueKey('workspace-header')),
    );
    expect(header.top, banner.bottom);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('renders reset completion for a valid one-use link', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    state.phase = AppPhase.signedOut;
    final token = List.filled(43, 'a').join();
    state.openPasswordResetLink(
      'https://v.bootybay.ru/reset-password#token=$token',
    );
    await tester.pumpWidget(BoohtacordApp(state: state));

    expect(find.text('Новый пароль'), findsNWidgets(2));
    expect(find.text('Повторите пароль'), findsOneWidget);
    expect(find.text('Изменить пароль'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}

class _VoiceEntryApi extends ApiClient {
  int voiceCredentialCalls = 0;

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async => const ChatMessagePage(messages: []);

  @override
  Future<List<DirectConversation>> directMessages() async => const [];

  @override
  Future<List<DirectCandidate>> directMessageCandidates() async => const [];

  @override
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    voiceCredentialCalls++;
    throw const ApiFailure('Проверочный отказ подключения');
  }
}
