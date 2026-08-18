import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/rows.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../benefits/domain/benefit.dart';
import '../../benefits/presentation/benefit_controller.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/presentation/booking_controller.dart';
import '../../certification/domain/certification.dart';
import '../../certification/presentation/certification_controller.dart';
import '../../../services/geofence_service.dart';
import '../../parking_map/presentation/parking_controller.dart';
import '../../profile/presentation/profile_controller.dart';

/// 홈 · 인증 상태 대시보드 (프로토타입 화면 2).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;

    return ScreenScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인사 + 아바타
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('안녕하세요 👋', style: AppText.meta(12.5)),
                      const SizedBox(height: 1),
                      Text(
                        '${profile?.name ?? ''}님',
                        style: appText(size: 21, weight: 900, emSpacing: -.02),
                      ),
                    ],
                  ),
                ),
                GradientAvatar(
                  initials: profile?.initials ?? '·',
                  onTap: () => context.go(Routes.profile),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _StatusHeroCard(),

          const _BackgroundPermissionNotice(),

          const SizedBox(height: 14),
          const _StatsGrid(),

          SectionHeader(
            title: '오늘의 알림',
            action: '모두 보기',
            onAction: () => context.go(Routes.benefits),
          ),
          const _AlertList(),

          const SizedBox(height: 14),
          DashedPillButton(
            label: '🚨 부정주차 신고하기',
            onPressed: () => context.push(Routes.report),
          ),
        ],
      ),
    );
  }
}

/// 히어로 상태 카드 — 대기 / 진행 중 / 완료 3모드.
class _StatusHeroCard extends ConsumerWidget {
  const _StatusHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(certificationControllerProvider);
    final cert = state.certification;
    final running = state.isRunning;
    final done = state.isVerified;
    final nearest = ref.watch(nearestAvailableSpotProvider);

    final (tag, head1, head2, sub, cta) = switch ((done, running)) {
      (true, _) => (
          '인증 완료 · 단속 제외',
          cert?.spotName?.split(' · ').first ?? '주차 중',
          '단속 대상 제외',
          '이 자리는 단속 대상에서 제외돼 있어요. 자리를 뜨면 인증이 자동으로 종료됩니다.',
          '확인증 보기',
        ),
      (_, true) => (
          '자동 인증 진행 중',
          '인증하고',
          '있어요',
          '누르지 않아도 끝나요. 화면을 꺼도 계속 진행됩니다.',
          '진행 보기',
        ),
      _ => (
          '자동 인증 대기 중',
          '주차하면',
          '알아서 인증돼요',
          '장애인주차면 반경에 들어오면 인증 팝업이 저절로 떠서 스스로 끝나요. 누를 게 없습니다.',
          '지금 인증 실행',
        ),
    };

