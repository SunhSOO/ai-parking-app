import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../features/parking_map/domain/parking_spot.dart';
import 'notification_service.dart';

/// iOS가 한 앱에 허용하는 region monitoring 개수 상한.
/// 그래서 "가장 가까운 20개"만 등록하고 위치가 크게 바뀌면 다시 등록한다.
const maxGeofences = 20;

/// 지오펜스 진입/이탈 콜백.
///
/// **앱과 다른 isolate에서 실행된다.** 앱의 Riverpod 상태나 메모리에 접근할 수 없으므로
/// 필요한 것(Supabase, 알림)을 여기서 직접 초기화한다. 화면이 꺼져 있거나 앱이 완전히
/// 종료된 상태에서도 이 콜백은 호출된다 — 그게 "버튼 0개 인증"의 핵심이다.
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  final spot = params.geofences.firstOrNull;
  if (spot == null) return;

  await NotificationService.instance.ensureInitialized();

  if (!AppConfig.hasSupabase) {
    // 목업 모드에서는 서버가 없으므로 알림만 띄운다.
    // (개발 중 전체 플로우는 앱 안의 시뮬레이터 버튼으로 확인한다.)
    if (params.event == GeofenceEvent.enter) {
      await NotificationService.instance.showArrival('주차면');
    }
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  final client = Supabase.instance.client;

  // 로그인 세션이 없으면 인증을 시작할 수 없다.
  if (client.auth.currentSession == null) return;

  try {
    switch (params.event) {
      case GeofenceEvent.enter:
        final row = await client.rpc('start_certification', params: {
          'p_spot_id': spot.id,
          'p_method': 'auto_geofence',
        });
        final name = (row is Map ? row['spot_name'] as String? : null) ?? '주차면';
        await NotificationService.instance.showArrival(name);

      case GeofenceEvent.exit:
        final active = await client
            .from('certifications')
            .select('id')
            .eq('spot_id', spot.id)
            .isFilter('ended_at', null)
            .maybeSingle();
        if (active != null) {
          await client.rpc('end_certification',
              params: {'p_cert_id': active['id'] as String});
        }

      case GeofenceEvent.dwell:
        break;
    }
  } catch (e) {
    debugPrint('[geofence] 처리 실패: $e');
  }
}

/// 주차면을 OS 지오펜스로 등록/해제한다.
class GeofenceService {
  GeofenceService._();

  static final GeofenceService instance = GeofenceService._();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await NativeGeofenceManager.instance.initialize();
    _initialized = true;
  }

  /// 위치 권한을 단계적으로 올린다.
  ///
  /// `whileInUse`만으로도 앱이 떠 있을 때는 동작하지만, **화면을 끈 상태에서도**
  /// 인증이 되려면 `always`가 필요하다. 그래서 먼저 사용 중 권한을 받고 나서
  /// 왜 필요한지 설명한 뒤 항상 허용을 요청하는 2단계로 간다.
  Future<LocationPermission> requestLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermission.denied;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // whileInUse까지 받았으면 한 번 더 요청해 always로 올린다.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// 백그라운드에서도 인증이 되는지 — 홈 화면의 안내 문구를 결정한다.
  Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// 가까운 주차면들을 지오펜스로 등록한다. 이전 등록은 모두 지운다.
  Future<void> sync(List<ParkingSpot> spots) async {
    await ensureInitialized();
    await NativeGeofenceManager.instance.removeAllGeofences();

    for (final spot in spots.take(maxGeofences)) {
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: spot.id,
          location: Location(latitude: spot.lat, longitude: spot.lng),
          radiusMeters: spot.radiusM.toDouble(),
          triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
          iosSettings: const IosGeofenceSettings(initialTrigger: true),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {GeofenceEvent.enter},
            notificationResponsiveness: Duration(seconds: 30),
          ),
        ),
        geofenceCallback,
      );
    }

    debugPrint('[geofence] ${spots.take(maxGeofences).length}개 등록됨');
  }

  Future<void> clear() async {
    await ensureInitialized();
    await NativeGeofenceManager.instance.removeAllGeofences();
  }
}
