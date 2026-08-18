import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 화면 하단에 떠 있는 pill 탭바.
///
/// `rgba(255,255,255,.92)` + `backdrop-filter: blur(14px)`, radius 999,
/// 활성 탭은 퍼플 그라디언트 pill + 흰 글씨.
/// 온보딩 · 신고 · 로그인 화면에서는 아예 렌더되지 않는다(셸 바깥 라우트).
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<String> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        boxShadow: AppShadows.tabBar,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.pill,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(6),
            color: Colors.white.withValues(alpha: .92),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _Tab(
                      label: items[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? AppGradients.primary : null,
              borderRadius: AppRadius.pill,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        offset: const Offset(0, 6),
                        blurRadius: 16,
                        color: AppColors.purpleA(.35),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              style: appText(
                size: 12.5,
                weight: selected ? 700 : 500,
                color: selected ? Colors.white : AppColors.mutedStrong,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
