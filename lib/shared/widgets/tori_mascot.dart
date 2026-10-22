import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum ToriFace {
  /// 얼굴 없음 (로고용).
  none,

  /// 눈만.
  calm,

  /// 눈과 웃는 입.
  smile,
}

/// 도토리 캐릭터 토리. 프로토타입의 SVG(64×64 좌표)를 그대로 옮겨 그린다.
class ToriMascot extends StatelessWidget {
  const ToriMascot({super.key, this.size = 72, this.face = ToriFace.calm});

  final double size;
  final ToriFace face;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _AcornPainter(face)),
    );
  }
}

class _AcornPainter extends CustomPainter {
  const _AcornPainter(this.face);

  final ToriFace face;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // 꼭지
    canvas.drawLine(
      const Offset(32, 5),
      const Offset(32, 12),
      stroke(ToriColors.acornCap, face == ToriFace.none ? 4 : 3),
    );

    // 모자
    final cap = Path()
      ..moveTo(9, 27)
      ..cubicTo(9, 18, 19.5, 12, 32, 12)
      ..cubicTo(44.5, 12, 55, 18, 55, 27)
      ..cubicTo(55, 29, 53.8, 30, 52, 30)
      ..lineTo(12, 30)
      ..cubicTo(10.2, 30, 9, 29, 9, 27)
      ..close();
    canvas.drawPath(cap, Paint()..color = ToriColors.acornCap);

    // 몸통
    final body = Path()
      ..moveTo(13.5, 30)
      ..lineTo(50.5, 30)
      ..cubicTo(50.5, 46.5, 42.5, 57.5, 32, 58.5)
      ..cubicTo(21.5, 57.5, 13.5, 46.5, 13.5, 30)
      ..close();
    canvas.drawPath(body, Paint()..color = ToriColors.acornBody);

    if (face == ToriFace.none) return;

    final eye = Paint()..color = ToriColors.acornFace;
    canvas.drawCircle(const Offset(25, 40), 2.2, eye);
    canvas.drawCircle(const Offset(39, 40), 2.2, eye);

    if (face == ToriFace.smile) {
      final mouth = Path()
        ..moveTo(28, 46)
        ..cubicTo(30.2, 48, 33.8, 48, 36, 46);
      canvas.drawPath(mouth, stroke(ToriColors.acornFace, 2));
    }
  }

  @override
  bool shouldRepaint(_AcornPainter old) => old.face != face;
}
