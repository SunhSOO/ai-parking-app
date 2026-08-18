import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../domain/facility.dart';
import 'facility_controller.dart';

/// 체육·생활시설 검색 (프로토타입 화면 8).
class FacilitiesScreen extends ConsumerWidget {
  const FacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(facilityCategoryProvider);
    final list = ref.watch(facilityListProvider);

    return ScreenScaffold(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 26),
            child: ScreenHeader(
              title: '체육·생활시설',
              subtitle: '예약하면 목적지 주차면까지 함께 잡아 드려요',
              padding: EdgeInsets.zero,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _SearchField(),
          ),
          ChipRow(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            children: [
              for (final category in FacilityCategory.values)
                PillChip(
                  label: category.label,
                  selected: selected == category.id,
                  onTap: () => ref
                      .read(facilityCategoryProvider.notifier)
                      .set(category.id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: switch (list) {
              AsyncValue(hasError: true) => ErrorState(
                  message: '시설을 불러오지 못했어요',
                  onRetry: () => ref.invalidate(facilityListProvider),
                ),
              AsyncValue(value: final items?) when items.isEmpty =>
                const EmptyState(message: '검색 결과가 없어요 🔍'),
              AsyncValue(value: final items?) => Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _FacilityCard(facility: items[i]),
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

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(facilityQueryProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pill,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: TextField(
        controller: _controller,
        onChanged: (value) =>
            ref.read(facilityQueryProvider.notifier).set(value),
        textInputAction: TextInputAction.search,
        style: appText(size: 14),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: '🔍 시설·프로그램 검색',
          hintStyle: appText(size: 14, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.facility});

  final Facility facility;

  /// 카테고리별 아이콘 칩 배경 — 프로토타입의 tint 값.
  Color get _chipBackground => switch (facility.cat) {
        'sports' => AppColors.blueA(.12),
        'rehab' => AppColors.mintA(.12),
        'culture' => AppColors.purpleA(.1),
        'life' => AppColors.orangeA(.14),
        _ => AppColors.yellowA(.18),
      };

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.all(16),
      onTap: () => context.go(Routes.facilityBook(facility.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            size: 50,
            radius: 18,
            background: _chipBackground,
            child: Text(facility.icon, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(facility.name, style: AppText.cardTitle(15)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      facility.distanceLabelText,
                      style: appText(
                        size: 11.5,
                        weight: 700,
                        color: AppColors.inkA(.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  facility.description,
                  style: appText(size: 12, height: 1.55, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (facility.tag != null) AppBadge.mint(facility.tag!),
                    AppBadge.neutral('주차 ${facility.parkingLabel}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
