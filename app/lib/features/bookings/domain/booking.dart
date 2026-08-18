import '../../../core/util/format.dart';

enum BookingStatus {
  confirmed('confirmed', '확정'),
  waiting('waiting', '대기'),
  cancelled('cancelled', '취소');

  const BookingStatus(this.code, this.label);

  final String code;
  final String label;

  static BookingStatus fromCode(String? code) => values.firstWhere(
        (e) => e.code == code,
        orElse: () => BookingStatus.confirmed,
      );
}

/// 시설 예약 한 건.
class Booking {
  const Booking({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.slotAt,
    required this.status,
    this.programLabel,
    this.hasParkingHold = false,
    this.callTaxiRequested = false,
    this.parkingQueuePosition,
  });

  final String id;
  final String facilityId;
  final String facilityName;
  final DateTime slotAt;
  final BookingStatus status;

  /// `· 수영` 처럼 시설명 뒤에 붙는 프로그램 이름
  final String? programLabel;

  /// 목적지 주차면 1면을 확보했는지
  final bool hasParkingHold;

  final bool callTaxiRequested;

  /// 주차면을 못 잡았을 때의 대기 순번
  final int? parkingQueuePosition;

  /// `성남 반다비체육센터 · 수영`
  String get title =>
      programLabel == null ? facilityName : '$facilityName · $programLabel';

  /// `8월 12일 (수) 10:30`
  String get whenLabel => bookingWhen(slotAt);

  /// `주차면 1면 확보 · 도착 시 자동 인증`
  String get metaLabel {
    if (hasParkingHold) return '주차면 1면 확보 · 도착 시 자동 인증';
    final queue = parkingQueuePosition;
    final parking = queue == null ? '주차면 미확보' : '주차면 대기 $queue순위';
    return callTaxiRequested ? '$parking · 콜택시 배차 요청됨' : parking;
  }

  factory Booking.fromMap(Map<String, dynamic> m) => Booking(
        id: m['id'] as String,
        facilityId: m['facility_id'] as String,
        facilityName: m['facility_name'] as String? ?? '',
        slotAt: DateTime.parse(m['slot_at'] as String).toLocal(),
        status: BookingStatus.fromCode(m['status'] as String?),
        programLabel: m['program_label'] as String?,
        hasParkingHold: m['hold_id'] != null,
        callTaxiRequested: m['call_taxi'] as bool? ?? false,
        parkingQueuePosition: (m['parking_queue'] as num?)?.toInt(),
      );
}
