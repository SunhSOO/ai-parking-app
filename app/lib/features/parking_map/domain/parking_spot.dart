import 'dart:math' as math;

import '../../../core/util/format.dart';

/// 두 좌표 사이의 거리(m). Haversine 공식.
///
/// 위치 플러그인의 `distanceBetween`을 쓰지 않는 이유: 이 계산은 자동 인증
/// 진입 판정의 핵심이라, 플러그인 없이 단위 테스트로 검증할 수 있어야 한다.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusM = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;

  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// 장애인주차면. 지도 화면과 지오펜스 등록이 같은 객체를 쓴다.
class ParkingSpot {
  const ParkingSpot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.total,
    required this.available,
    this.address,
    this.radiusM = 90,
    this.cameraZone = false,
    this.note,
    this.distanceM,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final int total;
  final int available;

  /// 자동 인증 지오펜스 반경 (기본 90m)
  final int radiusM;

  /// 카메라 단속 구역 여부
  final bool cameraZone;

  /// '예약 연동' 같은 부가 표시
  final String? note;

  /// 현재 위치로부터의 거리. 목록 정렬과 메타 문구에 쓴다.
  final double? distanceM;

  final DateTime? updatedAt;

  bool get isFull => available <= 0;

  /// 핀과 리스트 좌측 칩에 쓰는 `3면` / `만차`
  String get leftLabel => isFull ? '만차' : '$available면';

  /// `180m · 도보 3분 · 카메라 단속 구역`
  String get metaLine {
    final parts = <String>[
      if (distanceM != null) distanceLabel(distanceM),
      if (distanceM != null) travelLabel(distanceM),
      if (isFull) '만차' else if (cameraZone) '카메라 단속 구역',
      if (note != null && note!.isNotEmpty) note!,
    ];
    return parts.join(' · ');
  }

  /// 주어진 좌표까지의 거리(m).
  double distanceTo(double lat, double lng) =>
      distanceMeters(this.lat, this.lng, lat, lng);

  /// 자동 인증 반경 안에 들어와 있는지.
  bool contains(double lat, double lng) => distanceTo(lat, lng) <= radiusM;

  factory ParkingSpot.fromMap(Map<String, dynamic> m) => ParkingSpot(
        id: m['id'] as String,
        name: m['name'] as String,
        address: m['address'] as String?,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        total: (m['total'] as num).toInt(),
        available: (m['available'] as num).toInt(),
        radiusM: (m['radius_m'] as num?)?.toInt() ?? 90,
        cameraZone: m['camera_zone'] as bool? ?? false,
        note: m['note'] as String?,
        distanceM: (m['distance_m'] as num?)?.toDouble(),
        updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? ''),
      );

  ParkingSpot copyWith({int? available, double? distanceM}) => ParkingSpot(
        id: id,
        name: name,
        address: address,
        lat: lat,
        lng: lng,
        total: total,
        available: available ?? this.available,
        radiusM: radiusM,
        cameraZone: cameraZone,
        note: note,
        distanceM: distanceM ?? this.distanceM,
        updatedAt: updatedAt,
      );
}
