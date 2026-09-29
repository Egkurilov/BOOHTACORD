import 'package:boohtacord_desktop/src/widgets/android_system_gesture_exclusion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('boohtacord/system_gestures');

  testWidgets('updates Android edge exclusions and clears them on dispose', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AndroidSystemGestureExclusion(
          left: true,
          right: true,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(calls.last.method, 'setEdges');
    expect(calls.last.arguments, {'left': true, 'right': true});

    await tester.pumpWidget(
      const MaterialApp(
        home: AndroidSystemGestureExclusion(
          left: true,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(calls.last.arguments, {'left': true, 'right': false});

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls.last.arguments, {'left': false, 'right': false});
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('does not claim system gestures on non-Android platforms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      calls++;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AndroidSystemGestureExclusion(
          left: true,
          right: true,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
