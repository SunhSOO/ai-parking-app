import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/util/simple_notifier.dart';
import '../../../services/providers.dart';
import '../domain/parking_spot.dart';

/// 위치를 못 얻을 때 쓰는 기준점 — 성남시청.
/// 개발 중(에뮬레이터·권한 거부)에도 지도와 목록이 비지 않게 한다.
const fallbackLatLng = (lat: 37.4200, lng: 127.1265);

/// 위치 조회 전체에 거는 상한.
///
/// GPS가 늦거나(실내·터널) 플러그인이 응답하지 않아도 화면이 영원히 로딩 상태로
/// 남지 않게 한다. 넘기면 [fallbackLatLng]으로 주차면 목록을 먼저 보여 준다.
const _locationTimeout = Duration(seconds: 5);

/// 현재 위치. 권한이 없거나 느리거나 실패하면 [fallbackLatLng]으로 떨어진다.
final currentLocationProvider =
    FutureProvider<({double lat, double lng})>((ref) async {
  try {
    return await _resolveLocation().timeout(_locationTimeout);
  } catch (_) {
    return fallbackLatLng;
  }
});

Future<({double lat, double lng})> _resolveLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return fallbackLatLng;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return fallbackLatLng;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (_) {
    return fallbackLatLng;
  }
}

/// 주변 장애인주차면. 지도 목록과 지오펜스 등록이 같은 목록을 쓴다.
final nearbySpotsProvider = FutureProvider<List<ParkingSpot>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  return ref.watch(parkingRepositoryProvider).nearby(
        lat: location.lat,
        lng: location.lng,
      );
});

/// 지도에서 선택된 주차면 id. 선택하면 카드에 액션 버튼이 열린다.
final selectedSpotIdProvider =
    NotifierProvider<SimpleNotifier<String?>, String?>(
  () => SimpleNotifier(null),
);

/// 화면을 꺼 둔 상태에서도 인증이 되는지.
///
/// `always`가 아니면 지오펜스가 백그라운드에서 발화하지 않으므로, 홈에서
/// "앱을 열어 둔 동안만 인증됨"을 알리고 수동 실행을 주 경로로 안내해야 한다.
final backgroundPermissionProvider = FutureProvider<bool>((ref) async {
  try {
    return await Geolocator.checkPermission()
        .timeout(const Duration(seconds: 3)) ==
        LocationPermission.always;
  } catch (_) {
    return false;
  }
});

/// 가장 가까운 빈 자리 — 홈 통계의 "가까운 빈 자리"에 쓴다.
final nearestAvailableSpotProvider = Provider<ParkingSpot?>((ref) {
  final spots = ref.watch(nearbySpotsProvider).value ?? const [];
  for (final spot in spots) {
    if (!spot.isFull) return spot;
  }
  return null;
});
