import 'dart:math';

const generatedPasswordLength = 24;
const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _lower = 'abcdefghijklmnopqrstuvwxyz';
const _digits = '0123456789';
const _symbols = '!@#\$%^&*_-+=';
const _alphabet = '$_upper$_lower$_digits$_symbols';

typedef PasswordRandomByteSource = int Function();

class SecurePasswordGenerator {
  SecurePasswordGenerator({PasswordRandomByteSource? nextByte})
    : _nextByte = nextByte ?? _secureByteSource();

  static PasswordRandomByteSource _secureByteSource() {
    final random = Random.secure();
    return () => random.nextInt(256);
  }

  final PasswordRandomByteSource _nextByte;

  int _index(int max) {
    final limit = 256 - (256 % max);
    var byte = 0;
    do { byte = _nextByte() & 0xff; } while (byte >= limit);
    return byte % max;
  }

  String _pick(String alphabet) => alphabet[_index(alphabet.length)];

  String generate() {
    final result = <String>[
      _pick(_upper),
      _pick(_lower),
      _pick(_digits),
      _pick(_symbols),
    ];
    while (result.length < generatedPasswordLength) result.add(_pick(_alphabet));
    for (var index = result.length - 1; index > 0; index -= 1) {
      final swap = _index(index + 1);
      final current = result[index];
      result[index] = result[swap];
      result[swap] = current;
    }
    return result.join();
  }
}

