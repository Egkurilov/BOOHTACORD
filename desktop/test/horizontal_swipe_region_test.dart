import 'package:boohtacord_desktop/src/widgets/horizontal_swipe_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'recognizes only a deliberate horizontal swipe in its start zone',
    (tester) async {
      var right = 0;
      var left = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: HorizontalSwipeRegion(
                canStart: (position, size) => position.dx <= 56,
                onSwipeRight: () => right++,
                onSwipeLeft: () => left++,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(HorizontalSwipeRegion));
      await tester.dragFrom(
        rect.topLeft + const Offset(30, 100),
        const Offset(90, 4),
      );
      expect(right, 1);
      await tester.dragFrom(
        rect.topLeft + const Offset(90, 100),
        const Offset(90, 0),
      );
      expect(right, 1);
      await tester.dragFrom(
        rect.topLeft + const Offset(30, 100),
        const Offset(10, 0),
      );
      expect(right, 1);
      await tester.dragFrom(
        rect.topLeft + const Offset(30, 100),
        const Offset(80, 90),
      );
      expect(right, 1);
      await tester.dragFrom(
        rect.topLeft + const Offset(30, 100),
        const Offset(-70, 0),
      );
      expect(left, 1);
    },
  );
}
