import 'package:intl/intl.dart';

import 'currency.dart';

final _grouped = NumberFormat('#,##0', 'en_US');

/// 최소 단위 정수 금액을 화면 표기로 바꾼다.
///
/// `12,350원` · `1,500엔` · `128.50위안` · `$12.99`. 음수는 앞에 `-`를 붙인다.
/// 엔화·위안화에는 `¥` 기호를 쓰지 않는다.
String formatMoney(int amount, Currency currency) {
  final sign = amount < 0 ? '-' : '';
  final number = _formatNumber(amount.abs(), currency.decimals);
  return switch (currency) {
    Currency.krw => '$sign$number원',
    Currency.jpy => '$sign$number엔',
    Currency.cny => '$sign$number위안',
    Currency.usd => '$sign\$$number',
  };
}

String _formatNumber(int amount, int decimals) {
  if (decimals == 0) return _grouped.format(amount);
  var unit = 1;
  for (var i = 0; i < decimals; i++) {
    unit *= 10;
  }
  final major = _grouped.format(amount ~/ unit);
  final minor = (amount % unit).toString().padLeft(decimals, '0');
  return '$major.$minor';
}
