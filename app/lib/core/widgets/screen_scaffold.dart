import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';

/// 셸(탭바) 안쪽 화면의 공통 골격.
///
/// - 배경 `#F3F4F9`
/// - 상단 SafeArea만 적용 (하단은 플로팅 탭바가 덮는다)
/// - 스크롤 하단에 탭바가 가리는 만큼 여백을 준다
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      12,
      AppSizes.screenPadding,
      0,
    ),
    this.bottomClearance = AppSizes.tabBarClearance,
    this.controller,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsets padding;
  final double bottomClearance;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding.copyWith(bottom: padding.bottom + bottomClearance),
      child: child,
    );

    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: scrollable
            ? SingleChildScrollView(controller: controller, child: content)
            : content,
      ),
    );
  }
}

/// 화면 제목 + 부제 (각 화면 상단의 h3 + 회색 한 줄).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 6),
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(header: true, child: Text(title, style: AppText.screenTitle)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: AppText.meta(12)),
          ],
        ],
      ),
    );
  }
}

/// "← 홈" 처럼 앞 화면으로 돌아가는 텍스트 버튼.
class BackTextButton extends StatelessWidget {
  const BackTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GhostButton(label: '← $label', onPressed: onTap),
    );
  }
}

/// 데이터 로딩 실패 시 화면 전체를 대체한다.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: appText(size: 13.5, height: 1.8, color: AppColors.muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SoftButton(label: '다시 시도', onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// 빈 목록 안내 — "아직 예약이 없어요 🗓️" 같은 자리.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.r24,
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: appText(size: 13.5, height: 1.8, color: AppColors.muted),
        ),
      ),
    );
  }
}

/// 로딩 표시 — 앱 전체에서 이 하나만 쓴다.
class Loading extends StatelessWidget {
  const Loading({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.purple,
          ),
        ),
      ),
    );
  }
}
