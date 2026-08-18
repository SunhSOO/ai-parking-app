import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

/// 프로필 · 등록 차량 · 알림 설정.
abstract class ProfileRepository {
  Future<Profile?> fetchProfile();

  /// 온보딩에서 확인한 자격 정보를 저장한다.
  Future<Profile> saveProfile(Profile profile);

  Future<List<Vehicle>> fetchVehicles();

  /// 대표 차량 번호를 등록/수정한다.
  Future<Vehicle> savePrimaryVehicle(String plate);

  /// 혜택 알림 토글 하나를 바꾼다.
  Future<Profile> setNotif(String key, bool value);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw StateError('로그인이 필요합니다');
    return id;
  }

  @override
  Future<Profile?> fetchProfile() async {
    final row = await _db.from('profiles').select().eq('id', _uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  @override
  Future<Profile> saveProfile(Profile profile) async {
    final row = await _db
        .from('profiles')
        .update(profile.toMap())
        .eq('id', _uid)
        .select()
        .single();
    return Profile.fromMap(row);
  }

  @override
  Future<List<Vehicle>> fetchVehicles() async {
    final rows = await _db
        .from('vehicles')
        .select()
        .eq('user_id', _uid)
        .order('is_primary', ascending: false);
    return rows.map(Vehicle.fromMap).toList();
  }

  @override
  Future<Vehicle> savePrimaryVehicle(String plate) async {
    final existing = await _db
        .from('vehicles')
        .select('id')
        .eq('user_id', _uid)
        .eq('is_primary', true)
        .maybeSingle();

    final row = existing == null
        ? await _db
            .from('vehicles')
            .insert({'user_id': _uid, 'plate': plate, 'is_primary': true})
            .select()
            .single()
        : await _db
            .from('vehicles')
            .update({'plate': plate})
            .eq('id', existing['id'] as String)
            .select()
            .single();

    return Vehicle.fromMap(row);
  }

  @override
  Future<Profile> setNotif(String key, bool value) async {
    final current = await fetchProfile();
    final notif = Map<String, bool>.from(current?.notif ?? const {})
      ..[key] = value;
    final row = await _db
        .from('profiles')
        .update({'notif': notif})
        .eq('id', _uid)
        .select()
        .single();
    return Profile.fromMap(row);
  }
}
