import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// '토리' 글자 로고.
class ToriWordmark extends StatelessWidget {
  const ToriWordmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      '토리',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: size * -0.03,
        color: ToriColors.acornCap,
      ),
    );
  }
}
