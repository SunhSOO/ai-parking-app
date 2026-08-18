import '../../../core/util/format.dart';

/// 시설 검색의 카테고리 칩.
class FacilityCategory {
  const FacilityCategory(this.id, this.label);

  final String id;
  final String label;

  static const all = FacilityCategory('all', '전체');

  static const values = <FacilityCategory>[
    all,
    FacilityCategory('sports', '체육'),
    FacilityCategory('rehab', '재활·치료'),
    FacilityCategory('culture', '문화·학습'),
    FacilityCategory('life', '생활지원'),
    FacilityCategory('move', '이동지원'),
  ];
}

/// 체육·생활시설. 예약하면 [parkingSpotId]의 주차면 1면을 함께 확보한다.
class Facility {
  const Facility({
    required this.id,
    required this.cat,
    required this.name,
    required this.description,
    this.tag,
    this.icon = '🏛️',
    this.lat,
    this.lng,
    this.distanceM,
    this.parkingSpotId,
    this.parkingAvailable,
    this.parkingTotal,
  });

  final String id;
  final String cat;
  final String name;
  final String description;
  final String? tag;
  final String icon;
  final double? lat;
  final double? lng;
  final double? distanceM;
  final String? parkingSpotId;
  final int? parkingAvailable;
  final int? parkingTotal;

  /// 시설 카드의 `주차 4/6` — 연결된 주차면이 없으면 `—`
  String get parkingLabel => (parkingAvailable == null || parkingTotal == null)
      ? '—'
      : '$parkingAvailable/$parkingTotal';

  /// 예약 화면의 "🅿️ 목적지 주차면" 값 — `4면 여유` / `픽업 지점 지정`
  String get parkingLine => parkingAvailable == null
      ? '픽업 지점 지정'
      : (parkingAvailable! > 0 ? '$parkingAvailable면 여유' : '만차 · 대기 등록');

  /// `1.2km` — 거리를 모르면 빈 문자열
  String get distanceLabelText => distanceLabel(distanceM);

  /// 검색 부분 일치 대상 — 이름 · 설명 · 태그
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return '$name$description${tag ?? ''}'.toLowerCase().contains(q);
  }

  factory Facility.fromMap(Map<String, dynamic> m) => Facility(
        id: m['id'] as String,
        cat: m['cat'] as String,
        name: m['name'] as String,
        description: m['description'] as String? ?? '',
        tag: m['tag'] as String?,
        icon: m['icon'] as String? ?? '🏛️',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        distanceM: (m['distance_m'] as num?)?.toDouble(),
        parkingSpotId: m['parking_spot_id'] as String?,
        parkingAvailable: (m['parking_available'] as num?)?.toInt(),
        parkingTotal: (m['parking_total'] as num?)?.toInt(),
      );
}

/// 예약 가능한 시간 슬롯.
class FacilitySlot {
  const FacilitySlot({
    required this.id,
    required this.facilityId,
    required this.slotAt,
    required this.capacity,
    required this.remaining,
  });

  final String id;
  final String facilityId;
  final DateTime slotAt;
  final int capacity;
  final int remaining;

  bool get isFull => remaining <= 0;

  /// 시간 칩의 아래 줄 — `잔여 4` / `마감`
  String get note => isFull ? '마감' : '잔여 $remaining';

  /// `13:00`
  String get timeLabel => hhmm(slotAt);

  factory FacilitySlot.fromMap(Map<String, dynamic> m) => FacilitySlot(
        id: m['id'] as String,
        facilityId: m['facility_id'] as String,
        slotAt: DateTime.parse(m['slot_at'] as String).toLocal(),
        capacity: (m['capacity'] as num).toInt(),
        remaining: (m['remaining'] as num).toInt(),
      );
}
