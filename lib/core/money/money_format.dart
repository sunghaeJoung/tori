import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

import 'currency.dart';

final _formatters = <int, DecimalFormatter>{};

/// 최소 단위 정수 금액을 화면 표기로 바꾼다.
///
/// `12,350원` · `1,500엔` · `128.50위안` · `$12.99`. 음수는 앞에 `-`를 붙인다.
/// 엔화·위안화에는 `¥` 기호를 쓰지 않는다.
String formatMoney(int amount, Currency currency) {
  final formatter = _formatters.putIfAbsent(
    currency.decimals,
    () => DecimalFormatter(
      NumberFormat.decimalPatternDigits(
        locale: 'en_US',
        decimalDigits: currency.decimals,
      ),
    ),
  );
  final number = formatter.format(currency.toMajor(amount.abs()));
  final sign = amount < 0 ? '-' : '';
  return sign + currency.withUnit(number);
}
