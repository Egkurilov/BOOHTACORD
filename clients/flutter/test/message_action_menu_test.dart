import 'package:boohtacord_desktop/src/features/conversation/lifecycle/types.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_message_action_menu/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_action_menu/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _textMessage = ChatMessage(
  id: 'message-1',
  channelId: 'channel-1',
  authorId: 'account-1',
  body: 'Text message',
  createdAt: DateTime.utc(2026, 10, 10),
  deleted: false,
  revision: 1,
);

final _directMessage = DirectChatMessage(
  id: 'dm-message-1',
  directMessageId: 'direct-1',
  authorId: 'account-1',
  body: 'Direct message',
  createdAt: DateTime.utc(2026, 10, 10),
  deleted: false,
  revision: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'TEXT action order is touch-sized and delete requires confirmation (${platform.name})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        var deleteCalls = 0;
        var replyCalls = 0;
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: WorkspaceMessageActionMenu(
                message: _textMessage,
                canEdit: true,
                canDelete: true,
                onReply: (_) {
                  replyCalls++;
                },
                mentionOptions: const [],
                selfId: 'account-1',
                onEdit: (_, _, _) async =>
                    (kind: MessageEditStatus.saved, message: null),
                onRefresh: () async => (revision: 1, deleted: false),
                onDelete: () async {
                  deleteCalls++;
                },
              ),
            ),
          ),
        );

        final trigger = find.byTooltip('Действия с сообщением');
        expect(tester.getSize(trigger), const Size.square(48));
        expect(find.bySemanticsLabel('Действия с сообщением'), findsOneWidget);
        await tester.tap(trigger);
        await tester.pumpAndSettle();

        final items = tester
            .widgetList<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>),
            )
            .toList();
        expect(items.map((item) => item.value), ['reply', 'edit', 'delete']);
        expect(items.every((item) => item.height >= 48), isTrue);

        await tester.tap(find.text('Ответить'));
        await tester.pumpAndSettle();
        expect(replyCalls, 1);
        expect(find.byType(PopupMenuItem<String>), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'message-actions-trigger',
        );

        await tester.tap(trigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        expect(find.text('Удалить сообщение?'), findsOneWidget);
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(deleteCalls, 0);

        await tester.tap(trigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
        await tester.pumpAndSettle();
        expect(deleteCalls, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );

    testWidgets(
      'DM action menu follows ownership and confirms deletion (${platform.name})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: WorkspaceDirectMessageActionMenu(
                message: _directMessage,
                canEdit: false,
                onReply: (_) {},
                mentionOptions: const [],
                selfId: 'account-2',
                onEdit: (_, _, _) async =>
                    (kind: MessageEditStatus.saved, message: null),
                onRefresh: () async => (revision: 1, deleted: false),
                onDelete: () async {},
              ),
            ),
          ),
        );

        final trigger = find.byTooltip('Действия с сообщением');
        expect(tester.getSize(trigger), const Size.square(48));
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<PopupMenuItem<String>>(
                find.byType(PopupMenuItem<String>),
              )
              .map((item) => item.value),
          ['reply'],
        );
        expect(find.text('Изменить'), findsNothing);
        expect(find.text('Удалить'), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        var deleteCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: WorkspaceDirectMessageActionMenu(
                message: _directMessage,
                canEdit: true,
                onReply: (_) {},
                mentionOptions: const [],
                selfId: 'account-1',
                onEdit: (_, _, _) async =>
                    (kind: MessageEditStatus.saved, message: null),
                onRefresh: () async => (revision: 1, deleted: false),
                onDelete: () async {
                  deleteCalls++;
                },
              ),
            ),
          ),
        );
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<PopupMenuItem<String>>(
                find.byType(PopupMenuItem<String>),
              )
              .map((item) => item.value),
          ['reply', 'edit', 'delete'],
        );
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        expect(find.text('Удалить сообщение?'), findsOneWidget);
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(deleteCalls, 0);
      },
    );
  }
}
