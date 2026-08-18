import 'package:ai_parking/core/util/format.dart';
import 'package:ai_parking/features/parking_map/domain/parking_spot.dart';
import 'package:ai_parking/services/foreground_geofence.dart';
import 'package:flutter_test/flutter_test.dart';

/// 진입 판정은 자동 인증의 방아쇠다. 여기가 틀리면 엉뚱한 자리에서 인증이 뜨거나
/// 제자리에 세워도 아무 일이 없다. 그래서 플러그인 없이 순수 계산으로 검증한다.
void main() {
  // 성남시청 주차장 B2 (반경 90m)
  const cityHall = ParkingSpot(
    id: 'p1',
    name: '성남시청 주차장 B2',
    lat: 37.4200,
    lng: 127.1265,
    total: 6,
    available: 3,
  );

  // 1.2km 떨어진 반다비체육센터
  const bandabi = ParkingSpot(
    id: 'p3',
    name: '반다비체육센터 지상',
    lat: 37.4128,
    lng: 127.1430,
    total: 6,
    available: 4,
  );

  group('거리 계산', () {
    test('같은 지점은 0m', () {
      expect(cityHall.distanceTo(37.4200, 127.1265), closeTo(0, 1));
    });

    test('위도 0.001도는 약 111m', () {
      expect(cityHall.distanceTo(37.4210, 127.1265), closeTo(111, 3));
    });

    test('두 주차면 사이는 약 1.6km', () {
      final d = cityHall.distanceTo(bandabi.lat, bandabi.lng);
      expect(d, greaterThan(1500));
      expect(d, lessThan(1800));
    });
  });

  group('반경 진입 판정', () {
    test('주차면 위에 서 있으면 진입', () {
      expect(cityHall.contains(37.4200, 127.1265), isTrue);
    });

    test('반경 90m 안쪽(약 55m)은 진입', () {
      expect(cityHall.contains(37.42050, 127.1265), isTrue);
    });

    test('반경 밖(약 220m)은 진입 아님', () {
      expect(cityHall.contains(37.4220, 127.1265), isFalse);
    });

    test('반경을 넓히면 같은 좌표가 진입이 된다', () {
      const wide = ParkingSpot(
        id: 'p1',
        name: '넓은 반경',
        lat: 37.4200,
        lng: 127.1265,
        total: 1,
        available: 1,
        radiusM: 300,
      );
      expect(wide.contains(37.4220, 127.1265), isTrue);
    });
  });

  group('이동 시간 안내', () {
    // 보행상 장애가 있는 사용자에게 1km 넘는 거리를 "도보"로 안내하면 안 된다.
    test('가까우면 도보', () {
      expect(travelLabel(180), '도보 3분');
      expect(travelLabel(620), '도보 10분');
    });

    test('800m를 넘으면 차량', () {
      expect(travelLabel(1200), '차량 4분');
      expect(travelLabel(2000), '차량 7분');
      expect(travelLabel(3100), '차량 11분');
    });

    test('경계값 800m는 아직 도보', () {
      expect(travelLabel(800), startsWith('도보'));
      expect(travelLabel(801), startsWith('차량'));
    });

    test('거리를 모르면 빈 문자열', () {
      expect(travelLabel(null), '');
    });
  });

  group('spotContaining', () {
    const spots = [cityHall, bandabi];

    test('반경 안의 주차면을 찾는다', () {
      expect(spotContaining(spots, 37.4200, 127.1265)?.id, 'p1');
      expect(spotContaining(spots, 37.4128, 127.1430)?.id, 'p3');
    });

    test('어디에도 안 들어가면 null', () {
      expect(spotContaining(spots, 37.5000, 127.0000), isNull);
    });

    test('겹치는 반경에서는 더 가까운 쪽을 고른다', () {
      const a = ParkingSpot(
        id: 'a',
        name: 'A',
        lat: 37.4200,
        lng: 127.1265,
        total: 1,
        available: 1,
        radiusM: 500,
      );
      const b = ParkingSpot(
        id: 'b',
        name: 'B',
        lat: 37.4205,
        lng: 127.1265,
        total: 1,
        available: 1,
        radiusM: 500,
      );
      // b 바로 위에 서 있다 — 둘 다 반경 안이지만 b가 가깝다.
      expect(spotContaining([a, b], 37.4205, 127.1265)?.id, 'b');
    });

    test('빈 목록은 null', () {
      expect(spotContaining(const [], 37.42, 127.12), isNull);
    });
  });
}
