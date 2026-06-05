import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/utils/math_parser.dart';

void main() {
  group('MathParser Offline Evaluation Tests', () {
    test('Evaluates simple numbers', () {
      expect(MathParser.eval('15000'), 15000.0);
      expect(MathParser.eval('12.000'), 12000.0);
      expect(MathParser.eval(' 250000 '), 250000.0);
    });

    test('Evaluates simple math operations', () {
      expect(MathParser.eval('15000 + 5000'), 20000.0);
      expect(MathParser.eval('15000 - 5000'), 10000.0);
      expect(MathParser.eval('2500 * 4'), 10000.0);
      expect(MathParser.eval('15000 / 3'), 5000.0);
    });

    test('Evaluates complex expressions with precedence', () {
      expect(MathParser.eval('10000 + 5000 * 2'), 20000.0);
      expect(MathParser.eval('(10000 + 5000) * 2'), 30000.0);
      expect(MathParser.eval('100000 - (20000 + 30000)'), 50000.0);
    });

    test('Handles thousand separators properly', () {
      expect(MathParser.eval('12.000 + 5.000'), 17000.0);
      expect(MathParser.eval('150.000 - 50.000'), 100000.0);
    });

    test('Returns null for invalid syntax', () {
      expect(MathParser.eval('15000+'), null);
      expect(MathParser.eval('15000/0'), null);
      expect(MathParser.eval('15000abc'), null);
      expect(MathParser.eval(''), null);
      expect(MathParser.eval('   '), null);
    });
  });
}
