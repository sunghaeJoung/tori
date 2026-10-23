import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

import 'currency.dart';
import 'settlement.dart';

final _formatters = <int, DecimalFormatter>{};

/// 정수를 세 자리마다 쉼표로: `1,280`
String formatGrouped(int number) =>
    _formatter(0).format(Decimal.fromInt(number));

DecimalFormatter _formatter(int decimals) => _formatters.putIfAbsent(
  decimals,
  () => DecimalFormatter(
    NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: decimals),
  ),
);

/// 잔액 표기: 받을 돈은 앞에 `+`를 붙인다 (`+405.33위안` · `-300,000원`).
String formatSignedMoney(int amount, Currency currency) =>
    '${amount > 0 ? '+' : ''}${formatMoney(amount, currency)}';

/// 환산한 원화를 10원 단위로 반올림해 대략으로: `약 1,049,260원`
String formatApproxWon(Decimal won) =>
    '약 ${formatMoney(roundTo10Won(won), Currency.krw)}';

/// 최소 단위 정수 금액을 화면 표기로 바꾼다.
///
/// `12,350원` · `1,500엔` · `128.50위안` · `$12.99`. 음수는 앞에 `-`를 붙인다.
/// 엔화·위안화에는 `¥` 기호를 쓰지 않는다.
String formatMoney(int amount, Currency currency) {
  final number = _formatter(currency.decimals)
      .format(currency.toMajor(amount.abs()));
  final sign = amount < 0 ? '-' : '';
  return sign + currency.withUnit(number);
}
