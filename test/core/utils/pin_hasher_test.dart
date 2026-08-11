import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/pin_hasher.dart';

void main() {
  group('PinHasher.hash', () {
    test('PIN yang sama menghasilkan hash yang sama (deterministik)', () {
      expect(PinHasher.hash('123456'), PinHasher.hash('123456'));
    });

    test('PIN berbeda menghasilkan hash berbeda', () {
      expect(PinHasher.hash('123456'), isNot(PinHasher.hash('654321')));
    });

    test('hash bukan teks PIN itu sendiri (tidak disimpan plaintext)', () {
      expect(PinHasher.hash('123456'), isNot('123456'));
    });
  });
}
