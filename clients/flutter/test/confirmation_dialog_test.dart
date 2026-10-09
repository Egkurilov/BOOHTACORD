import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/widgets/confirmation_dialog.dart';
import 'package:boohtacord_desktop/src/widgets/topology_actions/create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('topology create dialog closes when the account changes', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..user = const SessionUser(accountId: 'account-1', role: 'ADMINISTRATOR')
      ..topology = const ChannelTopology(revision: 1, categories: []);
    state.permissions.snapshot = const PermissionSnapshot(
      accountId: 'account-1',
      role: GuildRole.administrator,
      revision: 1,
      values: {GuildPermission.categoryCreate: true},
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTopologyCreateDialog(context, state),
              child: const Text('Создать раздел'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Создать раздел'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    state.user = const SessionUser(
      accountId: 'account-2',
      role: 'ADMINISTRATOR',
    );
    state.session.changed();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirmation closes when its owning account context changes', (
    tester,
  ) async {
    final contextChanged = ValueNotifier<bool>(false);
    addTearDown(contextChanged.dispose);
    Future<bool?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showConfirmationDialog<bool>(
                context: context,
                cancelOn: contextChanged,
                shouldCancel: () => contextChanged.value,
                builder: (context) => AlertDialog(
                  title: const Text('Подтвердите удаление'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердите удаление'), findsOneWidget);

    contextChanged.value = true;
    await tester.pumpAndSettle();

    expect(find.text('Подтвердите удаление'), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('Enter activates the safe Cancel action in a confirmation', (
    tester,
  ) async {
    final cancelFocus = FocusNode();
    addTearDown(cancelFocus.dispose);
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConfirmationDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Опасное действие'),
                  actions: [
                    TextButton(
                      focusNode: cancelFocus,
                      autofocus: true,
                      onPressed: () {
                        result = false;
                        Navigator.pop(dialogContext, false);
                      },
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        result = true;
                        Navigator.pop(dialogContext, true);
                      },
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(cancelFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Опасное действие'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('confirmation stays modal until an explicit choice or Escape', (
    tester,
  ) async {
    final openerFocus = FocusNode();
    addTearDown(openerFocus.dispose);
    Future<bool?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: openerFocus,
              onPressed: () => result = showConfirmationDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Подтверждение действия'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Продолжить'),
                    ),
                  ],
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    openerFocus.requestFocus();
    await tester.pump();
    expect(openerFocus.hasFocus, isTrue);
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final title = find.text('Подтверждение действия');
    final route = ModalRoute.of(tester.element(title))!;
    expect(route.barrierDismissible, isFalse);
    expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(await result, isNull);
    expect(openerFocus.hasFocus, isTrue);
  });
}
