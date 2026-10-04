import 'package:boohtacord_desktop/src/services/password_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates the required classes and exact length from an injectable source', () {
    var index = 0;
    final generator = SecurePasswordGenerator(nextByte: () => (index++) % 9);
    final password = generator.generate();
    expect(password, hasLength(generatedPasswordLength));
    expect(password, matches(RegExp(r'^[A-Za-z0-9!@#\$%^&*_+=-]+$')));
    expect(password, matches(RegExp(r'[A-Z]')));
    expect(password, matches(RegExp(r'[a-z]')));
    expect(password, matches(RegExp(r'\d')));
    expect(password, matches(RegExp(r'[!@#\$%^&*_+=-]')));
  });

  test('uses rejection sampling for out-of-range bytes', () {
    final values = <int>[255, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    var index = 0;
    final password = SecurePasswordGenerator(nextByte: () => values[index++ % values.length]).generate();
    expect(password, hasLength(24));
  });
}

