import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/rows.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../domain/certification.dart';
import 'certification_controller.dart';

/// 인증 확인증 · 이력 (프로토타입 화면 4).
class CertificationScreen extends ConsumerWidget {
  const CertificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(certificationControllerProvider).certification;
    final historyAsync = ref.watch(certificationHistoryProvider);
    final history = historyAsync.value ?? const <Certification>[];

    // 확인증은 지금 유효한 인증을 우선 보여 주고, 없으면 가장 최근 인증 건을 보여 준다.
    final receipt = (active != null && active.ok)
        ? active
        : history.where((c) => c.ok).firstOrNull;

    return ScreenScaffold(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackTextButton(label: '홈', onTap: () => context.go(Routes.home)),
          if (receipt != null)
            _ReceiptCard(cert: receipt)
          else
            const EmptyState(message: '아직 인증 기록이 없어요 🅿️\n장애인주차면에 주차하면 자동으로 인증됩니다.'),

          const SectionHeader(title: '인증 이력'),

          if (historyAsync.isLoading && history.isEmpty)
            const Loading()
          else if (history.isEmpty)
            const EmptyState(message: '인증 이력이 없어요')
          else
            Column(
              children: [
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _HistoryRow(cert: history[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// 다크 확인증 카드.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.cert});

  final Certification cert;

  @override
  Widget build(BuildContext context) {
    final at = cert.verifiedAt ?? cert.startedAt;

    return DarkGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(
            label: '✓ 탑승 인증 확인증',
            background: AppColors.mintLight.withValues(alpha: .15),
            foreground: AppColors.mintLight,
            fontSize: 11.5,
            emSpacing: .06,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          ),
          const SizedBox(height: 14),
          Text(
            '인증 완료\n단속 대상 제외',
            style: appText(
              size: 27,
              weight: 900,
              height: 1.25,
              color: Colors.white,
              emSpacing: -.02,
            ),
          ),
          const SizedBox(height: 14),
          DarkKeyValueRow(label: '장소', value: cert.spotName ?? '—'),
          DarkKeyValueRow(label: '시각', value: receiptTime(at)),
          DarkKeyValueRow(label: '차량', value: cert.plate ?? '—'),
          DarkKeyValueRow(label: '인증 방식', value: cert.methodLabel),
          DarkKeyValueRow(
            label: '주차 요금',
            value: cert.feeNote ?? '무료 · 장애인 감면 적용',
          ),
          if (cert.receiptNo != null)
            DarkKeyValueRow(label: '확인번호', value: cert.receiptNo!),
        ],
      ),
    );
  }
}

/// 이력 한 줄. 인증/미인증을 색만이 아니라 ✓ · ! 아이콘으로도 구분한다.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.cert});

  final Certification cert;

  @override
  Widget build(BuildContext context) {
    final ok = cert.ok;
    final chipBg = ok ? AppColors.mintA(.12) : AppColors.inkA(.06);
    final chipFg = ok ? AppColors.mintDeep : AppColors.mutedWeak;

    return ListRowCard(
      titleSize: 13.5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      leading: IconChip.text(
        ok ? '✓' : '!',
        size: 38,
        radius: 14,
        fontSize: 15,
        background: chipBg,
        foreground: chipFg,
      ),
      title: cert.spotName ?? '—',
      subtitle: '${relativeTime(cert.startedAt)} · '
          '${ok ? cert.method.label : cert.failReason ?? '인증 없음'}',
      trailing: Text(
        ok ? '인증' : '미인증',
        style: appText(size: 11.5, weight: 700, color: chipFg),
      ),
    );
  }
}
