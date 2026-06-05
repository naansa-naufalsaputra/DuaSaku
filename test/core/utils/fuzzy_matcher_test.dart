import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/utils/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher Tests', () {
    test('identical strings have distance 0 and similarity 1.0', () {
      expect(FuzzyMatcher.computeLevenshtein('makanan', 'makanan'), equals(0));
      expect(FuzzyMatcher.similarity('makanan', 'makanan'), equals(1.0));
    });

    test('case insensitive and trimmed matching works', () {
      expect(FuzzyMatcher.computeLevenshtein('  Makanan  ', 'makanan'), equals(0));
      expect(FuzzyMatcher.similarity('  Makanan  ', 'makanan'), equals(1.0));
    });

    test('calculates correct distance for insertion, deletion, and substitution', () {
      // substitution: 'a' -> 'u'
      expect(FuzzyMatcher.computeLevenshtein('kopi', 'kopu'), equals(1));
      expect(FuzzyMatcher.similarity('kopi', 'kopu'), equals(0.75));

      // insertion: adding 's'
      expect(FuzzyMatcher.computeLevenshtein('kopi', 'kopis'), equals(1));
      expect(FuzzyMatcher.similarity('kopi', 'kopis'), equals(0.8));

      // deletion: removing 'i'
      expect(FuzzyMatcher.computeLevenshtein('kopi', 'kop'), equals(1));
      expect(FuzzyMatcher.similarity('kopi', 'kop'), equals(0.75));
    });

    test('completely different strings have low similarity', () {
      final similarityScore = FuzzyMatcher.similarity('bensin', 'Transportasi');
      // Levenshtein distance between bensin and transportasi is 10. max length is 12.
      // 1.0 - (10/12) = 2/12 = 0.1667
      expect(similarityScore, closeTo(0.167, 0.001));
    });

    test('partial matches return logical similarity', () {
      final similarityScore = FuzzyMatcher.similarity('pecel lele', 'Makanan');
      // pecel lele (10 chars), makanan (7 chars).
      // Levenshtein: substitution/deletions. Let's make sure it computes a valid double.
      expect(similarityScore, lessThan(0.5));
    });

    test('empty inputs handled gracefully', () {
      expect(FuzzyMatcher.similarity('', ''), equals(1.0));
      expect(FuzzyMatcher.similarity('kopi', ''), equals(0.0));
      expect(FuzzyMatcher.similarity('', 'kopi'), equals(0.0));
    });
  });
}
