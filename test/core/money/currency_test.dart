import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';

void main() {
  test('통화별 소수 자리수', () {
    expect(Currency.krw.decimals, 0);
    expect(Currency.jpy.decimals, 0);
    expect(Currency.cny.decimals, 2);
    expect(Currency.usd.decimals, 2);
  });

  test('코드로 통화를 찾는다', () {
    expect(Currency.fromCode('CNY'), Currency.cny);
    expect(() => Currency.fromCode('EUR'), throwsArgumentError);
  });
}
