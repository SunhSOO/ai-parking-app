import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 흰 카드 안의 키-값 행. 마지막 행은 구분선을 그리지 않는다.
///
/// 온보딩 정보 확인 · 혜택 상세 표 · 마이페이지 자격 정보에서 쓴다.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
    this.valueSize = 14.5,
    this.verticalPadding = 12,
  });

  final String label;
  final String value;
  final bool last;
  final double valueSize;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.inkA(.05))),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.rowKey),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.rowValue(valueSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// 다크 확인증 카드 안의 키-값 행. 구분선이 행 **위**에 있다.
class DarkKeyValueRow extends StatelessWidget {
  const DarkKeyValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .12)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: appText(
              size: 13,
              color: Colors.white.withValues(alpha: .6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: appText(size: 13, weight: 700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아이콘 칩 + 제목/메타 + 우측 위젯으로 이루어진 리스트 행 카드.
///
/// 홈의 "오늘의 알림", 인증 이력, 시설 카드가 모두 이 형태다.
class ListRowCard extends StatelessWidget {
  const ListRowCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.radius = AppRadius.r20,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    this.titleSize = 14,
    this.gap = 13,
    this.border,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final double titleSize;
  final double gap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.cardTitle(titleSize)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.meta(12)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        boxShadow: AppShadows.card,
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

/// 홈의 2×2 통계 타일.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$label $value',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.r22,
            boxShadow: AppShadows.card,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.r22,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: AppText.stat(color)),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: appText(
                        size: 12,
                        weight: 500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 불릿 한 줄 — "이 혜택이 뜬 이유"의 근거 목록.
class BulletLine extends StatelessWidget {
  const BulletLine({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? AppColors.purple,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appText(size: 13, weight: 500, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