    Future<void> onCta() async {
      if (done) {
        context.go(Routes.certification);
        return;
      }
      if (running) {
        ref.read(certificationControllerProvider.notifier).show();
        return;
      }
      // 대기 상태에서의 수동 실행 — 가장 가까운 빈 자리를 대상으로 한다.
      final spot = nearest;
      if (spot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가까운 장애인주차면을 찾지 못했어요')),
        );
        return;
      }
      await ref
          .read(certificationControllerProvider.notifier)
          .start(spot.id, method: CertMethod.manual);
    }

    return ClipRRect(
      borderRadius: AppRadius.r28,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: AppRadius.r28,
          boxShadow: AppShadows.hero,
        ),
        child: Stack(
          children: [
            // 장식용 반투명 원 2개
            Positioned(
              right: -40,
              top: -40,
              child: _Circle(size: 160, opacity: .10),
            ),
            Positioned(
              right: 20,
              bottom: -60,
              child: _Circle(size: 120, opacity: .08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlinkDot(
                        color: AppColors.mintLight,
                        animate: running,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tag,
                        style: appText(
                          size: 11.5,
                          weight: 700,
                          color: Colors.white.withValues(alpha: .9),
                          emSpacing: .06,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$head1\n$head2',
                    style: appText(
                      size: 29,
                      weight: 900,
                      height: 1.2,
                      color: Colors.white,
                      emSpacing: -.02,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      sub,
                      style: appText(
                        size: 13,
                        height: 1.65,
                        color: Colors.white.withValues(alpha: .85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OnHeroFilledButton(label: cta, onPressed: onCta),
                      ),
                      const SizedBox(width: 8),
                      OnHeroOutlineButton(
                        label: '주차면',
                        onPressed: () => context.go(Routes.map),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위치가 "항상 허용"이 아니면 화면을 꺼 둔 사이에는 인증이 되지 않는다.
/// 그 사실을 숨기지 않고 알리고, 수동 실행이 주 경로임을 안내한다.
class _BackgroundPermissionNotice extends ConsumerWidget {
  const _BackgroundPermissionNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(backgroundPermissionProvider).value;
    if (granted == null || granted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SurfaceCard(
        radius: AppRadius.r20,
        color: AppColors.orangeA(.12),
        shadow: const [],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () async {
          await GeofenceService.instance.requestLocationPermission();
          ref.invalidate(backgroundPermissionProvider);
        },
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '지금은 앱을 열어 둔 동안만 인증돼요.\n'
                '위치를 "항상 허용"으로 바꾸면 화면을 꺼도 알아서 끝나요.',
                style: appText(
                  size: 12.5,
                  height: 1.6,
                  weight: 500,
                  color: AppColors.warningDeep,
                ),
              ),
            ),
            Text('›', style: appText(size: 16, color: AppColors.warningDeep)),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// 2×2 통계 타일.
class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(certificationHistoryProvider).value ?? const [];
    final benefits = ref.watch(allBenefitsProvider).value ?? const [];
    final bookings = ref.watch(bookingsProvider).value ?? const [];
    final nearest = ref.watch(nearestAvailableSpotProvider);

    final now = DateTime.now();
    final thisMonth = history
        .where((c) =>
            c.ok && c.startedAt.year == now.year && c.startedAt.month == now.month)
        .length;
    final newBenefits = benefits.where((b) => !b.applied).length;

    final tiles = [
      (
        value: '$thisMonth회',
        label: '이번 달 인증',
        color: AppColors.purple,
        go: Routes.certification,
      ),
      (
        value: '$newBenefits건',
        label: '새 맞춤 혜택',
        color: AppColors.greenText,
        go: Routes.benefits,
      ),
      (
        value: '${bookings.length}건',
        label: '다가오는 예약',
        color: AppColors.blueText,
        go: Routes.bookings,
      ),
      (
        value: nearest == null ? '—' : '${nearest.available}면',
        label: '가까운 빈 자리',
        color: AppColors.warning,
        go: Routes.map,
      ),
    ];

    // 고정 비율 그리드를 쓰지 않는 이유: 글자 크기를 키운 사용자에게 타일이 넘친다.
    // 각 줄은 내용 높이를 따르고, 같은 줄의 두 타일만 서로 높이를 맞춘다.
    Widget row(int a, int b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in [a, b]) ...[
                if (i == b) const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    value: tiles[i].value,
                    label: tiles[i].label,
                    color: tiles[i].color,
                    onTap: () => context.go(tiles[i].go),
                  ),
                ),
              ],
            ],
          ),
        );

    return Column(
      children: [row(0, 1), const SizedBox(height: 10), row(2, 3)],
    );
  }
}

/// "오늘의 알림" — 마감 임박 혜택 1건 + 다가오는 예약 1건.
class _AlertList extends ConsumerWidget {
  const _AlertList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benefits = ref.watch(allBenefitsProvider).value ?? const [];
    final bookings = ref.watch(bookingsProvider).value ?? const [];

    final urgent = _mostUrgent(benefits);
    final next = bookings.isEmpty ? null : bookings.first;

    if (urgent == null && next == null) {
      return const EmptyState(message: '오늘 확인할 알림이 없어요 ☀️');
    }

    return Column(
      children: [
        if (urgent != null)
          ListRowCard(
            leading: IconChip.text(
              _badgeOf(urgent),
              background: AppColors.purpleA(.1),
              foreground: AppColors.purple,
            ),
            title: urgent.title,
            subtitle: '${urgent.dueText} · 서류 없이 신청 가능',
            trailing: Text('›', style: appText(size: 16, color: AppColors.inkA(.3))),
            onTap: () => context.go(Routes.benefitDetail(urgent.id)),
          ),
        if (urgent != null && next != null) const SizedBox(height: 10),
        if (next != null)
          ListRowCard(
            leading: IconChip.text(
              '예약',
              background: AppColors.mintA(.12),
              foreground: AppColors.mintDeep,
            ),
            title: '${next.title} · ${_whenShort(next)}',
            subtitle: next.metaLabel,
            trailing: Text('›', style: appText(size: 16, color: AppColors.inkA(.3))),
            onTap: () => context.go(Routes.bookings),
          ),
      ],
    );
  }

  /// 마감이 가장 임박한, 아직 신청하지 않은 혜택
  Benefit? _mostUrgent(List<Benefit> benefits) {
    final candidates = benefits
        .where((b) => !b.applied && b.dueDate != null)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return candidates.isEmpty ? null : candidates.first;
  }

  /// `D-9` — 배지에는 D-day만 넣는다
  String _badgeOf(Benefit benefit) => benefit.dueText.split(' · ').first;

  /// `내일 10:30` / `8월 12일 10:30`
  String _whenShort(Booking booking) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final slot = booking.slotAt;
    final isTomorrow = slot.year == tomorrow.year &&
        slot.month == tomorrow.month &&
        slot.day == tomorrow.day;
    return isTomorrow ? '내일 ${hhmm(slot)}' : '${monthDay(slot)} ${hhmm(slot)}';
  }
}
