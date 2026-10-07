import 'package:boohtacord_desktop/src/features/admin/readiness/model.dart';
import 'package:boohtacord_desktop/src/features/admin/readiness/panel.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AdminReadinessProbe _probe({
  String status = 'ready',
  int? availableBytes,
  int? pendingRevocations,
}) => AdminReadinessProbe(
  status: status,
  reason: status == 'failed' ? 'Проверка недоступна' : null,
  sampledAt: DateTime.now().toUtc(),
  pendingRevocations: pendingRevocations,
  availableBytes: availableBytes,
  totalBytes: availableBytes == null ? null : availableBytes * 2,
  reservedBytes: null,
  protectedBytes: null,
  headroomBytes: availableBytes,
);

class _ReadinessApi extends ApiClient {
  _ReadinessApi(this.result);
  final AdminReadiness result;
  int loads = 0;

  @override
  Future<AdminReadiness> inspectAdminReadiness() async {
    loads++;
    return result;
  }
}

class _SequenceReadinessApi extends ApiClient {
  _SequenceReadinessApi(this.result);
  final AdminReadiness result;
  int loads = 0;

  @override
  Future<AdminReadiness> inspectAdminReadiness() async {
    loads++;
    if (loads > 1) throw StateError('Проверка недоступна');
    return result;
  }
}

AdminReadiness _result({String status = 'ready'}) => AdminReadiness(
  status: status,
  checkedAt: DateTime.now().toUtc(),
  database: _probe(pendingRevocations: 3),
  sfu: _probe(status: status == 'ready' ? 'ready' : 'failed'),
  storage: _probe(availableBytes: 4 * 1024 * 1024),
);

void main() {
  testWidgets('readiness panel shows probes and storage metrics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = _ReadinessApi(_result());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminReadinessPanel(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.loads, 1);
    expect(find.text('Сервисы готовы'), findsOneWidget);
    expect(find.text('PostgreSQL'), findsOneWidget);
    expect(find.text('LiveKit'), findsOneWidget);
    expect(find.text('Хранилище'), findsOneWidget);
    expect(find.text('Ожидают отзыва SFU · 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('degraded readiness remains explicit and refreshable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = _ReadinessApi(_result(status: 'degraded'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminReadinessPanel(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Есть проблемы готовности'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pumpAndSettle();
    expect(api.loads, 2);
  });

  testWidgets('refresh error never presents the previous result as fresh', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = _SequenceReadinessApi(_result());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminReadinessPanel(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pumpAndSettle();

    expect(find.text('Нет свежего подтверждения готовности'), findsOneWidget);
    expect(find.text('Сервисы готовы'), findsNothing);
    expect(find.text('устарело'), findsNWidgets(3));
  });
}
