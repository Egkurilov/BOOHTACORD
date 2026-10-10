import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/model.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/lifecycle/state.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'admin_topology_fake_api.dart';

import 'package:boohtacord_desktop/src/features/admin/role_permissions/feedback/handler.dart';

class _RolePermissionsTestApi extends TopologyTestApi {
  _RolePermissionsTestApi({
    this.saveStatus = 409,
    this.saveGate,
    this.loadFailures = const {},
    this.loadGates = const {},
  });

  final int? saveStatus;
  final Completer<void>? saveGate;
  final Map<int, int> loadFailures;
  final Map<int, Completer<RolePolicyPage>> loadGates;
  int saveCalls = 0;
  int loads = 0;

  @override
  Future<RolePolicyPage> loadRolePolicies() async {
    loads++;
    final failure = loadFailures[loads];
    if (failure != null) throw ApiFailure('fixture-$failure', status: failure);
    final gate = loadGates[loads];
    if (gate != null) return gate.future;
    final permissions = {
      for (final permission in GuildPermission.values)
        permission:
            loads > 1 &&
            saveStatus != 403 &&
            permission == GuildPermission.textCreate,
    };
    return RolePolicyPage(1, [
      RolePolicy(
        role: GuildRole.administrator,
        displayName: 'Администратор',
        editable: false,
        permissions: permissions,
      ),
      RolePolicy(
        role: GuildRole.member,
        displayName: 'Пользователь',
        editable: true,
        permissions: permissions,
      ),
    ]);
  }

  @override
  Future<void> saveMemberRolePolicy({
    required int revision,
    required Map<GuildPermission, bool> values,
    required bool confirmDeleteGrants,
  }) async {
    saveCalls++;
    await saveGate?.future;
    if (saveStatus != null) {
      throw ApiFailure('fixture-$saveStatus', status: saveStatus);
    }
  }
}

