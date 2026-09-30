import 'package:boohtacord_desktop/src/services/screen_share_metrics_generation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new track generation is not blocked by an old pending sample', () {
    final gate = ScreenShareMetricsGenerationGate();
    final oldGeneration = gate.nextGeneration();

    expect(gate.tryEnter(oldGeneration), isTrue);

    final currentGeneration = gate.nextGeneration();
    expect(gate.tryEnter(currentGeneration), isTrue);
  });

  test(
    'late completion from old generation does not release current sample',
    () {
      final gate = ScreenShareMetricsGenerationGate();
      final oldGeneration = gate.nextGeneration();
      expect(gate.tryEnter(oldGeneration), isTrue);

      final currentGeneration = gate.nextGeneration();
      expect(gate.tryEnter(currentGeneration), isTrue);
      gate.leave(oldGeneration);

      expect(gate.tryEnter(currentGeneration), isFalse);
      gate.leave(currentGeneration);
      expect(gate.tryEnter(currentGeneration), isTrue);
    },
  );
}
