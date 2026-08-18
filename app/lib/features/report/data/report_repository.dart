import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/report.dart';

/// 부정주차 신고와 내가 받은 경고.
abstract class ReportRepository {
  /// 사진은 비공개 버킷 `reports/{uid}/…`에 올라가고 접수번호는 서버가 발급한다.
  Future<Report> submit({
    required ReportReason reason,
    File? photo,
    String? spotId,
    String? memo,
  });

  Future<List<Warning>> warnings();
}

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw StateError('로그인이 필요합니다');
    return id;
  }

  @override
  Future<Report> submit({
    required ReportReason reason,
    File? photo,
    String? spotId,
    String? memo,
  }) async {
    String? path;
    if (photo != null) {
      path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _db.storage.from('reports').upload(path, photo);
    }

    final row = await _db.rpc('submit_report', params: {
      'p_reason': reason.code,
      'p_photo_path': path,
      'p_spot_id': spotId,
      'p_memo': memo,
    });

    return Report.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<List<Warning>> warnings() async {
    final rows = await _db
        .from('warnings')
        .select()
        .eq('user_id', _uid)
        .order('occurred_at', ascending: false);
    return rows.map(Warning.fromMap).toList();
  }
}
