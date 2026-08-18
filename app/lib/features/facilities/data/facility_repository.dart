import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/facility.dart';

/// 체육·생활시설 검색과 예약 슬롯.
abstract class FacilityRepository {
  /// 카테고리 필터와 검색어(이름·설명·태그 부분 일치)를 함께 적용한다.
  Future<List<Facility>> list({String? categoryId, String query = ''});

  Future<Facility?> byId(String id);

  /// 오늘부터 [days]일치 슬롯. 화면에서 날짜별로 묶는다.
  Future<List<FacilitySlot>> slots(String facilityId, {int days = 7});
}

class SupabaseFacilityRepository implements FacilityRepository {
  SupabaseFacilityRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Facility>> list({String? categoryId, String query = ''}) async {
    var q = _db.from('facilities_geo').select();
    if (categoryId != null && categoryId != 'all') {
      q = q.eq('cat', categoryId);
    }
    final rows = await q.order('name');

    final all = rows.map(Facility.fromMap).toList();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return all;
    return all.where((f) => f.matches(trimmed)).toList();
  }

  @override
  Future<Facility?> byId(String id) async {
    final row =
        await _db.from('facilities_geo').select().eq('id', id).maybeSingle();
    return row == null ? null : Facility.fromMap(row);
  }

  @override
  Future<List<FacilitySlot>> slots(String facilityId, {int days = 7}) async {
    final now = DateTime.now();
    final until = now.add(Duration(days: days));

    final rows = await _db
        .from('facility_slots')
        .select()
        .eq('facility_id', facilityId)
        .gte('slot_at', now.toUtc().toIso8601String())
        .lte('slot_at', until.toUtc().toIso8601String())
        .order('slot_at');

    return rows.map(FacilitySlot.fromMap).toList();
  }
}
