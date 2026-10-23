import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 회색 바탕 위에서 하나를 고르는 칸 (지출 통화 위안/원, 여행방 탭 등).
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  /// (값, 라벨)
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ToriColors.divider,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          spacing: 4,
          children: [
            for (final (value, label) in options)
              Expanded(child: _segment(context, value, label)),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, T value, String label) {
    final isSelected = value == selected;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? ToriColors.surface : Colors.transparent,
        elevation: isSelected ? 1 : 0,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isSelected ? null : () => onSelect(value),
          child: SizedBox(
            height: 36,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? ToriColors.text : ToriColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
