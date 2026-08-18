import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/benefit.dart';

/// 복지혜택 피드 · 상세 · 신청.
///
/// 적합도와 근거 태그는 서버 함수 `benefits_for_me()`가 계산해서 내려준다.
abstract class BenefitRepository {
  /// [categoryId]가 null이거나 'all'이면 전체
  Future<List<Benefit>> feed({String? categoryId});

  Future<Benefit?> byId(String id);

  Future<void> apply(String benefitId);
}

class SupabaseBenefitRepository implements BenefitRepository {
  SupabaseBenefitRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Benefit>> feed({String? categoryId}) async {
    final rows = await _db.rpc('benefits_for_me', params: {
      'p_cat': categoryId,
    }) as List;
    return rows.cast<Map<String, dynamic>>().map(Benefit.fromMap).toList();
  }

  @override
  Future<Benefit?> byId(String id) async {
    final all = await feed();
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<void> apply(String benefitId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인이 필요합니다');

    await _db.from('benefit_applications').upsert(
      {'user_id': uid, 'benefit_id': benefitId},
      onConflict: 'user_id,benefit_id',
    );
  }
}
