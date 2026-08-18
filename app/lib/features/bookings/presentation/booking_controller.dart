import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers.dart';
import '../domain/booking.dart';

/// 내 예약 목록. 예약·취소가 끝나면 스스로 갱신한다.
final bookingsProvider =
    AsyncNotifierProvider<BookingsController, List<Booking>>(
  BookingsController.new,
);

class BookingsController extends AsyncNotifier<List<Booking>> {
  @override
  Future<List<Booking>> build() => ref.watch(bookingRepositoryProvider).list();

  /// 시간 슬롯을 예약한다. 잔여 슬롯과 목적지 주차면 확보는 서버가 한 트랜잭션으로 처리한다.
  Future<Booking> book(String slotId) async {
    final booking = await ref.read(bookingRepositoryProvider).book(slotId);
    ref.invalidateSelf();
    await future;
    return booking;
  }

  Future<void> cancel(String bookingId) async {
    // 취소는 즉시 목록에서 빠지는 게 자연스러우므로 낙관적으로 먼저 지운다.
    final previous = state.value;
    if (previous != null) {
      state = AsyncValue.data(
        previous.where((b) => b.id != bookingId).toList(),
      );
    }

    try {
      await ref.read(bookingRepositoryProvider).cancel(bookingId);
      ref.invalidateSelf();
    } catch (e, st) {
      state = previous == null
          ? AsyncValue.error(e, st)
          : AsyncValue.data(previous);
      rethrow;
    }
  }
}
