import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 여러 개 중 하나를 고르는 카드 (통화 고르기, 나는 누구? 등).
/// 고르면 강조색 테두리와 연한 배경이 된다.
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 16, 14),
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      child: Material(
        color: selected ? ToriColors.accentSoft : ToriColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? ToriColors.accent : ToriColors.cardBorder,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
