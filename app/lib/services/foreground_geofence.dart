import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../features/parking_map/domain/parking_spot.dart';

/// 앱이 떠 있는 동안 위치를 직접 보고 주차면 진입/이탈을 판단한다.
///
/// OS 지오펜스([GeofenceService])와 **둘 다** 돌린다. 역할이 다르다:
/// - OS 지오펜스: 앱이 꺼져 있어도 발화. 대신 "항상 허용" 권한이 필요하다.
/// - 이 워처: 앱이 떠 있을 때만. 대신 "사용 중" 권한만으로 동작한다.
///
/// 두 경로가 같은 주차면에 대해 동시에 인증을 시작해도 안전하다 —
/// `start_certification`이 이미 진행 중인 세션을 그대로 돌려주기 때문이다.
class ForegroundGeofenceWatcher {
  ForegroundGeofenceWatcher({
    required this.onEnter,
    required this.onExit,
    this.onPosition,
  });

  /// 주차면 반경에 들어왔을 때
  final void Function(ParkingSpot spot) onEnter;

  /// 있던 주차면 반경을 벗어났을 때
  final void Function(ParkingSpot spot) onExit;

  /// 위치가 갱신될 때마다. 주차면 목록을 다시 받아올지 판단하는 데 쓴다.
  final void Function(double lat, double lng)? onPosition;

  StreamSubscription<Position>? _sub;
  List<ParkingSpot> _spots = const [];

  /// 마지막으로 받은 위치. 목록이 늦게 도착했을 때 다시 판정하는 데 쓴다.
  ({double lat, double lng})? _lastPosition;

  /// 지금 안에 들어와 있다고 판단한 주차면. 같은 자리에서 반복 발화하지 않게 한다.
  ParkingSpot? _inside;

  bool get isRunning => _sub != null;

  /// 주차면 목록이 갱신되면 **마지막 위치로 즉시 다시 판정한다.**
  ///
  /// 이게 없으면: 주차면에 도착해 차를 세운 뒤에야 목록이 도착한 경우, 이미
  /// 멈춰 있어 위치 이벤트가 더 오지 않으므로 진입이 영영 감지되지 않는다.
  void updateSpots(List<ParkingSpot> spots) {
    _spots = spots;

    final last = _lastPosition;
    if (last != null) _evaluate(last.lat, last.lng);
  }

  Future<void> start() async {
    if (_sub != null) return;

    try {
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // 10m마다 판단하면 90m 반경에는 충분하고 배터리도 아낄 수 있다.
          distanceFilter: 10,
        ),
      ).listen(
        _onPosition,
        onError: (Object e) => debugPrint('[foreground-geofence] 위치 스트림 오류: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[foreground-geofence] 시작 실패: $e');
    }
  }

  void _onPosition(Position position) {
    _lastPosition = (lat: position.latitude, lng: position.longitude);
    onPosition?.call(position.latitude, position.longitude);
    _evaluate(position.latitude, position.longitude);
  }

  void _evaluate(double lat, double lng) {
    final entered = spotContaining(_spots, lat, lng);
    final previous = _inside;

    if (entered != null && previous?.id != entered.id) {
      _inside = entered;
      debugPrint('[foreground-geofence] 진입: ${entered.name}');
      onEnter(entered);
      return;
    }

    if (entered == null && previous != null) {
      _inside = null;
      debugPrint('[foreground-geofence] 이탈: ${previous.name}');
      onExit(previous);
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _inside = null;
    _lastPosition = null;
  }
}

/// 좌표를 품고 있는 주차면 중 가장 가까운 것. 없으면 null.
///
/// 위치 플러그인에 의존하지 않는 순수 함수라 단위 테스트로 검증한다.
ParkingSpot? spotContaining(List<ParkingSpot> spots, double lat, double lng) {
  ParkingSpot? best;
  var bestDistance = double.infinity;

  for (final spot in spots) {
    final distance = spot.distanceTo(lat, lng);
    if (distance <= spot.radiusM && distance < bestDistance) {
      best = spot;
      bestDistance = distance;
    }
  }
  return best;
}
