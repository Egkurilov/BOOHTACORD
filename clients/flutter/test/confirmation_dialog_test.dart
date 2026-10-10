import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/workspace/topology_mutations/model.dart';
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

  testWidgets(
    'topology create keeps its draft after 403/409/503 and locks submit',
    (tester) async {
      final api = _TopologyCreateApi();
      final state = AppState(api)
        ..user = const SessionUser(
          accountId: 'account-1',
          role: 'ADMINISTRATOR',
        )
        ..topology = const ChannelTopology(revision: 1, categories: []);
      state.permissions.snapshot = const PermissionSnapshot(
        accountId: 'account-1',
        role: GuildRole.administrator,
        revision: 1,
        values: {
          GuildPermission.textCreate: true,
          GuildPermission.textDelete: false,
          GuildPermission.voiceCreate: true,
          GuildPermission.voiceDelete: false,
          GuildPermission.categoryCreate: true,
          GuildPermission.categoryDelete: false,
        },
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
      final field = find.byType(TextField);
      await tester.enterText(field, 'Новый раздел');
      final submit = find.byType(FilledButton);

      api.firstCategoryRequest = Completer<TopologyCommandResult>();
      await tester.tap(submit);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      expect(api.categoryCreateCalls, 1);
      api.firstCategoryRequest!.completeError(
        const ApiFailure('Список изменился (409).', status: 409),
      );
      await tester.pumpAndSettle();
      expect(find.text('Список изменился (409).'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'Новый раздел');

      for (final failure in [
        const ApiFailure('Недостаточно прав (403).', status: 403),
        const ApiFailure('Сервис временно недоступен (503).', status: 503),
      ]) {
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text(failure.message), findsOneWidget);
        expect(
          tester.widget<TextField>(field).controller!.text,
          'Новый раздел',
        );
      }

      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.categoryCreateCalls, 4);
    },
  );

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
    expect(tester.getSemantics(title).label, 'Подтверждение действия');
    expect(tester.getSemantics(find.text('Отмена')).label, 'Отмена');
    expect(tester.getSemantics(find.text('Продолжить')).label, 'Продолжить');
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

class _TopologyCreateApi extends ApiClient {
  Completer<TopologyCommandResult>? firstCategoryRequest;
  int categoryCreateCalls = 0;
  bool firstCategoryRequestUsed = false;

  @override
  Future<TopologyCommandResult> createMemberCategory(
    String name,
    String requestId,
  ) async {
    categoryCreateCalls++;
    final pending = firstCategoryRequest;
    if (pending != null && !firstCategoryRequestUsed) {
      firstCategoryRequestUsed = true;
      return pending.future;
    }
    if (categoryCreateCalls == 2) {
      throw const ApiFailure('Недостаточно прав (403).', status: 403);
    }
    if (categoryCreateCalls == 3) {
      throw const ApiFailure('Сервис временно недоступен (503).', status: 503);
    }
    return TopologyCommandResult(
      requestId: requestId,
      revision: 2,
      resourceId: 'category-2',
      state: 'ACTIVE',
    );
  }

  @override
  Future<ChannelTopology> topology() async =>
      const ChannelTopology(revision: 2, categories: []);
}
