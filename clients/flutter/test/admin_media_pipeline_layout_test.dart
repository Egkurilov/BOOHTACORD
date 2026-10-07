import 'package:boohtacord_desktop/src/features/admin/media_metrics/pipeline.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pipeline columns follow constrained parent width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final sample = AdminScreenSample(
      platform: 'android_native',
      direction: 'receiver',
      state: 'playing',
      sampledAtUtc: DateTime.now().toUtc(),
      frameWidth: 540,
      frameHeight: 1170,
    );

    for (final width in [390.0, 600.0, 840.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: AdminMediaPipeline(sample: sample),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stage = find.byKey(const ValueKey('media-stage-Отправка'));
      final viewportWidth = MediaQuery.sizeOf(tester.element(stage)).width;
      expect(
        viewportWidth,
        1200,
      );
      final parentWidth = tester.getSize(find.byType(AdminMediaPipeline)).width;
      expect(parentWidth, width);
      final rows = [
        for (final name in ['Отправка', 'Приём', 'Декодирование', 'Показ'])
          tester.getTopLeft(find.byKey(ValueKey('media-stage-$name'))).dy,
      ].toSet();
      expect(rows.length, width < 420 ? 4 : width < 840 ? 2 : 1);
      expect(tester.takeException(), isNull);
    }
  });
}
