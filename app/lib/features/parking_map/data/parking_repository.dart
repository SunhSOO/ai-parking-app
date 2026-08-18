import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parking_spot.dart';

/// 주변 장애인주차면 조회. 지도 화면과 지오펜스 등록이 같은 경로를 쓴다.
abstract class ParkingRepository {
  /// iOS 지오펜스 상한이 20개라 기본 [limit]도 20이다.
  Future<List<ParkingSpot>> nearby({
    required double lat,
    required double lng,
    int radiusM = 3000,
    int limit = 20,
  });

  Future<ParkingSpot?> byId(String id);
}

class SupabaseParkingRepository implements ParkingRepository {
  SupabaseParkingRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<ParkingSpot>> nearby({
    required double lat,
    required double lng,
    int radiusM = 3000,
    int limit = 20,
  }) async {
    final rows = await _db.rpc('nearby_spots', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_m': radiusM,
      'p_limit': limit,
    }) as List;

    return rows
        .cast<Map<String, dynamic>>()
        .map(ParkingSpot.fromMap)
        .toList();
  }

  @override
  Future<ParkingSpot?> byId(String id) async {
    // geography 컬럼을 lat/lng으로 펼친 뷰를 읽는다.
    final row =
        await _db.from('parking_spots_geo').select().eq('id', id).maybeSingle();
    return row == null ? null : ParkingSpot.fromMap(row);
  }
}
