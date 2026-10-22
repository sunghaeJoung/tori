import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/money/money_format.dart';

void main() {
  test('통화별 표기', () {
    expect(formatMoney(12350, Currency.krw), '12,350원');
    expect(formatMoney(1500, Currency.jpy), '1,500엔');
    expect(formatMoney(12850, Currency.cny), '128.50위안');
    expect(formatMoney(1299, Currency.usd), r'$12.99');
  });

  test('큰 금액은 세 자리마다 쉼표', () {
    expect(formatMoney(1200000, Currency.krw), '1,200,000원');
    expect(formatMoney(480000, Currency.cny), '4,800.00위안');
  });

  test('0과 1단위 미만 금액', () {
    expect(formatMoney(0, Currency.krw), '0원');
    expect(formatMoney(5, Currency.cny), '0.05위안');
    expect(formatMoney(0, Currency.usd), r'$0.00');
  });

  test('음수는 앞에 - 를 붙인다', () {
    expect(formatMoney(-300000, Currency.krw), '-300,000원');
    expect(formatMoney(-38788, Currency.cny), '-387.88위안');
    expect(formatMoney(-1299, Currency.usd), r'-$12.99');
  });
}
