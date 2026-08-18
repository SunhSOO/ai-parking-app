import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 카테고리 필터 칩 — 선택 시 퍼플 그라디언트 pill + 흰 글씨.
/// 혜택 피드·시설 검색의 가로 스크롤 칩 행에 쓴다.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 38,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.primary : null,
          color: selected ? null : AppColors.surface,
          borderRadius: AppRadius.pill,
          boxShadow: selected ? AppShadows.primaryButtonSmall : AppShadows.chip,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.pill,
            child: Container(
              constraints: BoxConstraints(minHeight: height),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                style: appText(
                  size: 13,
                  weight: 700,
                  color: selected ? Colors.white : AppColors.inkA(.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 가로 스크롤 칩 행. 좌우 여백은 프로토타입과 동일하게 20px.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 6),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 작은 상태 배지 pill — "✓ 탑승 인증 확인증", "자동 실행", "확정", "D-9".
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.fontSize = 11,
    this.emSpacing = .04,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.leading,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;
  final double emSpacing;
  final EdgeInsetsGeometry padding;
  final Widget? leading;

  /// 퍼플 틴트 — 카테고리 라벨
  factory AppBadge.purple(String label, {double fontSize = 11}) => AppBadge(
        label: label,
        background: AppColors.purpleA(.1),
        foreground: AppColors.purple,
        fontSize: fontSize,
      );

  /// 민트 틴트 — 확정·인증 완료
  factory AppBadge.mint(String label, {double fontSize = 11}) => AppBadge(
        label: label,
        background: AppColors.mintA(.12),
        foreground: AppColors.mintDeep,
        fontSize: fontSize,
      );

  /// 오렌지 틴트 — 대기·경고
  factory AppBadge.warning(String label, {double fontSize = 11}) => AppBadge(
        label: label,
        background: AppColors.orangeA(.15),
        foreground: AppColors.warningDeep,
        fontSize: fontSize,
      );

  /// 회색 틴트 — 부가 정보
  factory AppBadge.neutral(String label, {double fontSize = 11}) => AppBadge(
        label: label,
        background: AppColors.inkA(.05),
        foreground: AppColors.inkA(.55),
        fontSize: fontSize,
        emSpacing: 0,
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 7)],
            Text(
              label,
              style: appText(
                size: fontSize,
                weight: 700,
                color: foreground,
                emSpacing: emSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 정사각 라운드 아이콘 칩 — 알림 배지(44px), 시설 아이콘(50px), 이력 아이콘(38px).
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.child,
    this.size = 44,
    this.radius = 16,
    this.background,
    this.gradient,
  });

  final Widget child;
  final double size;
  final double radius;
  final Color? background;
  final Gradient? gradient;

  /// 텍스트/이모지를 담는 흔한 형태
  factory IconChip.text(
    String text, {
    double size = 44,
    double radius = 16,
    Color? background,
    Color? foreground,
    double fontSize = 12,
    int weight = 900,
  }) =>
      IconChip(
        size: size,
        radius: radius,
        background: background,
        child: Text(
          text,
          style: appText(
            size: fontSize,
            weight: weight,
            color: foreground ?? AppColors.ink,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gradient == null ? (background ?? AppColors.fill) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// 원형 그라디언트 아바타 — 이니셜 표시.
class GradientAvatar extends StatelessWidget {
  const GradientAvatar({
    super.key,
    required this.initials,
    this.size = 46,
    this.fontSize = 14,
    this.onTap,
  });

  final String initials;
  final double size;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.avatar,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 6),
            blurRadius: 16,
            color: AppColors.purpleA(.35),
          ),
        ],
      ),
      child: Text(
        initials,
        style: appText(size: fontSize, weight: 900, color: Colors.white),
      ),
    );

    if (onTap == null) return avatar;

    return Semantics(
      button: true,
      label: '마이페이지',
      child: ExcludeSemantics(
        child: GestureDetector(onTap: onTap, child: avatar),
      ),
    );
  }
}
