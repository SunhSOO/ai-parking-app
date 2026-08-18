import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../certification/domain/certification.dart';
import '../../certification/presentation/certification_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/parking_spot.dart';
import 'parking_controller.dart';
import 'widgets/mock_map_view.dart';
import 'widgets/naver_map_view.dart';

/// 주변 장애인주차면 지도 (프로토타입 화면 5).
class ParkingMapScreen extends ConsumerWidget {
  const ParkingMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(nearbySpotsProvider);
    final location = ref.watch(currentLocationProvider).value ?? fallbackLatLng;
    final selectedId = ref.watch(selectedSpotIdProvider);
    final profile = ref.watch(profileProvider).value;
    final spots = spotsAsync.value ?? const <ParkingSpot>[];

    final updatedAt = spots
        .map((s) => s.updatedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: '주변 장애인주차면',
            subtitle: [
              profile?.sigungu ?? '현재 위치',
              if (updatedAt != null) '${_minutesAgo(updatedAt)} 갱신',
            ].join(' · '),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 240,
            child: AppConfig.hasNaverMap
                ? NaverMapView(
                    spots: spots,
                    center: location,
                    selectedId: selectedId,
                    onSelect: (id) =>
                        ref.read(selectedSpotIdProvider.notifier).set(id),
                  )
                : MockMapView(
                    spots: spots,
                    center: location,
                    selectedId: selectedId,
                    onSelect: (id) =>
                        ref.read(selectedSpotIdProvider.notifier).set(id),
                  ),
          ),
          const SizedBox(height: 14),

          if (spotsAsync.isLoading && spots.isEmpty)
            const Loading()
          else if (spotsAsync.hasError)
            ErrorState(
              message: '주차면을 불러오지 못했어요',
              onRetry: () => ref.invalidate(nearbySpotsProvider),
            )
          else if (spots.isEmpty)
            const EmptyState(message: '주변에 등록된 장애인주차면이 없어요')
          else
            Column(
              children: [
                for (var i = 0; i < spots.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SpotCard(spot: spots[i], selected: spots[i].id == selectedId),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _minutesAgo(DateTime at) {
    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes < 1) return '방금';
    if (minutes < 60) return '$minutes분 전';
    return historyTime(at);
  }
}

/// 주차면 카드. 선택하면 아래에 액션 두 개가 열린다.
class _SpotCard extends ConsumerWidget {
  const _SpotCard({required this.spot, required this.selected});

  final ParkingSpot spot;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceCard(
      radius: AppRadius.r22,
      padding: const EdgeInsets.all(16),
      border: Border.all(
        color: selected ? AppColors.purpleA(.5) : Colors.transparent,
        width: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            selected: selected,
            label: '${spot.name}, ${spot.leftLabel}, ${spot.metaLine}',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(selectedSpotIdProvider.notifier).set(spot.id),
                child: Row(
                  children: [
                    IconChip.text(
                      spot.leftLabel,
                      size: 50,
                      radius: 18,
                      fontSize: 15,
                      background: spot.isFull
                          ? AppColors.inkA(.06)
                          : AppColors.purpleA(.1),
                      foreground:
                          spot.isFull ? AppColors.inkA(.4) : AppColors.purple,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(spot.name, style: AppText.cardTitle(15)),
                          const SizedBox(height: 3),
                          Text(spot.metaLine, style: AppText.meta(11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: spot.isFull ? '빈자리 알림 받기' : '여기서 인증 실행',
                    height: AppSizes.actionHeight,
                    fontSize: 14,
                    shadow: AppShadows.primaryButtonSmall,
                    onPressed: () => _onAction(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                SoftButton(
                  label: '길 안내',
                  fontSize: 14,
                  expand: false,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('길 안내는 준비 중이에요')),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref) async {
    if (spot.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${spot.name}에 빈자리가 생기면 알려 드릴게요')),
      );
      return;
    }
    await ref
        .read(certificationControllerProvider.notifier)
        .start(spot.id, method: CertMethod.manual);
  }
}
