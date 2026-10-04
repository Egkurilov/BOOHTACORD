import 'package:boohtacord_desktop/src/services/password_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generates the required classes and exact length from an injectable source',
    () {
      var index = 0;
      final generator = SecurePasswordGenerator(nextByte: () => (index++) % 9);
      final password = generator.generate();
      expect(password.length, generatedPasswordLength);
      for (final pattern in [
        r'^[A-Za-z0-9!@#\$%^&*_+=-]{24}$',
        r'[A-Z]',
        r'[a-z]',
        r'\d',
        r'[!@#\$%^&*_+=-]',
      ]) {
        expect(RegExp(pattern).hasMatch(password), isTrue);
      }
      index = 0;
      expect(password == generator.generate(), isTrue);
    },
  );

  test('uses rejection sampling for out-of-range bytes', () {
    final values = <int>[
      234,
      255,
      233,
      234,
      255,
      233,
      250,
      255,
      249,
      252,
      255,
      251,
      222,
      255,
      221,
    ];
    var index = 0;
    final password = SecurePasswordGenerator(
      nextByte: () => index < values.length ? values[index++] : (index++, 0).$2,
    ).generate();
    expect(index, 57);
    for (final char in ['Z', 'z', '9', '=']) {
      expect(password.contains(char), isTrue);
    }
  });

  test('default secure RNG satisfies the same contract', () {
    final password = SecurePasswordGenerator().generate();
    expect(
      RegExp(r'^[A-Za-z0-9!@#\$%^&*_+=-]{24}$').hasMatch(password),
      isTrue,
    );
  });

  test('rejects invalid injected byte values', () {
    for (final invalid in [-1, 256]) {
      expect(
        () => SecurePasswordGenerator(nextByte: () => invalid).generate(),
        throwsRangeError,
      );
    }
  });
}
