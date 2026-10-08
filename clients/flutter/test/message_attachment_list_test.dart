import 'dart:async';
import 'dart:convert';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=private',
    });
  });

  testWidgets('opens a protected image preview and presents deleted state', (
    tester,
  ) async {
    final requests = <String>[];
    final state = AppState(
      ApiClient(
        client: MockClient((request) async {
          requests.add(
            '${request.url.path}|${request.url.query}|${request.headers['cookie']}',
          );
          return httpResponse(404);
        }),
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    expect(requests, [
      '/api/v1/channels/channel-1/attachments/attachment-1/preview||session=private',
    ]);

    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вложение удалено или недоступно.'), findsOneWidget);
    expect(requests, hasLength(2));
    expect(requests.last, contains('/preview||session=private'));
    expect(
      find.byKey(const ValueKey('protected-image-viewer-download')),
      findsNothing,
    );
    expect(find.byTooltip('Скачать photo.png'), findsOneWidget);
    expect(find.byTooltip('Закрыть просмотр изображения'), findsOneWidget);
  });

  testWidgets('announces the image viewer route and image alt text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      const onePixelPng =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
      final state = AppState(
        ApiClient(
          client: MockClient(
            (_) async => http.Response.bytes(
              base64Decode(onePixelPng),
              200,
              headers: {'content-type': 'image/png'},
            ),
          ),
        ),
      );
      addTearDown(state.dispose);

      await tester.pumpWidget(_app(state));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Открыть изображение photo.png'),
        findsOneWidget,
      );
      expect(find.byTooltip('Открыть изображение photo.png'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('attachment-preview-attachment-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Просмотр изображения photo.png'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.image == true &&
              widget.properties.label == 'photo.png',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Escape closes the image viewer and restores opener focus', (
    tester,
  ) async {
    final state = AppState(
      ApiClient(client: MockClient((_) async => httpResponse(404))),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final openerFocus = tester.binding.focusManager.primaryFocus;
    expect(openerFocus, isNotNull);
    expect(
      openerFocus?.context?.findAncestorWidgetOfExactType<InkWell>()?.key,
      const ValueKey('attachment-preview-attachment-1'),
    );

    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<IconButton>()
          ?.tooltip,
      'Закрыть просмотр изображения',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final dialogControlFocus = tester.binding.focusManager.primaryFocus;
    expect(dialogControlFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus, same(dialogControlFocus));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(tester.binding.focusManager.primaryFocus, same(openerFocus));
  });

  testWidgets('announces image preview loading and unavailable states', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requestCount = 0;
    final state = AppState(
      ApiClient(
        client: MockClient((_) async {
          requestCount++;
          return requestCount == 1 ? httpResponse(404) : response.future;
        }),
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Загружаем изображение…',
      ),
      findsOneWidget,
    );

    response.complete(httpResponse(404));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Вложение удалено или недоступно.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers retry for transient protected preview failures', (
    tester,
  ) async {
    var dialogRequest = false;
    var transientAttempts = 0;
    final state = AppState(
      ApiClient(
        client: MockClient((request) async {
          if (!dialogRequest) return httpResponse(404);
          transientAttempts++;
          return httpResponse(transientAttempts == 1 ? 503 : 404);
        }),
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    dialogRequest = true;
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить изображение.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(transientAttempts, 2);
    expect(find.text('Вложение удалено или недоступно.'), findsOneWidget);
  });

  testWidgets('keeps the image viewer inside a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
    final state = AppState(
      ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            base64Decode(onePixelPng),
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    final dialog = tester.getRect(find.byType(Dialog));
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.top, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(320));
    expect(dialog.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the web full-screen protected image viewer on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
    final state = AppState(
      ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            base64Decode(onePixelPng),
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('protected-image-viewer'))),
      const Size(1440, 900),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('protected-image-viewer-header')),
      ),
      const Size(1440, 64),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('protected-image-viewer-header')),
        matching: find.text('photo.png'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('protected-image-viewer-file-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('protected-image-viewer-download')),
      findsOneWidget,
    );
    expect(
      find.text('Изображение целиком · Масштаб по размеру окна'),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the web compact protected image viewer controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(client: MockClient((_) async => httpResponse(404))),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('protected-image-viewer'))),
      const Size(390, 844),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('protected-image-viewer-header')),
      ),
      const Size(390, 56),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('protected-image-viewer-close')),
      ),
      const Size(44, 44),
    );
    expect(find.text('Скачать'), findsNothing);
    expect(find.text('Вложение удалено или недоступно.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps compact viewer controls clear of system insets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(client: MockClient((_) async => httpResponse(404))),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('protected-image-viewer-header')),
          )
          .dy,
      24,
    );
    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('protected-image-viewer-footer')),
          )
          .dy,
      lessThanOrEqualTo(820),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides download and offers retry when image decoding fails', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      ),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить изображение.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('protected-image-viewer-download')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the web file-card fallback when thumbnail loading fails', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(client: MockClient((_) async => httpResponse(404))),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(
        find.byKey(const ValueKey('attachment-card-attachment-1')),
      ),
      const Size(340, 62),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('attachment-preview-attachment-1')),
      ),
      const Size(44, 44),
    );
    expect(
      find.bySemanticsLabel('Открыть изображение photo.png'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вложение удалено или недоступно.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses the web file-card fallback when thumbnail bytes are invalid',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final state = AppState(
        ApiClient(
          client: MockClient(
            (_) async => http.Response.bytes(
              [1, 2, 3],
              200,
              headers: {'content-type': 'image/png'},
            ),
          ),
        ),
      );
      addTearDown(state.dispose);

      await tester.pumpWidget(_app(state));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(
          find.byKey(const ValueKey('attachment-card-attachment-1')),
        ),
        const Size(340, 62),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('attachment-preview-attachment-1')),
        ),
        const Size(44, 44),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('matches web image attachment geometry on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(client: MockClient((_) async => imageResponse())),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pump();

    final card = tester.getSize(
      find.byKey(const ValueKey('attachment-card-attachment-1')),
    );
    final preview = tester.getSize(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    expect(card, const Size(440, 238));
    expect(preview, const Size(438, 200));
  });

  testWidgets('matches web image attachment geometry on compact layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(client: MockClient((_) async => imageResponse())),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(_app(state));
    await tester.pump();

    final card = tester.getSize(
      find.byKey(const ValueKey('attachment-card-attachment-1')),
    );
    final preview = tester.getSize(
      find.byKey(const ValueKey('attachment-preview-attachment-1')),
    );
    expect(card, const Size(390, 182));
    expect(preview, const Size(388, 144));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps generic file cards at the web desktop width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(
      ApiClient(client: MockClient((_) async => httpResponse(404))),
    );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _app(
        state,
        attachments: const [
          MessageAttachment(
            id: 'file-1',
            originalName: 'report.pdf',
            sizeBytes: 1500,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('attachment-card-file-1'))),
      const Size(340, 62),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(AppState state, {List<MessageAttachment>? attachments}) =>
    MaterialApp(
      home: Scaffold(
        body: MessageAttachmentList(
          state: state,
          parentPath: '/channels/channel-1',
          attachments:
              attachments ??
              const [
                MessageAttachment(
                  id: 'attachment-1',
                  originalName: 'photo.png',
                  sizeBytes: 10,
                ),
              ],
        ),
      ),
    );

http.Response httpResponse(int status) => http.Response(
  jsonEncode({
    'error': {'code': 'ATTACHMENT_UNAVAILABLE', 'message': 'Unavailable'},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response imageResponse() => http.Response.bytes(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  ),
  200,
  headers: {'content-type': 'image/png'},
);
