import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:boohtacord_desktop/src/features/voice/screen_preview/client.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/uploader.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=preview-test',
    });
  });

  test('accepts only bounded JPEG-shaped preview bytes', () {
    expect(validScreenPreviewJpeg(Uint8List.fromList([0xff, 0xd8, 1, 0xff, 0xd9])), isTrue);
    expect(validScreenPreviewJpeg(Uint8List(14 * 1024 + 1)), isFalse);
    expect(validScreenPreviewJpeg(Uint8List.fromList([0xff, 0xd8, 1, 0])), isFalse);
  });

  test('screen preview cap matches the backend contract', () {
    expect(maxScreenPreviewBytes, 14 * 1024);
  });

  test('uploads and invalidates through the private session routes', () async {
    final requests = <http.Request>[];
    const lease = 'd9428888-122b-4a50-8c5c-5b9393a4e5f1';
    const generation = 'e35d15a4-6d8c-4a6e-a6b9-78de899631f8';
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'schema_version': 1, 'generation_id': generation}),
            201,
          );
        }
        return http.Response('', 204);
      }),
    );
    final client = ScreenPreviewClient(api.transport);
    final resolved = await client.begin(lease);
    final jpeg = Uint8List.fromList([0xff, 0xd8, 1, 0xff, 0xd9]);
    await client.upload(lease, resolved, 1, jpeg);
    await client.invalidate(lease, resolved);

    expect(requests.map((request) => request.method), ['POST', 'PUT', 'DELETE']);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/voice/leases/$lease/screen-previews/v1',
      '/api/v1/voice/leases/$lease/screen-previews/v1/$generation',
      '/api/v1/voice/leases/$lease/screen-previews/v1/$generation',
    ]);
    expect(requests[1].headers['content-type'], 'image/jpeg');
    expect(requests[1].headers['x-screen-preview-revision'], '1');
    expect(requests[1].bodyBytes, jpeg);
    expect(requests.every((request) => request.headers['cookie'] == 'session=preview-test'), isTrue);
  });

  test('sender keeps one upload in flight and only the newest queued frame', () async {
    const lease = 'd9428888-122b-4a50-8c5c-5b9393a4e5f1';
    const generation = 'e35d15a4-6d8c-4a6e-a6b9-78de899631f8';
    final firstUpload = Completer<void>();
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final markers = <int>[];
    var uploads = 0;
    final api = ApiClient(client: MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'schema_version': 1, 'generation_id': generation}),
          201,
        );
      }
      if (request.method == 'PUT') {
        markers.add(request.bodyBytes[2]);
        uploads++;
        if (uploads == 1) {
          firstStarted.complete();
          await firstUpload.future;
        } else if (uploads == 2) {
          secondStarted.complete();
        }
      }
      return http.Response('', 204);
    }));
    final sender = LatestScreenPreviewUploader(ScreenPreviewClient(api.transport));
    Uint8List frame(int marker) => Uint8List.fromList([0xff, 0xd8, marker, 0xff, 0xd9]);

    sender.offer(lease, frame(1));
    await firstStarted.future.timeout(const Duration(seconds: 2));
    sender.offer(lease, frame(2));
    sender.offer(lease, frame(3));
    firstUpload.complete();
    await secondStarted.future.timeout(const Duration(seconds: 2));
    await sender.stop();

    expect(markers, [1, 3]);
  });
}
