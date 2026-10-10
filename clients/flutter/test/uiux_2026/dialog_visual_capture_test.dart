import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/confirmation_dialog.dart';
import 'package:boohtacord_desktop/src/widgets/screen_share_setup_dialog.dart';
import 'package:boohtacord_desktop/src/widgets/topology_actions/create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures current create, destructive and mobile setup dialogs', (
    tester,
  ) async {
    if (!uiuxVisualCaptureEnabled) return;
    await loadUiuxVisualCaptureFonts();

    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2880, 1800);
    addTearDown(tester.view.reset);

    final state = AppState(ApiClient())
      ..user = const SessionUser(accountId: 'account-a', role: 'ADMINISTRATOR')
      ..topology = const ChannelTopology(revision: 7, categories: []);
    state.permissions.snapshot = const PermissionSnapshot(
      accountId: 'account-a',
      role: GuildRole.administrator,
      revision: 1,
      values: {
        GuildPermission.textCreate: true,
        GuildPermission.textDelete: true,
        GuildPermission.voiceCreate: true,
        GuildPermission.voiceDelete: true,
        GuildPermission.categoryCreate: true,
        GuildPermission.categoryDelete: true,
      },
    );
    addTearDown(state.dispose);

    final rootKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showTopologyCreateDialog(context, state),
                  child: const Text('Создать раздел'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Создать раздел'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureUiuxBoundary(
      tester,
      find.byKey(rootKey),
      fileName: 'flutter-topology-create-desktop-1440x900@2x.png',
      pixelRatio: 2,
    );

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showConfirmationDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Закрыть «Комната команды»?'),
                      content: const Text(
                        'Участники будут отключены от голосового канала.',
                      ),
                      actions: [
                        TextButton(
                          autofocus: true,
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Закрыть канал'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Открыть подтверждение'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть подтверждение'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureUiuxBoundary(
      tester,
      find.byKey(rootKey),
      fileName: 'flutter-topology-destructive-desktop-1440x900@2x.png',
      pixelRatio: 2,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(786, 1704);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: guildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => ScreenShareSetupDialog.show(
                    context,
                    initialQuality: ScreenShareQuality.balanced,
                    allowSourceSelection: false,
                  ),
                  child: const Text('Открыть'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-screen-share')), findsOneWidget);
    await captureUiuxBoundary(
      tester,
      find.byKey(rootKey),
      fileName: 'flutter-screen-share-mobile-ime-2x-393x852.png',
      pixelRatio: 2,
    );
  });
}
