import '../../../core/util/format.dart';

/// 혜택 피드의 카테고리 칩.
class BenefitCategory {
  const BenefitCategory(this.id, this.label);

  final String id;
  final String label;

  static const all = BenefitCategory('all', '전체');

  static const values = <BenefitCategory>[
    all,
    BenefitCategory('mobility', '이동·교통'),
    BenefitCategory('care', '돌봄·활동지원'),
    BenefitCategory('health', '건강·재활'),
    BenefitCategory('culture', '문화·체육'),
    BenefitCategory('tax', '세금·요금'),
  ];
}

/// 복지혜택 한 건. `score`와 `reasons`는 서버의 `match_benefits()`가 계산한
/// **적합도**와 **매칭 근거 태그**다 — 앱에서 다시 계산하지 않는다.
class Benefit {
  const Benefit({
    required this.id,
    required this.cat,
    required this.catLabel,
    required this.title,
    required this.summary,
    required this.score,
    this.org,
    this.detailRows = const [],
    this.foot,
    this.dueDate,
    this.dueLabelOverride,
    this.reasons = const [],
    this.applied = false,
  });

  final String id;
  final String cat;
  final String catLabel;
  final String title;
  final String summary;

  /// 적합도 0–100
  final int score;

  final String? org;

  /// `[['지원 내용','취득세 전액 · 자동차세 감면'], …]`
  final List<List<String>> detailRows;

  final String? foot;
  final DateTime? dueDate;

  /// 날짜가 없는 상시 항목의 표기 (`상시 신청`)
  final String? dueLabelOverride;

  final List<String> reasons;
  final bool applied;

  /// `D-9 · 8/20 마감` 또는 `상시 신청`
  String get dueText =>
      dueLabelOverride ?? dueLabel(dueDate, fallback: '상시 신청');

  /// 마감 임박이면 카드에서 빨갛게 보인다
  bool get urgent => dueLabelOverride == null && isUrgentDue(dueDate);

  Benefit copyWith({bool? applied}) => Benefit(
        id: id,
        cat: cat,
        catLabel: catLabel,
        title: title,
        summary: summary,
        score: score,
        org: org,
        detailRows: detailRows,
        foot: foot,
        dueDate: dueDate,
        dueLabelOverride: dueLabelOverride,
        reasons: reasons,
        applied: applied ?? this.applied,
      );

  factory Benefit.fromMap(Map<String, dynamic> m) => Benefit(
        id: m['id'] as String,
        cat: m['cat'] as String,
        catLabel: m['cat_label'] as String,
        title: m['title'] as String,
        summary: m['summary'] as String,
        score: (m['score'] as num?)?.toInt() ?? 0,
        org: m['org'] as String?,
        detailRows: ((m['detail_rows'] as List?) ?? const [])
            .map((e) => (e as List).map((v) => v.toString()).toList())
            .toList(),
        foot: m['foot'] as String?,
        dueDate: DateTime.tryParse(m['due_date'] as String? ?? ''),
        dueLabelOverride: m['due_label'] as String?,
        reasons: ((m['reasons'] as List?) ?? const []).cast<String>(),
        applied: m['applied'] as bool? ?? false,
      );
}
