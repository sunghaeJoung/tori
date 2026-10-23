import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tori/core/exchange_rate/exchange_rate.dart';
import 'package:tori/core/exchange_rate/frankfurter_api.dart';
import 'package:tori/core/money/currency.dart';

void main() {
  test('최신 원화 환율과 기준일을 읽는다', () async {
    late Uri asked;
    final api = FrankfurterApi(
      MockClient((request) async {
        asked = request.url;
        return http.Response(
          '{"amount":1.0,"base":"CNY","date":"2026-11-09","rates":{"KRW":192.35}}',
          200,
        );
      }),
    );
    final rate = await api.latest(Currency.cny);
    expect(asked.queryParameters, {'base': 'CNY', 'symbols': 'KRW'});
    expect(asked.scheme, 'https');
    expect(rate.krwPerUnit, Decimal.parse('192.35'));
    expect(rate.date, DateTime(2026, 11, 9));
  });

  test('실패하면 예외', () async {
    final api = FrankfurterApi(MockClient((_) async => http.Response('', 500)));
    expect(api.latest(Currency.jpy), throwsA(isA<http.ClientException>()));
  });

  test('환율 표기: 엔화는 100엔 단위', () {
    ExchangeRate rate(Currency c, String v) => ExchangeRate(
      currency: c,
      krwPerUnit: Decimal.parse(v),
      date: DateTime(2026, 11, 9),
    );
    expect(rate(Currency.cny, '192.35').label, '1위안 = 192.35원');
    expect(rate(Currency.jpy, '9.124').label, '100엔 = 912.40원');
    expect(rate(Currency.usd, '1380.5').label, r'$1 = 1,380.50원');
  });
}
