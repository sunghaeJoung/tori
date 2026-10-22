import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/money/currency.dart';
import '../../core/money/money_format.dart';

/// 금액 표시. 숫자 폭이 같은 글꼴(tabular)로 그려서 목록에서 자리가 맞는다.
///
/// [balance]가 true면 잔액으로 보고 받을 돈은 `+`와 파랑, 줄 돈은 빨강으로 그린다.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount,
    this.currency, {
    super.key,
    this.style,
    this.balance = false,
  });

  /// 최소 단위 정수.
  final int amount;
  final Currency currency;
  final TextStyle? style;
  final bool balance;

  @override
  Widget build(BuildContext context) {
    final formatted = formatMoney(amount, currency);
    final Color? color;
    if (!balance || amount == 0) {
      color = null;
    } else {
      color = amount > 0 ? ToriColors.receive : ToriColors.pay;
    }

    return Text(
      balance && amount > 0 ? '+$formatted' : formatted,
      style: (style ?? const TextStyle()).merge(
        TextStyle(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
