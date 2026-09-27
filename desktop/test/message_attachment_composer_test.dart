import 'dart:async';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/system_clipboard_paste.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_composer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pastes clipboard text at the selection and uploads its image', (
    tester,
  ) async {
    final state = _UploadState();
    addTearDown(state.dispose);
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      ),
    );
    final focusNode = FocusNode();
    final key = GlobalKey<MessageAttachmentComposerState>();
    final imageBytes = Uint8List.fromList([7, 8, 9]);
    var attachments = <MessageAttachment>[];
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => MessageAttachmentComposer(
              key: key,
              state: state,
              channelId: 'text-a',
              textController: controller,
              focusNode: focusNode,
              attachments: attachments,
              clipboardReader: () async => ClipboardPasteContent(
                text: 'pasted text',
                image: ClipboardImagePaste(
                  bytes: imageBytes,
                  fileName: 'clipboard-image.png',
                ),
              ),
              onChanged: (value) => rebuild(() => attachments = value),
              onPending: (_) {},
            ),
          ),
        ),
      ),
    );

    await key.currentState!.pasteFromClipboard();
    await tester.pumpAndSettle();

    expect(controller.text, 'hello pasted text');
    expect(controller.selection.extentOffset, 'hello pasted text'.length);
    expect(state.uploadedNames, ['clipboard-image.png']);
    expect(state.uploadedBytes.single, imageBytes);
    expect(state.targetChannels, ['text-a']);
    expect(attachments.single.originalName, 'clipboard-image.png');
  });

  testWidgets(
    'does not leak clipboard contents when the conversation changes',
    (tester) async {
      final gate = Completer<ClipboardPasteContent?>();
      final state = _UploadState();
      addTearDown(state.dispose);
      final controller = TextEditingController(text: 'unchanged');
      final focusNode = FocusNode();
      final key = GlobalKey<MessageAttachmentComposerState>();
      var target = 'text-a';
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, rebuild) => Column(
                children: [
                  TextButton(
                    onPressed: () => rebuild(() => target = 'text-b'),
                    child: const Text('Другой канал'),
                  ),
                  MessageAttachmentComposer(
                    key: key,
                    state: state,
                    channelId: target,
                    textController: controller,
                    focusNode: focusNode,
                    attachments: const [],
                    clipboardReader: () => gate.future,
                    onChanged: (_) {},
                    onPending: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final paste = key.currentState!.pasteFromClipboard();
      await tester.pump();
      await tester.tap(find.text('Другой канал'));
      await tester.pump();
      gate.complete(
        ClipboardPasteContent(
          text: 'secret clipboard text',
          image: ClipboardImagePaste(
            bytes: Uint8List.fromList([1]),
            fileName: 'clipboard-image.png',
          ),
        ),
      );
      await paste;
      await tester.pumpAndSettle();

      expect(controller.text, 'unchanged');
      expect(state.uploadedNames, isEmpty);
    },
  );

  testWidgets(
    'keeps co-pasted text when the image exceeds the attachment cap',
    (tester) async {
      final state = _UploadState();
      addTearDown(state.dispose);
      final controller = TextEditingController(text: 'caption');
      final focusNode = FocusNode();
      final key = GlobalKey<MessageAttachmentComposerState>();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageAttachmentComposer(
              key: key,
              state: state,
              channelId: 'text-a',
              textController: controller,
              focusNode: focusNode,
              attachments: const [],
              clipboardReader: () async => ClipboardPasteContent(
                text: ' + image',
                image: ClipboardImagePaste(
                  bytes: Uint8List(25000001),
                  fileName: 'clipboard-image.png',
                ),
              ),
              onChanged: (_) {},
              onPending: (_) {},
            ),
          ),
        ),
      );

      await key.currentState!.pasteFromClipboard();
      await tester.pumpAndSettle();

      expect(controller.text, 'caption + image');
      expect(state.uploadedNames, isEmpty);
      expect(
        find.text('Каждый файл должен быть не больше 25 МБ.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('retries a clipboard image in the captured private DM', (
    tester,
  ) async {
    final imageBytes = Uint8List.fromList([4, 5, 6]);
    final state = _UploadState()
      ..failedNames.add('clipboard-image.png')
      ..failureStatus = 507;
    addTearDown(state.dispose);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final key = GlobalKey<MessageAttachmentComposerState>();
    var attachments = <MessageAttachment>[];
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => MessageAttachmentComposer(
              key: key,
              state: state,
              directMessageId: 'dm-private',
              textController: controller,
              focusNode: focusNode,
              attachments: attachments,
              clipboardReader: () async => ClipboardPasteContent(
                image: ClipboardImagePaste(
                  bytes: imageBytes,
                  fileName: 'clipboard-image.png',
                ),
              ),
              onChanged: (value) => rebuild(() => attachments = value),
              onPending: (_) {},
            ),
          ),
        ),
      ),
    );

    await key.currentState!.pasteFromClipboard();
    await tester.pumpAndSettle();
    expect(find.text('clipboard-image.png · не загружено'), findsOneWidget);
    expect(find.textContaining('недостаточно места'), findsOneWidget);
    expect(state.targetChannels, ['dm-private']);

    state.failedNames.clear();
    await tester.tap(find.byTooltip('Повторить загрузку clipboard-image.png'));
    await tester.pumpAndSettle();

    expect(state.uploadedNames, ['clipboard-image.png', 'clipboard-image.png']);
    expect(state.uploadedBytes, [imageBytes, imageBytes]);
    expect(state.targetChannels, ['dm-private', 'dm-private']);
    expect(attachments.single.originalName, 'clipboard-image.png');
  });

  testWidgets('retains successful uploads and retries only the failed file', (
    tester,
  ) async {
    final state = _UploadState()
      ..failedNames.add('two.txt')
      ..failureStatus = 507;
    addTearDown(state.dispose);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var attachments = <MessageAttachment>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => MessageAttachmentComposer(
              state: state,
              channelId: 'text-a',
              textController: controller,
              focusNode: focusNode,
              attachments: attachments,
              filePicker: () async => [
                XFile.fromData(
                  Uint8List.fromList([1]),
                  path: '/private/tmp/one.txt',
                ),
                XFile.fromData(
                  Uint8List.fromList([2]),
                  path: '/private/tmp/two.txt',
                ),
              ],
              onChanged: (value) => rebuild(() => attachments = value),
              onPending: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Прикрепить файлы'));
    await tester.pumpAndSettle();
    expect(attachments.map((item) => item.originalName), ['one.txt']);
    expect(state.uploadedNames, ['one.txt', 'two.txt']);
    expect(find.text('two.txt · не загружено'), findsOneWidget);
    expect(find.textContaining('недостаточно места'), findsOneWidget);

    state.failedNames.clear();
    await tester.tap(find.byTooltip('Повторить загрузку two.txt'));
    await tester.pumpAndSettle();
    expect(attachments.map((item) => item.originalName), [
      'one.txt',
      'two.txt',
    ]);
    expect(state.uploadedNames, ['one.txt', 'two.txt', 'two.txt']);
    expect(state.targetChannels, everyElement('text-a'));
  });

  testWidgets('ignores an old file selection after conversation changes', (
    tester,
  ) async {
    final selected = Completer<List<XFile>>();
    final state = _UploadState();
    addTearDown(state.dispose);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var target = 'text-a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => Column(
              children: [
                TextButton(
                  onPressed: () => rebuild(() => target = 'text-b'),
                  child: const Text('Другой канал'),
                ),
                MessageAttachmentComposer(
                  state: state,
                  channelId: target,
                  textController: controller,
                  focusNode: focusNode,
                  attachments: const [],
                  filePicker: () => selected.future,
                  onChanged: (_) {},
                  onPending: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Прикрепить файлы'));
    await tester.pump();
    await tester.tap(find.text('Другой канал'));
    await tester.pump();
    selected.complete([
      XFile.fromData(Uint8List.fromList([1]), path: '/private/tmp/old.txt'),
    ]);
    await tester.pumpAndSettle();

    expect(state.uploadedNames, isEmpty);
  });

  testWidgets('shows progress for the active file before the server responds', (
    tester,
  ) async {
    final gate = Completer<void>();
    final state = _UploadState()..uploadGate = gate;
    addTearDown(state.dispose);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var attachments = <MessageAttachment>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => MessageAttachmentComposer(
              state: state,
              directMessageId: 'dm-a',
              textController: controller,
              focusNode: focusNode,
              attachments: attachments,
              filePicker: () async => [
                XFile.fromData(
                  Uint8List.fromList([1]),
                  path: '/private/tmp/progress.txt',
                ),
              ],
              onChanged: (value) => rebuild(() => attachments = value),
              onPending: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Прикрепить файлы'));
    await tester.pump();
    await tester.pump();
    expect(find.text('progress.txt · 50%'), findsOneWidget);
    expect(attachments, isEmpty);
    gate.complete();
    await tester.pumpAndSettle();
    expect(attachments.single.originalName, 'progress.txt');
    expect(state.targetChannels, ['dm-a']);
  });

  testWidgets('does not upload bytes after switching during file read', (
    tester,
  ) async {
    final readGate = Completer<void>();
    final state = _UploadState();
    addTearDown(state.dispose);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var target = 'text-a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => Column(
              children: [
                TextButton(
                  onPressed: () => rebuild(() => target = 'text-b'),
                  child: const Text('Другой канал'),
                ),
                MessageAttachmentComposer(
                  state: state,
                  channelId: target,
                  textController: controller,
                  focusNode: focusNode,
                  attachments: const [],
                  filePicker: () async => [_GatedFile(readGate)],
                  onChanged: (_) {},
                  onPending: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Прикрепить файлы'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Другой канал'));
    await tester.pump();
    readGate.complete();
    await tester.pumpAndSettle();

    expect(state.uploadedNames, isEmpty);
  });
}

class _GatedFile extends XFile {
  _GatedFile(this.gate)
    : super.fromData(Uint8List.fromList([1]), path: '/private/tmp/gated.txt');

  final Completer<void> gate;

  @override
  Future<Uint8List> readAsBytes() async {
    await gate.future;
    return Uint8List.fromList([1]);
  }
}

class _UploadState extends AppState {
  _UploadState() : super(ApiClient());

  final failedNames = <String>{};
  final uploadedNames = <String>[];
  final uploadedBytes = <Uint8List>[];
  final targetChannels = <String>[];
  Completer<void>? uploadGate;
  int? failureStatus;

  @override
  Future<MessageAttachment> uploadAttachment(
    String fileName,
    Uint8List bytes, {
    String? channelId,
    String? directMessageId,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedNames.add(fileName);
    uploadedBytes.add(bytes);
    targetChannels.add(channelId ?? directMessageId ?? 'missing');
    onProgress?.call(1, 2);
    await uploadGate?.future;
    if (failedNames.contains(fileName)) {
      throw ApiFailure('Ошибка загрузки', status: failureStatus);
    }
    onProgress?.call(2, 2);
    return MessageAttachment(
      id: 'attachment-${uploadedNames.length}',
      originalName: fileName,
      sizeBytes: bytes.length,
    );
  }
}
