import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/panel.dart';
import 'package:boohtacord_desktop/src/features/admin/guild_settings/model.dart';
import 'package:boohtacord_desktop/src/features/guild/profile/name.dart';
import 'package:boohtacord_desktop/src/features/text/system_welcome/row.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class _Api extends ApiClient {
  @override
  Future<GuildSettings> readGuildSettings() async =>
      const GuildSettings('Имя', 1, null);
}

void main() {
  testWidgets(
    'admin settings and long public name fit portrait at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: Column(
                children: [
                  GuildName(List.filled(80, 'Ж').join()),
                  Expanded(
                    child: AdminGuildSettings(
                      api: _Api(),
                      channels: const [],
                      onSaved: () async {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Не отправлять'), findsOneWidget);
      expect(find.text('Название гильдии'), findsOneWidget);
    },
  );
  testWidgets(
    'system welcome exposes current mention and only allowed delete',
    (tester) async {
      final message = ChatMessage(
        id: 'm',
        channelId: 'c',
        authorId: 'u',
        body: 'врывается в гильдию.',
        createdAt: DateTime(2026),
        deleted: false,
        revision: 1,
        kind: 'SYSTEM_WELCOME',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SystemWelcomeMessage(
              message: message,
              displayName: 'Новое имя',
            ),
          ),
        ),
      );
      expect(
        find.textContaining('@Новое имя', findRichText: true),
        findsOneWidget,
      );
      expect(find.byTooltip('Удалить системное приветствие'), findsNothing);
      expect(find.text('Ответить'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SystemWelcomeMessage(
              message: message,
              displayName: 'Новое имя',
              onDelete: () {},
            ),
          ),
        ),
      );
      expect(find.byTooltip('Удалить системное приветствие'), findsOneWidget);
    },
  );
}
