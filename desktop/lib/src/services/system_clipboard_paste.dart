import 'dart:typed_data';

import 'package:clipboard/clipboard.dart';

class ClipboardImagePaste {
  const ClipboardImagePaste({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ClipboardPasteContent {
  const ClipboardPasteContent({this.text, this.image, this.imageError});

  final String? text;
  final ClipboardImagePaste? image;
  final String? imageError;
}

Future<ClipboardPasteContent?> readSystemClipboardPaste({
  Future<EnhancedClipboardData> Function()? readClipboard,
  int maxImageBytes = 25000000,
}) async {
  final data = await (readClipboard ?? FlutterClipboard.pasteRichText)();
  final bytes = data.imageBytes;
  final imageError = bytes != null && bytes.length > maxImageBytes
      ? 'Изображение из буфера должно быть не больше 25 МБ.'
      : null;
  final image = bytes == null || bytes.isEmpty || imageError != null
      ? null
      : ClipboardImagePaste(bytes: bytes, fileName: 'clipboard-image.png');
  if ((data.text == null || data.text!.isEmpty) &&
      image == null &&
      imageError == null) {
    return null;
  }
  return ClipboardPasteContent(
    text: data.text,
    image: image,
    imageError: imageError,
  );
}
