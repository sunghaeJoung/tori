import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 화면 위쪽 안내 띠. 기본은 회색, [NoticeBox.warning]은 빨간 경고.
class NoticeBox extends StatelessWidget {
  const NoticeBox(this.text, {super.key, this.action})
    : background = ToriColors.tile,
      foreground = ToriColors.textMuted,
      weight = FontWeight.w400;

  const NoticeBox.warning(this.text, {super.key, this.action})
    : background = ToriColors.payBackground,
      foreground = ToriColors.payText,
      weight = FontWeight.w600;

  final String text;

  /// 오른쪽 버튼 (예: 다시 시도)
  final Widget? action;
  final Color background;
  final Color foreground;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                fontWeight: weight,
                color: foreground,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
