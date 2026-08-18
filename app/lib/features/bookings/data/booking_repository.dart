import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/booking.dart';

/// 내 예약.
///
/// 예약 생성/취소는 잔여 슬롯과 주차면 확보를 한 트랜잭션으로 처리해야 하므로
/// 테이블에 직접 쓰지 않고 RPC(`book_facility_slot` / `cancel_booking`)만 호출한다.
abstract class BookingRepository {
  Future<List<Booking>> list();

  Future<Booking> book(String slotId);

  Future<void> cancel(String bookingId);
}

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Booking>> list() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인이 필요합니다');

    final rows = await _db
        .from('bookings_view')
        .select()
        .eq('user_id', uid)
        .neq('status', 'cancelled')
        .order('slot_at');

    return rows.map(Booking.fromMap).toList();
  }

  @override
  Future<Booking> book(String slotId) async {
    final row = await _db.rpc('book_facility_slot', params: {
      'p_slot_id': slotId,
    });
    final booking = Map<String, dynamic>.from(row as Map);

    // RPC는 bookings 행만 돌려주므로 화면 표시에 필요한 이름·시각을 다시 읽는다.
    final full = await _db
        .from('bookings_view')
        .select()
        .eq('id', booking['id'] as String)
        .single();
    return Booking.fromMap(full);
  }

  @override
  Future<void> cancel(String bookingId) async {
    await _db.rpc('cancel_booking', params: {'p_booking_id': bookingId});
  }
}
