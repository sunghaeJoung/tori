import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 둥근 배지. 기본은 강조색(통화 표시 등), [Pill.muted]는 회색(정산 완료 등).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key})
    : background = ToriColors.accentSoft,
      foreground = ToriColors.accent;

  const Pill.muted(this.label, {super.key})
    : background = ToriColors.mutedBadge,
      foreground = ToriColors.textMuted;

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
