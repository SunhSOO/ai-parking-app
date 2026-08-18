import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/simple_notifier.dart';
import '../../../services/providers.dart';
import '../domain/facility.dart';

/// 시설 검색어 (이름·설명·태그 부분 일치).
final facilityQueryProvider = NotifierProvider<SimpleNotifier<String>, String>(
  () => SimpleNotifier(''),
);

/// 선택된 시설 카테고리 칩.
final facilityCategoryProvider =
    NotifierProvider<SimpleNotifier<String>, String>(
  () => SimpleNotifier('all'),
);

/// 필터가 적용된 시설 목록.
final facilityListProvider = FutureProvider<List<Facility>>((ref) async {
  final category = ref.watch(facilityCategoryProvider);
  final query = ref.watch(facilityQueryProvider);
  return ref.watch(facilityRepositoryProvider).list(
        categoryId: category,
        query: query,
      );
});

final facilityDetailProvider =
    FutureProvider.family<Facility?, String>((ref, id) async {
  return ref.watch(facilityRepositoryProvider).byId(id);
});

/// 오늘부터 7일치 예약 슬롯.
final facilitySlotsProvider =
    FutureProvider.family<List<FacilitySlot>, String>((ref, facilityId) async {
  return ref.watch(facilityRepositoryProvider).slots(facilityId);
});

/// 예약 화면에서 고른 날짜(자정 기준)와 슬롯.
final selectedDateProvider =
    NotifierProvider<SimpleNotifier<DateTime?>, DateTime?>(
  () => SimpleNotifier(null),
);

final selectedSlotIdProvider =
    NotifierProvider<SimpleNotifier<String?>, String?>(
  () => SimpleNotifier(null),
);

/// 슬롯 목록에서 날짜만 뽑아 정렬한다 — 날짜 칩 행에 쓴다.
List<DateTime> datesOf(List<FacilitySlot> slots) {
  final days = <DateTime>{};
  for (final slot in slots) {
    days.add(DateTime(slot.slotAt.year, slot.slotAt.month, slot.slotAt.day));
  }
  return days.toList()..sort();
}

/// 특정 날짜의 슬롯만 시간순으로.
List<FacilitySlot> slotsOn(List<FacilitySlot> slots, DateTime? day) {
  if (day == null) return const [];
  return slots
      .where((s) =>
          s.slotAt.year == day.year &&
          s.slotAt.month == day.month &&
          s.slotAt.day == day.day)
      .toList()
    ..sort((a, b) => a.slotAt.compareTo(b.slotAt));
}
