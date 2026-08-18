import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/certification.dart';

/// 자동 인증 세션.
///
/// 상태 전이(detecting → matching → sending → verified)는 **서버가** 한다.
/// 앱은 [start]로 시작만 시키고 [watch]로 구독한다. 시트를 닫아도(숨기기)
/// 세션은 그대로 진행되므로, 화면 생명주기와 이 스트림은 무관하다.
abstract class CertificationRepository {
  /// 진행 중이거나 방금 완료된 세션. 없으면 null.
  Future<Certification?> active();

  Future<Certification> start(String spotId, {CertMethod method});

  Stream<Certification> watch(String certificationId);

  Future<List<Certification>> history({int limit = 20});

  /// 주차면 이탈 — 인증 종료
  Future<void> end(String certificationId);
}

class SupabaseCertificationRepository implements CertificationRepository {
  SupabaseCertificationRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw StateError('로그인이 필요합니다');
    return id;
  }

  @override
  Future<Certification?> active() async {
    final row = await _db
        .from('certifications')
        .select()
        .eq('user_id', _uid)
        .isFilter('ended_at', null)
        .inFilter('status', ['detecting', 'matching', 'sending', 'verified'])
        .maybeSingle();
    return row == null ? null : Certification.fromMap(row);
  }

  @override
  Future<Certification> start(String spotId, {CertMethod method = CertMethod.autoGeofence}) async {
    final row = await _db.rpc('start_certification', params: {
      'p_spot_id': spotId,
      'p_method': method.code,
    });
    return Certification.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Stream<Certification> watch(String certificationId) {
    return _db
        .from('certifications')
        .stream(primaryKey: ['id'])
        .eq('id', certificationId)
        .map((rows) => Certification.fromMap(rows.first));
  }

  @override
  Future<List<Certification>> history({int limit = 20}) async {
    final rows = await _db
        .from('certifications')
        .select()
        .eq('user_id', _uid)
        .order('started_at', ascending: false)
        .limit(limit);
    return rows.map(Certification.fromMap).toList();
  }

  @override
  Future<void> end(String certificationId) async {
    await _db.rpc('end_certification', params: {'p_cert_id': certificationId});
  }
}
