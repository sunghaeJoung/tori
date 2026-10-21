import 'package:decimal/decimal.dart';

/// 앱에서 쓰는 통화 4종.
///
/// 금액은 항상 통화의 최소 단위 정수로 다룬다 (예: 128.50위안 → 12850).
enum Currency {
  krw(code: 'KRW', decimals: 0),
  jpy(code: 'JPY', decimals: 0),
  cny(code: 'CNY', decimals: 2),
  usd(code: 'USD', decimals: 2);

  const Currency({required this.code, required this.decimals});

  /// DB에 저장하는 ISO 4217 코드.
  final String code;

  /// 소수 자리수. 최소 단위 정수를 10^decimals로 나누면 실제 금액이 된다.
  final int decimals;

  /// 최소 단위 정수를 실제 금액으로 바꾼다 (12850 → 128.50).
  Decimal toMajor(int minor) => Decimal.fromInt(minor).shift(-decimals);

  static Currency fromCode(String code) => values.firstWhere(
    (c) => c.code == code,
    orElse: () => throw ArgumentError.value(code, 'code', '지원하지 않는 통화'),
  );
}
