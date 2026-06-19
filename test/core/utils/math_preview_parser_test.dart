import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/utils/math_preview_parser.dart';

void main() {
  group('MathPreviewParser Tests', () {
    test('sanitizeExpression cleans currency symbols and formats correctly', () {
      // IDR / Rp formatting
      expect(
        MathPreviewParser.sanitizeExpression('Rp 15.000 + Rp 5.000', 'Rp'),
        '15000+5000',
      );
      expect(
        MathPreviewParser.sanitizeExpression('Rp 12.500,50 * 2', 'Rp'),
        '12500.50*2',
      );

      // USD / $ formatting
      expect(
        MathPreviewParser.sanitizeExpression('\$ 10,000 + \$ 500', '\$'),
        '10000+500',
      );
      expect(
        MathPreviewParser.sanitizeExpression('\$ 12.50 * 2', '\$'),
        '12.50*2',
      );
    });

    test('hasOperators detects mathematical operators correctly', () {
      expect(MathPreviewParser.hasOperators('15000'), false);
      expect(MathPreviewParser.hasOperators('Rp 15.000'), false);
      expect(MathPreviewParser.hasOperators('15000 + 5000'), true);
      expect(MathPreviewParser.hasOperators('Rp 12.000 * 3'), true);
      expect(MathPreviewParser.hasOperators('1000/2'), true);
      expect(MathPreviewParser.hasOperators('100-50'), true);
    });

    test('evaluate computes simple calculations accurately', () {
      expect(MathPreviewParser.evaluate('15000+5000'), 20000.0);
      expect(MathPreviewParser.evaluate('15000-5000'), 10000.0);
      expect(MathPreviewParser.evaluate('2500*4'), 10000.0);
      expect(MathPreviewParser.evaluate('15000/3'), 5000.0);
    });

    test('evaluate handles operator precedence (MDAS) correctly', () {
      expect(MathPreviewParser.evaluate('10000+5000*2'), 20000.0);
      expect(MathPreviewParser.evaluate('15000/3+5000'), 10000.0);
      expect(MathPreviewParser.evaluate('10000-5000/2+1000'), 8500.0);
    });

    test('evaluate ignores trailing operator during active writing', () {
      // trailing operator should be silently trimmed to evaluate what has been typed so far
      expect(MathPreviewParser.evaluate('15000+'), 15000.0);
      expect(MathPreviewParser.evaluate('15000+5000*'), 20000.0);
    });

    test('evaluate returns null for invalid syntax or division by zero', () {
      expect(MathPreviewParser.evaluate('15000/0'), null);
      expect(MathPreviewParser.evaluate('abc+def'), null);
      expect(MathPreviewParser.evaluate(''), null);
    });
  });
}
