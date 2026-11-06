import 'package:flutter_test/flutter_test.dart';

import 'package:zaznamity/shared/amount_parser.dart';
import 'package:zaznamity/shared/money_formatter.dart';

void main() {
  group('parseAmount', () {
    test('accepts comma and dot decimals', () {
      expect(parseAmount('12,50'), 12.5);
      expect(parseAmount('12.50'), 12.5);
      expect(parseAmount('.5'), 0.5);
      expect(parseAmount('5,'), 5.0);
    });

    test('handles thousands grouping', () {
      expect(parseAmount('1,234.56'), 1234.56);
      expect(parseAmount('1.234,56'), 1234.56);
      expect(parseAmount('1 234,56'), 1234.56);
      expect(parseAmount('1,234,567'), 1234567.0);
      expect(parseAmount('1.234.567,89'), 1234567.89);
    });

    test('ignores currency symbols and spaces', () {
      expect(parseAmount('€ 1 234,5'), 1234.5);
      expect(parseAmount('  42  '), 42.0);
    });

    test('rejects invalid input', () {
      expect(parseAmount(null), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('.'), isNull);
      expect(parseAmount('1.5.3'), isNull);
      expect(parseAmount('1,2,3'), isNull);
    });

    test('negatives only when allowed', () {
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('(5)'), isNull);
      expect(parseAmount('-5', allowNegative: true), -5.0);
      expect(parseAmount('(5,5)', allowNegative: true), -5.5);
    });
  });

  group('Money', () {
    test('format puts the symbol where the currency expects it', () {
      expect(Money.format(2064.29, 'EUR'), '2,064.29 €');
      expect(Money.format(1234.4, 'JPY'), '¥1,234');
      expect(Money.format(1234, 'CHF'), 'CHF 1,234.00');
      expect(Money.format(-5, 'USD'), '-\$5.00');
      expect(Money.format(10, 'USD', signed: true), '+\$10.00');
    });

    test('no minus sign for amounts that round to zero', () {
      expect(Money.format(-0.001, 'EUR'), '0.00 €');
      expect(Money.format(0, 'EUR', signed: true), '0.00 €');
    });

    test('unknown currencies show their code, not a dollar sign', () {
      expect(Money.symbol('xyz'), 'XYZ');
    });

    test('compact', () {
      expect(Money.compact(950, 'EUR'), '€950');
      expect(Money.compact(1500, 'EUR'), '€1.5k');
      expect(Money.compact(-2000000, 'USD'), '-\$2M');
    });
  });
}
