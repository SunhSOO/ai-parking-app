/// 자동 인증 세션의 단계.
///
/// 프로토타입의 타이밍(감지 1.1s → 대조 2.5s → 전달 3.9s)은 **연출 최소 지속시간**으로만
/// 쓰고, 실제 단계 전이는 서버가 결정한다.
enum CertStatus {
  detecting('detecting'),
  matching('matching'),
  sending('sending'),
  verified('verified'),
  failed('failed'),
  ended('ended');

  const CertStatus(this.code);

  final String code;

  static CertStatus fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => CertStatus.detecting);

  /// 시트 상단 킥커 — "주차면 감지" → "차량 대조 중" → …
  String get kicker => switch (this) {
        CertStatus.detecting => '주차면 감지',
        CertStatus.matching => '차량 대조 중',
        CertStatus.sending => '단속 시스템 전달 중',
        CertStatus.verified => '인증 완료',
        CertStatus.failed => '인증 실패',
        CertStatus.ended => '인증 종료',
      };

  /// 진행바 비율 — 프로토타입의 1.1 / 2.5 / 3.9초 구간과 같은 비율
  double get progress => switch (this) {
        CertStatus.detecting => 1.1 / 3.9,
        CertStatus.matching => 2.5 / 3.9,
        CertStatus.sending => 3.4 / 3.9,
        _ => 1.0,
      };

  bool get isRunning =>
      this == CertStatus.detecting ||
      this == CertStatus.matching ||
      this == CertStatus.sending;

  bool get isDone => this == CertStatus.verified || this == CertStatus.ended;
}

enum CertMethod {
  autoGeofence('auto_geofence', '자동 · GPS'),
  manual('manual', '수동 실행'),
  bookingLinked('booking_linked', '예약 연동 자동 인증');

  const CertMethod(this.code, this.label);

  final String code;
  final String label;

  static CertMethod fromCode(String? code) => values
      .firstWhere((e) => e.code == code, orElse: () => CertMethod.autoGeofence);
}

/// 인증 세션 하나. 진행 중인 것과 이력이 같은 타입이다.
class Certification {
  const Certification({
    required this.id,
    required this.status,
    required this.startedAt,
    this.spotId,
    this.spotName,
    this.plate,
    this.method = CertMethod.autoGeofence,
    this.radiusM = 90,
    this.feeNote,
    this.receiptNo,
    this.failReason,
    this.verifiedAt,
    this.endedAt,
    this.transmitted = false,
  });

  final String id;
  final CertStatus status;
  final DateTime startedAt;
  final String? spotId;
  final String? spotName;
  final String? plate;
  final CertMethod method;
  final int radiusM;
  final String? feeNote;
  final String? receiptNo;
  final String? failReason;
  final DateTime? verifiedAt;
  final DateTime? endedAt;

  /// 단속 시스템(G.Eye-Parking)에 **실제로** 전달했는지.
  ///
  /// 연동 전에는 항상 false다. 보내지 않고 보냈다고 표시하면 안 된다 —
  /// 사용자는 그 표시를 믿고 차를 두고 간다.
  final bool transmitted;

  bool get isRunning => status.isRunning && endedAt == null;
  bool get isVerified => status == CertStatus.verified;

  /// 이력 목록에서 인증에 성공한 건인지
  bool get ok => status == CertStatus.verified || status == CertStatus.ended;

  /// 확인증의 "인증 방식" 값 — `자동 · GPS 반경 90m`
  String get methodLabel => method == CertMethod.autoGeofence
      ? '${method.label} 반경 ${radiusM}m'
      : method.label;

  /// 자동 인증 시트의 3단계 상태
  bool get stepDetectDone => status != CertStatus.detecting;
  bool get stepMatchDone =>
      status == CertStatus.sending || status.isDone;

  /// 전달 단계는 **정말 보냈을 때만** 완료로 표시한다.
  bool get stepSendDone => status.isDone && transmitted;

  factory Certification.fromMap(Map<String, dynamic> m) => Certification(
        id: m['id'] as String,
        status: CertStatus.fromCode(m['status'] as String?),
        startedAt: DateTime.parse(m['started_at'] as String),
        spotId: m['spot_id'] as String?,
        spotName: m['spot_name'] as String?,
        plate: m['plate'] as String?,
        method: CertMethod.fromCode(m['method'] as String?),
        radiusM: (m['radius_m'] as num?)?.toInt() ?? 90,
        feeNote: m['fee_note'] as String?,
        receiptNo: m['receipt_no'] as String?,
        failReason: m['fail_reason'] as String?,
        verifiedAt: DateTime.tryParse(m['verified_at'] as String? ?? ''),
        endedAt: DateTime.tryParse(m['ended_at'] as String? ?? ''),
        transmitted: m['transmitted'] as bool? ?? false,
      );

  Certification copyWith({
    CertStatus? status,
    DateTime? verifiedAt,
    DateTime? endedAt,
    String? receiptNo,
    bool? transmitted,
  }) =>
      Certification(
        id: id,
        status: status ?? this.status,
        startedAt: startedAt,
        spotId: spotId,
        spotName: spotName,
        plate: plate,
        method: method,
        radiusM: radiusM,
        feeNote: feeNote,
        receiptNo: receiptNo ?? this.receiptNo,
        failReason: failReason,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        endedAt: endedAt ?? this.endedAt,
        transmitted: transmitted ?? this.transmitted,
      );
}
