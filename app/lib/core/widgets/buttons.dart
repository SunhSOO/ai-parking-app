import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// pill 버튼의 공통 뼈대.
///
/// 높이는 `minHeight`로만 잡는다 — 글자 크기를 키운 사용자에게도 잘리지 않아야 한다.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.child,
    required this.onPressed,
    required this.minHeight,
    this.gradient,
    this.color,
    this.border,
    this.shadow,
    this.padding,
    this.expand = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double minHeight;
  final Gradient? gradient;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? color : null,
        border: border,
        borderRadius: AppRadius.pill,
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.pill,
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    final wrapped = semanticLabel == null
        ? button
        : Semantics(label: semanticLabel, button: true, child: ExcludeSemantics(child: button));

    return expand ? SizedBox(width: double.infinity, child: wrapped) : wrapped;
  }
}

/// 주 CTA — `linear-gradient(90deg,#6A5AE0,#7C63EC)` + 퍼플 그림자.
///
/// [onPressed]가 null이면 프로토타입의 비활성 스타일(회색 채움·연한 글씨·그림자 없음)로
/// 자동 전환된다. 별도 disabled 플래그를 두지 않는다.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = AppSizes.ctaHeight,
    this.fontSize = 16,
    this.gradient = AppGradients.primary,
    this.shadow,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Gradient gradient;
  final List<BoxShadow>? shadow;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return _PillButton(
      onPressed: onPressed,
      minHeight: height,
      expand: expand,
      semanticLabel: semanticLabel,
      gradient: enabled ? gradient : null,
      color: enabled ? null : AppColors.inkA(.08),
      shadow: enabled ? (shadow ?? AppShadows.primaryButton) : null,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.button(fontSize).copyWith(
          color: enabled ? Colors.white : AppColors.faint,
        ),
      ),
    );
  }
}

/// 회색 채움 pill — `rgba(23,22,58,.06)` 배경의 보조 버튼.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = AppSizes.actionHeight,
    this.fontSize = 14,
    this.color,
    this.background,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Color? color;
  final Color? background;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _PillButton(
      onPressed: onPressed,
      minHeight: height,
      expand: expand,
      color: background ?? AppColors.fill,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.button(fontSize).copyWith(color: color ?? AppColors.ink),
      ),
    );
  }
}

/// 배경 없는 텍스트 버튼 — "나중에 하기", "← 홈", "모두 보기".
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.fontSize = 14,
    this.weight = 700,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double fontSize;
  final int weight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.r12,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: appText(
              size: fontSize,
              weight: weight,
              color: color ?? AppColors.purple,
            ),
          ),
        ),
      ),
    );
  }
}

/// 점선 테두리 pill — 홈의 "🚨 부정주차 신고하기".
class DashedPillButton extends StatelessWidget {
  const DashedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    // 실제 dash 패턴 대신 프로토타입과 같은 인상(연한 퍼플 채움 + 퍼플 테두리)을 낸다.
    // 진짜 점선이 필요하면 CustomPainter로 교체한다.
    return _PillButton(
      onPressed: onPressed,
      minHeight: height,
      color: AppColors.purpleA(.05),
      border: Border.all(color: AppColors.purpleA(.4), width: 1.5),
      child: Text(
        label,
        style: AppText.button(14).copyWith(color: AppColors.purple),
      ),
    );
  }
}

/// 히어로 카드 위에 얹는 반투명 흰 테두리 버튼 — "주차면".
class OnHeroOutlineButton extends StatelessWidget {
  const OnHeroOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _PillButton(
      onPressed: onPressed,
      minHeight: height,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withValues(alpha: .12),
      border: Border.all(color: Colors.white.withValues(alpha: .5), width: 1.5),
      child: Text(
        label,
        style: AppText.button(15).copyWith(color: Colors.white),
      ),
    );
  }
}

/// 히어로 카드 위의 흰 채움 버튼 — "지금 인증 실행" / "확인증 보기".
class OnHeroFilledButton extends StatelessWidget {
  const OnHeroFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _PillButton(
      onPressed: onPressed,
      minHeight: height,
      color: Colors.white,
      shadow: AppShadows.onHeroButton,
      child: Text(
        label,
        style: AppText.button(15).copyWith(color: AppColors.purpleDeep),
      ),
    );
  }
}
