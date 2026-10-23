import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 흰 바탕에 옅은 테두리를 두른 둥근 카드 (요약, 송금, 잔액 행 등).
class ToriCard extends StatelessWidget {
  const ToriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.color = ToriColors.surface,
    this.borderColor = ToriColors.cardBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
