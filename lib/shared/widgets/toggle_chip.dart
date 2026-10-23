import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 눌러서 켜고 끄는 둥근 칩 (낸 사람, 나눌 사람). 켜지면 강조색으로 채운다.
class ToggleChip extends StatelessWidget {
  const ToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 켜졌을 때 앞에 체크 표시 (여러 개를 고르는 칩)
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? ToriColors.surface : ToriColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ToriColors.accent : ToriColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? ToriColors.accent : ToriColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (showCheck && selected)
                  Icon(Icons.check, size: 16, color: foreground),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
