import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/utils/dart_tokenizer.dart';

void main() {
  group('DartTokenizer Tests', () {
    late DartTokenizer tokenizer;

    setUp(() {
      final mockMetadata = {
        'max_len': 6,
        'vocabulary': ['', '[UNK]', 'rp', 'beli', 'kopi', 'gajian', '1.5jt', '25k']
      };
      tokenizer = DartTokenizer.fromJson(mockMetadata);
    });

    test('should lowercase input', () {
      final result = tokenizer.tokenize('BELI KOPI');
      // "beli" -> index 3, "kopi" -> index 4, padded with 0 to length 6
      expect(result, equals([3, 4, 0, 0, 0, 0]));
    });

    test('should strip punctuation matching Keras standard', () {
      final result = tokenizer.tokenize('beli kopi!');
      expect(result, equals([3, 4, 0, 0, 0, 0]));

      final resultWithCommas = tokenizer.tokenize('beli, kopi.');
      expect(resultWithCommas, equals([3, 4, 0, 0, 0, 0]));
    });

    test('should map unknown words to dynamic UNK token index', () {
      final result = tokenizer.tokenize('beli martabak');
      // "beli" -> index 3, "martabak" is unknown -> [UNK] index 1
      expect(result, equals([3, 1, 0, 0, 0, 0]));
    });

    test('should handle padding correctly', () {
      final result = tokenizer.tokenize('beli');
      expect(result, equals([3, 0, 0, 0, 0, 0]));
    });

    test('should handle truncation correctly', () {
      final result = tokenizer.tokenize('beli kopi rp gajian rp gajian rp');
      // max_len is 6, so it should keep exactly 6 items
      expect(result.length, equals(6));
      expect(result, equals([3, 4, 2, 5, 2, 5]));
    });

    test('should preserve dots and commas in raw input text (checked via separate logic)', () {
      // String split by whitespace before tokenizer logic should keep 1.5jt intact
      final rawTokens = 'beli kopi 1.5jt'.toLowerCase().split(RegExp(r'\s+'));
      expect(rawTokens, contains('1.5jt'));
    });
  });
}
