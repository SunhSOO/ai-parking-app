/// 부정주차 신고 사유 4종 — 프로토타입의 라디오 항목과 같다.
enum ReportReason {
  noPermit('no_permit', '표지 없이 주차'),
  permitNoRider('permit_no_rider', '표지는 있지만 본인 미탑승'),
  encroach('encroach', '주차면 침범·통로 방해'),
  abandoned('abandoned', '장기 방치 차량');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;

  static ReportReason fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => ReportReason.noPermit);
}

enum ReportStatus {
  received('received', '접수됨'),
  reviewing('reviewing', '확인 중'),
  confirmed('confirmed', '확인됨'),
  dismissed('dismissed', '해당 없음');

  const ReportStatus(this.code, this.label);

  final String code;
  final String label;

  static ReportStatus fromCode(String? code) => values
      .firstWhere((e) => e.code == code, orElse: () => ReportStatus.received);
}

class Report {
  const Report({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.receiptNo,
    this.photoPath,
    this.memo,
  });

  final String id;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? receiptNo;
  final String? photoPath;
  final String? memo;

  factory Report.fromMap(Map<String, dynamic> m) => Report(
        id: m['id'] as String,
        reason: ReportReason.fromCode(m['reason'] as String?),
        status: ReportStatus.fromCode(m['status'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        receiptNo: m['receipt_no'] as String?,
        photoPath: m['photo_path'] as String?,
        memo: m['memo'] as String?,
      );
}

/// 내가 받은 경고. 인증 없는 주차가 3회 누적되면 표지 점검 대상이 된다.
class Warning {
  const Warning({
    required this.id,
    required this.label,
    required this.occurredAt,
    this.spotName,
    this.detail,
  });

  final String id;
  final String label;
  final DateTime occurredAt;
  final String? spotName;
  final String? detail;

  factory Warning.fromMap(Map<String, dynamic> m) => Warning(
        id: m['id'] as String,
        label: m['label'] as String,
        occurredAt: DateTime.parse(m['occurred_at'] as String).toLocal(),
        spotName: m['spot_name'] as String?,
        detail: m['detail'] as String?,
      );
}
