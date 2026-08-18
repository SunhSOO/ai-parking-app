import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 흰 카드 — 프로토타입 전반의 기본 서피스.
/// `background:#fff; border-radius:20~28px; box-shadow:0 6px 18px rgba(23,22,58,.05)`
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.radius = AppRadius.r22,
    this.shadow,
    this.border,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final List<BoxShadow>? shadow;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        boxShadow: shadow ?? AppShadows.card,
        border: border,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
            ),
    );
  }
}

/// 다크 그라디언트 카드 — 인증 확인증, 신고 접수 완료.
/// 우상단에 흐릿한 발광 원 하나가 들어간다.
class DarkGradientCard extends StatelessWidget {
  const DarkGradientCard({
    super.key,
    required this.child,
    this.glowColor,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 24),
    this.radius = AppRadius.r28,
  });

  final Widget child;
  final Color? glowColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.dark,
          borderRadius: radius,
          boxShadow: AppShadows.darkCard,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: _Glow(color: glowColor ?? AppColors.purpleA(.3)),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;
  static const size = 140.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 30, spreadRadius: 30)],
      ),
    );
  }
}

/// 연한 퍼플·블루 틴트 카드 — "🎯 이 혜택이 뜬 이유", "🅿️ 목적지 주차면".
class TintCard extends StatelessWidget {
  const TintCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.radius = AppRadius.r22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.tintPurpleBlue,
        borderRadius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 민트 틴트 안내 박스 — 온보딩의 번호판 대조 안내.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mintA(.1),
        borderRadius: AppRadius.r18,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: appText(size: 12.5, height: 1.7, color: AppColors.mintDeep),
        ),
      ),
    );
  }
}

/// 섹션 헤더 — 왼쪽 제목 + 오른쪽 선택적 액션("모두 보기").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(6, 22, 6, 10),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: AppText.section)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: appText(size: 12.5, weight: 700, color: AppColors.purple),
              ),
            ),
        ],
      ),
    );
  }
}
