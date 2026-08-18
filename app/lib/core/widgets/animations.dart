import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// `@keyframes blink{0%,100%{opacity:1}50%{opacity:.25}}`
///
/// 자동 인증이 진행 중일 때만 깜빡인다. [animate]가 false면 정지 상태로 둔다
/// (모션 민감 사용자를 위해 `MediaQuery.disableAnimations`도 존중한다).
class BlinkDot extends StatefulWidget {
  const BlinkDot({
    super.key,
    required this.color,
    this.size = 7,
    this.animate = true,
    this.period = const Duration(milliseconds: 1200),
  });

  final Color color;
  final double size;
  final bool animate;
  final Duration period;

  @override
  State<BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BlinkDot old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
    );

    if (!widget.animate || reduceMotion) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: .25).animate(_c),
      child: dot,
    );
  }
}

/// `@keyframes floaty{50%{transform:translateY(-5px)}}` — 온보딩 카드 일러스트.
class Floaty extends StatefulWidget {
  const Floaty({super.key, required this.child, this.distance = 5});

  final Widget child;
  final double distance;

  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -widget.distance * _c.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// 자동 인증 시트의 진행바.
/// `height:8px; radius:99px; background:rgba(106,90,224,.1)` + 퍼플→블루 채움.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.duration = const Duration(milliseconds: 400),
  });

  /// 0.0 – 1.0
  final double value;
  final double height;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: AppRadius.pill,
        child: Container(
          height: height,
          color: AppColors.purpleA(.1),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: duration,
                decoration: const BoxDecoration(
                  gradient: AppGradients.progress,
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 온보딩 상단 3칸 진행바.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step, this.total = 3});

  /// 0-based 현재 단계
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total단계 중 ${step + 1}단계',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 5,
                decoration: BoxDecoration(
                  gradient: i <= step ? AppGradients.progress : null,
                  color: i <= step ? null : AppColors.inkA(.08),
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