void main() {
  test('role request feedback localizes offline and timeout outcomes', () {
    expect(
      rolePermissionsFailureMessage(http.ClientException('Failed to fetch')),
      'Нет соединения с сервером. Проверьте подключение.',
    );
    expect(
      rolePermissionsFailureMessage(TimeoutException('timeout')),
      'Сервер не ответил вовремя. Повторите попытку.',
    );
  });

  testWidgets('admin permission checkboxes have a visible Material surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = _RolePermissionsTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();

    final permissionTile = find.widgetWithText(
      CheckboxListTile,
      'Создавать текстовые каналы',
    );
    expect(
      find.byType(CheckboxListTile),
      findsNWidgets(GuildPermission.values.length),
    );
    expect(tester.takeException(), isNull);
    expect(tester.widget<CheckboxListTile>(permissionTile).value, isFalse);

    await tester.tap(permissionTile);
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(permissionTile).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role conflict exposes before/current/proposed review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = _RolePermissionsTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Создавать текстовые каналы'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(api.loads, greaterThan(1));
    expect(
      find.byKey(const ValueKey('admin-role-conflict-review')),
      findsOneWidget,
    );
    expect(find.textContaining('Текстовые · создавать'), findsOneWidget);
    expect(find.text('Принять серверные данные'), findsOneWidget);
    expect(find.text('Применить мой draft'), findsOneWidget);
  });

  testWidgets('role conflict does not show stale values when refresh fails', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = _RolePermissionsTestApi(
      saveStatus: 409,
      loadFailures: const {2: 503},
    );
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();
    final permission = find.widgetWithText(
      CheckboxListTile,
      'Создавать текстовые каналы',
    );
    await tester.tap(permission);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(api.loads, 2);
    expect(
      find.byKey(const ValueKey('admin-role-conflict-review')),
      findsNothing,
    );
    expect(
      find.text('Сервис временно не отвечает. Попробуйте позже.'),
      findsOneWidget,
    );
    expect(tester.widget<CheckboxListTile>(permission).value, isTrue);

    await tester.drag(find.byType(ListView).last, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Обновить'));
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(api.loads, 3);
    expect(
      find.byKey(const ValueKey('admin-role-conflict-review')),
      findsOneWidget,
    );
    expect(find.textContaining('Текстовые · создавать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlapping role refreshes ignore the older response', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final older = Completer<RolePolicyPage>();
    final latest = Completer<RolePolicyPage>();
    final api = _RolePermissionsTestApi(loadGates: {2: older, 3: latest});
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();
    final roleState = tester.state<RolePermissionsState>(
      find.byType(RolePermissionsPanel),
    );
    final staleRequest = roleState.loadRoles(reset: false);
    final currentRequest = roleState.loadRoles(reset: false);
    expect(api.loads, 3);

    latest.complete(_rolePage(revision: 3, textCreate: true));
    expect(await currentRequest, isTrue);
    older.complete(_rolePage(revision: 2, textCreate: false));
    expect(await staleRequest, isFalse);
    expect(roleState.baseline[GuildPermission.textCreate], isTrue);
    expect(roleState.revision, 3);
  });

  for (final status in [403, 404, 429, 503]) {
    testWidgets(
      'role save $status preserves the draft and applies the retry policy',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final api = _RolePermissionsTestApi(saveStatus: status);
        final state = AppState(api)..topology = api.current;
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminScreen(state: state)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
        await tester.pumpAndSettle();

        final permission = find.widgetWithText(
          CheckboxListTile,
          'Создавать текстовые каналы',
        );
        await tester.tap(permission);
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
        final save = find.text('Сохранить');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        final expectedError = switch (status) {
          403 => 'Нет доступа к изменению разрешений этой роли.',
          404 => 'Роль не найдена. Обновите данные и повторите попытку.',
          429 =>
            'Слишком много запросов. Подождите немного и повторите попытку.',
          _ => 'Сервис временно не отвечает. Попробуйте позже.',
        };
        final error = find.text(expectedError);
        expect(error, findsOneWidget);
        expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
        expect(tester.widget<CheckboxListTile>(permission).value, isTrue);
        final saveButton = find.ancestor(
          of: save,
          matching: find.byType(FilledButton),
        );
        if (status == 403) {
          expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
          await tester.drag(find.byType(ListView).last, const Offset(0, 700));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Обновить'));
          await tester.tap(find.text('Обновить'));
          await tester.pumpAndSettle();
          expect(api.loads, 2);
          expect(tester.widget<CheckboxListTile>(permission).value, isTrue);
          await tester.drag(find.byType(ListView).last, const Offset(0, -700));
          await tester.pumpAndSettle();
          await tester.ensureVisible(save);
          expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
        } else {
          expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
        }
        expect(api.saveCalls, 1);
        expect(
          api.loads,
          status == 403 ? 2 : 1,
          reason: 'errors never trigger an automatic reload; denial is rechecked only after refresh',
        );
      },
    );
  }

  testWidgets('role save announces one pending and one success status', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final gate = Completer<void>();
    final api = _RolePermissionsTestApi(saveStatus: null, saveGate: gate);
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();
    final permission = find.widgetWithText(
      CheckboxListTile,
      'Создавать текстовые каналы',
    );
    await tester.tap(permission);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final save = find.text('Сохранить');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    final pending = find.text('Сохраняем…');
    expect(pending, findsOneWidget);
    expect(tester.getSemantics(pending).flagsCollection.isLiveRegion, isTrue);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    final success = find.text('Разрешения сохранены.');
    expect(success, findsOneWidget);
    expect(tester.getSemantics(success).flagsCollection.isLiveRegion, isTrue);
    expect(api.saveCalls, 1);
    expect(api.loads, 2);
  });
}

RolePolicyPage _rolePage({required int revision, required bool textCreate}) {
  final permissions = {
    for (final permission in GuildPermission.values)
      permission: permission == GuildPermission.textCreate && textCreate,
  };
  return RolePolicyPage(revision, [
    RolePolicy(
      role: GuildRole.administrator,
      displayName: 'Администратор',
      editable: false,
      permissions: permissions,
    ),
    RolePolicy(
      role: GuildRole.member,
      displayName: 'Пользователь',
      editable: true,
      permissions: permissions,
    ),
  ]);
}
