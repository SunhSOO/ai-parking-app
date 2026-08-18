import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 혜택 카드의 **적합도 링 게이지**.
///
/// 프로토타입 CSS:
/// ```css
/// background: conic-gradient(#6A5AE0 {match*3.6}deg, rgba(106,90,224,.12) 0);
/// ```
/// CSS의 conic-gradient는 12시 방향에서 시계 방향으로 채워지므로
/// 시작 각도를 -90°(= -π/2)로 잡는다.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.percent,
    this.size = 52,
    this.innerSize = 40,
    this.color = AppColors.purple,
  });

  /// 0–100
  final int percent;
  final double size;
  final double innerSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '적합도 $percent 퍼센트',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            percent: percent.clamp(0, 100),
            color: color,
            trackColor: color.withValues(alpha: .12),
          ),
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: Container(
                width: innerSize,
                height: innerSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                ),
                child: Text(
                  '$percent%',
                  style: appText(size: 12.5, weight: 900, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.color,
    required this.trackColor,
  });

  final int percent;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sweep = percent / 100 * 2 * math.pi;

    canvas.drawCircle(
      rect.center,
      size.width / 2,
      Paint()..color = trackColor,
    );

    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        true,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.color != color;
}
