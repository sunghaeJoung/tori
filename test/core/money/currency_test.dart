import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';

void main() {
  test('최소 단위 정수를 실제 금액으로 바꾼다', () {
    expect(Currency.cny.toMajor(12850), Decimal.parse('128.5'));
    expect(Currency.krw.toMajor(12350), Decimal.parse('12350'));
  });

  test('실제 금액을 최소 단위 정수로 바꾼다', () {
    expect(Currency.cny.toMinor(Decimal.parse('128.5')), 12850);
    expect(Currency.krw.toMinor(Decimal.parse('12350')), 12350);
    expect(Currency.usd.toMinor(Decimal.parse('0.019')), 1);
  });

  test('단위 붙이기', () {
    expect(Currency.cny.withUnit('128.5'), '128.5위안');
    expect(Currency.usd.withUnit('12.99'), r'$12.99');
  });

  test('코드로 통화를 찾는다', () {
    expect(Currency.fromCode('CNY'), Currency.cny);
    expect(() => Currency.fromCode('EUR'), throwsArgumentError);
  });
}
