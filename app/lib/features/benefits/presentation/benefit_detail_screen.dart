import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/rows.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../domain/benefit.dart';
import 'benefit_controller.dart';

/// 혜택 상세 · 신청 (프로토타입 화면 7).
class BenefitDetailScreen extends ConsumerWidget {
  const BenefitDetailScreen({super.key, required this.benefitId});

  final String benefitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(benefitDetailProvider(benefitId));

    return ScreenScaffold(
      child: switch (detail) {
        AsyncValue(hasError: true) => ErrorState(
            message: '혜택을 불러오지 못했어요',
            onRetry: () => ref.invalidate(benefitDetailProvider(benefitId)),
          ),
        AsyncValue(value: final benefit?) => _Detail(benefit: benefit),
        AsyncValue(isLoading: true) => const Loading(height: 400),
        _ => const EmptyState(message: '없는 혜택이에요'),
      },
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.benefit});

  final Benefit benefit;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _submitting = false;

  Future<void> _apply() async {
    setState(() => _submitting = true);
    try {
      await ref.read(applyBenefitProvider)(widget.benefit.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신청이 접수됐어요')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청하지 못했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final benefit = widget.benefit;
    final applied = benefit.applied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackTextButton(label: '혜택', onTap: () => context.go(Routes.benefits)),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AppBadge.purple(benefit.catLabel),
                  const Spacer(),
                  Text(
                    '적합도 ${benefit.score}%',
                    style: appText(
                      size: 12.5,
                      weight: 900,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(benefit.title, style: AppText.heading(24)),
              ),
              const SizedBox(height: 8),
              Text(benefit.summary, style: AppText.body()),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 왜 이 혜택이 추천됐는지 — 매칭 근거를 그대로 보여 준다.
        TintCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎯 이 혜택이 뜬 이유',
                style: appText(size: 12.5, weight: 900, color: AppColors.purple),
              ),
              const SizedBox(height: 4),
              for (final reason in benefit.reasons) BulletLine(text: reason),
              if (benefit.reasons.isEmpty)
                BulletLine(text: '자격 정보를 더 채우면 근거를 보여 드릴 수 있어요'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (benefit.detailRows.isNotEmpty)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < benefit.detailRows.length; i++)
                  KeyValueRow(
                    label: benefit.detailRows[i].first,
                    value: benefit.detailRows[i].last,
                    valueSize: 13,
                    last: i == benefit.detailRows.length - 1,
                  ),
                if (benefit.org != null)
                  KeyValueRow(
                    label: '담당',
                    value: benefit.org!,
                    valueSize: 13,
                    last: true,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),

        if (applied)
          SoftButton(
            label: '✓ 신청 접수됨 · 진행 보기',
            height: AppSizes.ctaHeight,
            fontSize: 16,
            background: AppColors.mintA(.15),
            color: AppColors.mintDeep,
            onPressed: () {},
          )
        else
          GradientButton(
            label: _submitting ? '신청 중…' : '바로 신청하기',
            onPressed: _submitting ? null : _apply,
          ),

        if (benefit.foot != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              benefit.foot!,
              style: appText(size: 12, height: 1.7, color: AppColors.mutedWeak),
            ),
          ),
        ],
      ],
    );
  }
}
