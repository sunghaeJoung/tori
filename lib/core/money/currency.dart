import 'package:decimal/decimal.dart';

/// 앱에서 쓰는 통화 4종.
///
/// 금액은 항상 통화의 최소 단위 정수로 다룬다 (예: 128.50위안 → 12850).
enum Currency {
  krw(code: 'KRW', decimals: 0, label: '원화', unit: '원'),
  jpy(code: 'JPY', decimals: 0, label: '엔화', unit: '엔'),
  cny(code: 'CNY', decimals: 2, label: '위안화', unit: '위안'),
  usd(code: 'USD', decimals: 2, label: '달러', unit: '달러');

  const Currency({
    required this.code,
    required this.decimals,
    required this.label,
    required this.unit,
  });

  /// DB에 저장하는 ISO 4217 코드.
  final String code;

  /// 소수 자리수. 최소 단위 정수를 10^decimals로 나누면 실제 금액이 된다.
  final int decimals;

  /// 화면에 보이는 이름 (원화·엔화·위안화·달러).
  final String label;

  /// 금액 뒤에 붙이는 단위 (원·엔·위안). 달러는 금액 앞에 `$`를 붙여서 쓰지 않는다.
  final String unit;

  /// 최소 단위 정수를 실제 금액으로 바꾼다 (12850 → 128.50).
  Decimal toMajor(int minor) => Decimal.fromInt(minor).shift(-decimals);

  static Currency fromCode(String code) => values.firstWhere(
    (c) => c.code == code,
    orElse: () => throw ArgumentError.value(code, 'code', '지원하지 않는 통화'),
  );
}
