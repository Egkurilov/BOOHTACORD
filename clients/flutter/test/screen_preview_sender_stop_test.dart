import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/features/voice/screen_preview/client.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/uploader.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie': 'session=preview-test',
    });
  });

  test('concurrent stops await one completed generation invalidation', () async {
    const lease = 'd9428888-122b-4a50-8c5c-5b9393a4e5f1';
    const generation = 'e35d15a4-6d8c-4a6e-a6b9-78de899631f8';
    final uploadStarted = Completer<void>();
    final finishUpload = Completer<void>();
    final deleteStarted = Completer<void>();
    final finishDelete = Completer<void>();
    var deletes = 0;
    final api = ApiClient(client: MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({
          'schema_version': 1, 'generation_id': generation,
        }), 201);
      }
      if (request.method == 'PUT') {
        uploadStarted.complete();
        await finishUpload.future;
      }
      if (request.method == 'DELETE') {
        deletes++;
        deleteStarted.complete();
        await finishDelete.future;
      }
      return http.Response('', 204);
    }));
    final sender = LatestScreenPreviewUploader(ScreenPreviewClient(api.transport));
    sender.offer(lease, Uint8List.fromList([0xff, 0xd8, 1, 0xff, 0xd9]));
    await uploadStarted.future.timeout(const Duration(seconds: 2));
    var completedStops = 0;
    final first = sender.stop().then((_) => completedStops++);
    finishUpload.complete();
    await deleteStarted.future.timeout(const Duration(seconds: 2));
    final second = sender.stop().then((_) => completedStops++);
    final secondFinished = second.then((_) => true);
    expect(await Future.any<bool>([
      secondFinished,
      Future<bool>.delayed(const Duration(milliseconds: 10), () => false),
    ]), isFalse);
    finishDelete.complete();
    await Future.wait([first, second]);
    expect(completedStops, 2);
    expect(deletes, 1);
  });
}
