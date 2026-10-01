import 'package:boohtacord_desktop/src/widgets/sliding_drawer_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('drawer follows an eased open and close transition', (
    tester,
  ) async {
    var open = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: Stack(
                children: [
                  SlidingDrawerLayer(
                    visible: open,
                    side: SlidingDrawerSide.left,
                    width: 280,
                    child: const ColoredBox(
                      key: ValueKey('drawer-content'),
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    expect(find.byKey(const ValueKey('drawer-content')), findsNothing);

    update(() => open = true);
    await tester.pump();
    final drawer = find.byKey(const ValueKey('drawer-content'));
    final initial = tester.getRect(drawer).left;
    expect(initial, lessThan(0));
    await tester.pump(const Duration(milliseconds: 120));
    final middle = tester.getRect(drawer).left;
    expect(middle, greaterThan(initial));
    expect(middle, lessThan(0));
    await tester.pumpAndSettle();
    expect(tester.getRect(drawer).left, 0);

    update(() => open = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(drawer).left, lessThan(0));
    await tester.pumpAndSettle();
    expect(drawer, findsNothing);
  });
}
