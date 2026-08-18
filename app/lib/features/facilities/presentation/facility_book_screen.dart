import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../bookings/presentation/booking_controller.dart';
import '../domain/facility.dart';
import 'facility_controller.dart';

/// 시설 예약 (프로토타입 화면 9).
class FacilityBookScreen extends ConsumerWidget {
  const FacilityBookScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facility = ref.watch(facilityDetailProvider(facilityId));
    final slots = ref.watch(facilitySlotsProvider(facilityId));

    return ScreenScaffold(
      child: switch ((facility, slots)) {
        (AsyncValue(value: final f?), AsyncValue(value: final s?)) =>
          _BookForm(facility: f, slots: s),
        (AsyncValue(hasError: true), _) || (_, AsyncValue(hasError: true)) =>
          ErrorState(
            message: '시설 정보를 불러오지 못했어요',
            onRetry: () {
              ref.invalidate(facilityDetailProvider(facilityId));
              ref.invalidate(facilitySlotsProvider(facilityId));
            },
          ),
        _ => const Loading(height: 400),
      },
    );
  }
}

class _BookForm extends ConsumerWidget {
  const _BookForm({required this.facility, required this.slots});

  final Facility facility;
  final List<FacilitySlot> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = datesOf(slots);
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedSlotId = ref.watch(selectedSlotIdProvider);
    final daySlots = slotsOn(slots, selectedDate);

    final selectedSlot = selectedSlotId == null
        ? null
        : daySlots.where((s) => s.id == selectedSlotId).firstOrNull;

    final month = (selectedDate ?? days.firstOrNull ?? DateTime.now()).month;

    Future<void> confirm() async {
      if (selectedSlot == null) return;
      try {
        await ref.read(bookingsProvider.notifier).book(selectedSlot.id);
        ref.read(selectedDateProvider.notifier).set(null);
        ref.read(selectedSlotIdProvider.notifier).set(null);
        ref.invalidate(facilitySlotsProvider(facility.id));
        if (!context.mounted) return;
        context.go(Routes.bookings);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예약하지 못했어요: $e')),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackTextButton(label: '시설', onTap: () => context.go(Routes.facilities)),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (facility.tag != null) AppBadge.mint(facility.tag!),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(facility.name, style: AppText.heading(23)),
              ),
              const SizedBox(height: 6),
              Text(
                facility.description,
                style: appText(size: 13, height: 1.7, color: AppColors.mutedStrong),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------------------------------------------------------- 날짜
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 9),
          child: Text('날짜 · $month월', style: appText(size: 13.5, weight: 900)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              for (final day in days) ...[
                _DateChip(
                  day: day,
                  selected: selectedDate != null &&
                      selectedDate.day == day.day &&
                      selectedDate.month == day.month,
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).set(day);
                    ref.read(selectedSlotIdProvider.notifier).set(null);
                  },
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------------------------------------------------------- 시간
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 9),
          child: Text('시간', style: appText(size: 13.5, weight: 900)),
        ),
        if (selectedDate == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('날짜를 먼저 골라 주세요', style: AppText.meta(13)),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.9,
            children: [
              for (final slot in daySlots)
                _TimeChip(
                  slot: slot,
                  selected: selectedSlotId == slot.id,
                  onTap: slot.isFull
                      ? null
                      : () =>
                          ref.read(selectedSlotIdProvider.notifier).set(slot.id),
                ),
            ],
          ),
        const SizedBox(height: 14),

        // ------------------------------------------------ 목적지 주차면 안내
        TintCard(
          radius: AppRadius.r20,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '🅿️ 목적지 주차면',
                    style: appText(size: 13, weight: 700, color: AppColors.purple),
                  ),
                  const Spacer(),
                  Text(
                    facility.parkingLine,
                    style: appText(size: 13, weight: 900),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '예약과 함께 1면을 잡아 두고, 도착하면 인증 팝업이 저절로 떠서 스스로 끝나요.',
                style: appText(
                  size: 12,
                  height: 1.65,
                  color: AppColors.mutedStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        GradientButton(
          label: selectedSlot == null
              ? '날짜와 시간을 골라 주세요'
              : '${monthDay(selectedSlot.slotAt)} ${selectedSlot.timeLabel} 예약하기',
          onPressed: selectedSlot == null ? null : confirm,
        ),
      ],
    );
  }
}

/// 52×66 날짜 칩 — 요일 + 일.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${monthDay(day)} ${weekdayLabel(day)}요일',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            constraints: const BoxConstraints(minHeight: 66),
            decoration: BoxDecoration(
              gradient: selected ? AppGradients.primaryDiagonal : null,
              color: selected ? null : AppColors.surface,
              borderRadius: AppRadius.r18,
              boxShadow:
                  selected ? AppShadows.primaryButtonSmall : AppShadows.chip,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayLabel(day),
                  style: appText(
                    size: 11,
                    weight: 500,
                    color: selected
                        ? Colors.white.withValues(alpha: .7)
                        : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  style: appText(
                    size: 18,
                    weight: 900,
                    color: selected ? Colors.white : AppColors.ink,
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

/// 시간 칩 — 마감된 슬롯은 흐리게 + 누를 수 없게.
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final FacilitySlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: '${slot.timeLabel} ${slot.note}',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? .4 : 1,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.primaryDiagonal : null,
                color: selected ? null : AppColors.surface,
                borderRadius: AppRadius.r18,
                boxShadow:
                    selected ? AppShadows.primaryButtonSmall : AppShadows.chip,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot.timeLabel,
                    style: appText(
                      size: 16,
                      weight: 900,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slot.note,
                    style: appText(
                      size: 11,
                      weight: 500,
                      color: selected
                          ? Colors.white.withValues(alpha: .75)
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
