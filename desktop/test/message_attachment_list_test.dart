import 'dart:convert';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie': 'session=private',
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
}

Widget _app(AppState state) => MaterialApp(
  home: Scaffold(
    body: MessageAttachmentList(
      state: state,
      parentPath: '/channels/channel-1',
      attachments: const [
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
