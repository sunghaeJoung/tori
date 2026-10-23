import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

import '../money/currency.dart';

/// 통화 1단위(1위안, 1엔, 1달러)가 몇 원인지와 그 기준일.
class ExchangeRate {
  const ExchangeRate({
    required this.currency,
    required this.krwPerUnit,
    required this.date,
  });

  /// 원화 여행의 "환율" (1원 = 1원). 날짜만 남긴다.
  factory ExchangeRate.won(DateTime today) => ExchangeRate(
    currency: Currency.krw,
    krwPerUnit: Decimal.one,
    date: DateTime(today.year, today.month, today.day),
  );

  /// 환율 단위([Currency.rateQuoteUnit])로 입력한 값으로 만든다 (엔화는 100엔이 몇 원인지).
  factory ExchangeRate.quoted(Currency currency, Decimal won, DateTime date) =>
      ExchangeRate(
        currency: currency,
        krwPerUnit: (won / Decimal.fromInt(currency.rateQuoteUnit)).toDecimal(
          scaleOnInfinitePrecision: 10,
        ),
        date: DateTime(date.year, date.month, date.day),
      );

  final Currency currency;
  final Decimal krwPerUnit;
  final DateTime date;

  /// 원화 여행이라 바꿀 필요가 없다 ("약 ○○원" 대신 정확한 금액).
  bool get isWon => currency == Currency.krw;

  /// 화면 표기: `1위안 = 192.35원` · `100엔 = 912.40원` · `$1 = 1,380.50원`
  String get label {
    final unit = currency.rateQuoteUnit;
    final won = _rateFormat.format(krwPerUnit * Decimal.fromInt(unit));
    return '${currency.withUnit('$unit')} = $won원';
  }

  /// [currency] 최소 단위 금액을 원화로 (반올림하지 않음).
  Decimal toKrw(int amount) => currency.toMajor(amount) * krwPerUnit;
}

final _rateFormat = DecimalFormatter(NumberFormat('#,##0.00', 'en_US'));
