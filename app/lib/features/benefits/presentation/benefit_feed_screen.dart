import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/ring_gauge.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/benefit.dart';
import 'benefit_controller.dart';

/// 복지혜택 맞춤 피드 (프로토타입 화면 6).
class BenefitFeedScreen extends ConsumerWidget {
  const BenefitFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final selected = ref.watch(benefitCategoryProvider);
    final feed = ref.watch(benefitFeedProvider);

    return ScreenScaffold(
      // 카테고리 칩이 화면 끝까지 스크롤돼야 해서 좌우 여백을 자식이 직접 준다.
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: ScreenHeader(
              title: '내게 맞는 혜택 ✨',
              subtitle: profile?.eligibilitySummary,
              padding: EdgeInsets.zero,
            ),
          ),
          ChipRow(
            children: [
              for (final category in BenefitCategory.values)
                PillChip(
                  label: category.label,
                  selected: selected == category.id,
                  onTap: () => ref
                      .read(benefitCategoryProvider.notifier)
                      .set(category.id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: switch (feed) {
              AsyncValue(hasError: true, :final error) => ErrorState(
                  message: '혜택을 불러오지 못했어요\n$error',
                  onRetry: () => ref.invalidate(benefitFeedProvider),
                ),
              AsyncValue(value: final items?) when items.isEmpty =>
                const EmptyState(message: '이 카테고리에 맞는 혜택이 아직 없어요'),
              AsyncValue(value: final items?) => Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      BenefitCard(benefit: items[i]),
                    ],
                  ],
                ),
              _ => const Loading(),
            },
          ),
        ],
      ),
    );
  }
}

/// 피드의 혜택 카드 — 적합도 링 + 제목 + 매칭 근거 태그.
class BenefitCard extends StatelessWidget {
  const BenefitCard({super.key, required this.benefit});

  final Benefit benefit;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.all(18),
      onTap: () => context.go(Routes.benefitDetail(benefit.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppBadge.purple(benefit.catLabel),
              const Spacer(),
              Text(
                benefit.dueText,
                style: appText(
                  size: 11.5,
                  weight: 700,
                  color: benefit.urgent ? AppColors.danger : AppColors.inkA(.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RingGauge(percent: benefit.score),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(benefit.title, style: AppText.cardTitle()),
                    const SizedBox(height: 3),
                    Text(
                      benefit.summary,
                      style: appText(
                        size: 12.5,
                        height: 1.55,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (benefit.reasons.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final reason in benefit.reasons.take(3))
                  AppBadge.neutral(reason),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
