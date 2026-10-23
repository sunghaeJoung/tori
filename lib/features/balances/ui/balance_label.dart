import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 잔액 부호에 맞는 색과 말: 받을 돈(파랑) · 줄 돈(빨강) · 정산 끝.
({Color color, String label}) balanceLook(int amount) => switch (amount) {
  > 0 => (color: ToriColors.receive, label: '받을 돈'),
  < 0 => (color: ToriColors.pay, label: '줄 돈'),
  _ => (color: ToriColors.textMuted, label: '정산 끝'),
};
