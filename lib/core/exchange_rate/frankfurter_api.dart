import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../money/currency.dart';

/// 통화 1단위(1위안, 1엔, 1달러)가 몇 원인지와 그 기준일.
class ExchangeRate {
  const ExchangeRate({
    required this.currency,
    required this.krwPerUnit,
    required this.date,
  });

  final Currency currency;
  final Decimal krwPerUnit;
  final DateTime date;

  /// 화면 표기: `1위안 = 192.35원` · `100엔 = 912.40원` · `$1 = 1,380.50원`
  ///
  /// 엔화는 한국에서 익숙한 100엔 단위로 보여준다.
  String get label {
    final unit = currency == Currency.jpy ? 100 : 1;
    final won = _rateFormat.format(krwPerUnit * Decimal.fromInt(unit));
    return '${currency.withUnit('$unit')} = $won원';
  }

  /// 엔화는 100엔 단위로 입력받는다 ([label]과 같은 기준).
  static int inputUnitOf(Currency currency) =>
      currency == Currency.jpy ? 100 : 1;
}

final _rateFormat = DecimalFormatter(NumberFormat('#,##0.00', 'en_US'));

/// 유럽중앙은행(ECB) 고시 환율을 주는 무료 API. 키가 필요 없고 HTTPS·CORS를 지원한다.
/// 주말·공휴일에는 직전 영업일 환율이 나온다.
class FrankfurterApi {
  FrankfurterApi(this._client);

  final http.Client _client;

  static final _latest = Uri.parse('https://api.frankfurter.dev/v1/latest');

  /// [currency] 1단위의 최신 원화 환율. 실패하면 예외.
  Future<ExchangeRate> latest(Currency currency) async {
    final uri = _latest.replace(
      queryParameters: {'base': currency.code, 'symbols': 'KRW'},
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException('환율 조회 실패 (${response.statusCode})', uri);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (json['rates'] as Map<String, dynamic>)['KRW'] as num;
    return ExchangeRate(
      currency: currency,
      // JSON 숫자를 그대로 읽으면 double 오차가 생길 수 있어 글자로 바꿔 읽는다
      krwPerUnit: Decimal.parse(rate.toString()),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
