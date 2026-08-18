import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/certification/domain/certification.dart';
import '../features/certification/presentation/certification_controller.dart';
import '../features/parking_map/domain/parking_spot.dart';
import '../features/parking_map/presentation/parking_controller.dart';
import 'foreground_geofence.dart';
import 'geofence_service.dart';
import 'notification_service.dart';

/// 화면에 아무것도 그리지 않고 백그라운드 동작만 붙잡아 두는 위젯.
///
/// 하는 일 세 가지:
/// 1. **OS 지오펜스 등록** — 앱이 꺼져 있어도 인증이 시작되게. 서버가 있어야 의미가
///    있으므로 Supabase가 설정됐을 때만 등록한다.
/// 2. **포그라운드 위치 워처** — 앱이 떠 있는 동안의 감지. "항상 허용"을 거부한
///    사용자와 개발/에뮬레이터 검증을 위한 경로다.
/// 3. **복귀 시 상태 동기화** — 백그라운드 isolate가 시작한 인증을 앱이 이어받는다.
class BackgroundServices extends ConsumerStatefulWidget {
  const BackgroundServices({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackgroundServices> createState() => _BackgroundServicesState();
}

class _BackgroundServicesState extends ConsumerState<BackgroundServices>
    with WidgetsBindingObserver {
  List<String>? _registeredIds;
  ForegroundGeofenceWatcher? _watcher;

  /// 지금 들고 있는 주차면 목록을 받아온 기준 좌표.
  double? _spotsLat;
  double? _spotsLng;

  /// 이 거리 이상 움직이면 주변 주차면을 다시 받아온다.
  ///
  /// 목록을 앱 시작 때 한 번만 받으면, 집에서 멀리 떨어진 시설로 이동했을 때
  /// 지오펜스가 옛 동네(또는 빈 목록)에 머물러 자동 인증이 아예 걸리지 않는다.
  static const _refetchDistanceM = 1000.0;

  /// 실기기(Android/iOS)에서만 위치·알림 플러그인을 건드린다.
  /// 위젯 테스트는 Windows 호스트에서 돌기 때문에 이 검사로 자연스럽게 빠진다.
  bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// OS 지오펜스는 백그라운드 isolate에서 서버를 호출하므로 서버가 있어야 한다.
  bool get _osGeofenceEnabled => _mobile && AppConfig.hasSupabase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_mobile) {
      NotificationService.instance.ensureInitialized();
      _startWatcher();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watcher?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 화면을 꺼 둔 사이 OS 지오펜스가 인증을 시작했을 수 있다.
      ref.read(certificationControllerProvider.notifier).refresh();
      if (_mobile) _startWatcher();
    } else if (state == AppLifecycleState.paused) {
      // 앱이 내려가면 위치 스트림을 놓는다. 그 뒤는 OS 지오펜스의 몫이다.
      _watcher?.stop();
    }
  }

  void _startWatcher() {
    final watcher = _watcher ??= ForegroundGeofenceWatcher(
      onEnter: (spot) {
        ref
            .read(certificationControllerProvider.notifier)
            .start(spot.id, method: CertMethod.autoGeofence);
        NotificationService.instance.showArrival(spot.name);
      },
      onExit: (_) => ref.read(certificationControllerProvider.notifier).end(),
      onPosition: _onPosition,
    );

    watcher.updateSpots(ref.read(nearbySpotsProvider).value ?? const []);
    if (!watcher.isRunning) watcher.start();
  }

  /// 기준 좌표에서 [_refetchDistanceM] 이상 벗어나면 주변 주차면을 다시 받는다.
  void _onPosition(double lat, double lng) {
    final baseLat = _spotsLat;
    final baseLng = _spotsLng;

    if (baseLat != null && baseLng != null) {
      if (distanceMeters(baseLat, baseLng, lat, lng) < _refetchDistanceM) return;
    }

    _spotsLat = lat;
    _spotsLng = lng;
    debugPrint('[geofence] 위치가 크게 바뀌어 주변 주차면을 다시 받습니다');
    ref.invalidate(currentLocationProvider);
  }

  Future<void> _syncOsGeofences(List<ParkingSpot> spots) async {
    final ids = spots.take(maxGeofences).map((s) => s.id).toList();
    if (listEquals(ids, _registeredIds)) return;
    _registeredIds = ids;

    try {
      await GeofenceService.instance.sync(spots);
    } catch (e) {
      debugPrint('[geofence] 등록 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mobile) {
      ref.listen(nearbySpotsProvider, (previous, next) {
        final spots = next.value;
        if (spots == null || spots.isEmpty) return;

        _watcher?.updateSpots(spots);
        if (_osGeofenceEnabled) _syncOsGeofences(spots);
      });
    }
    return widget.child;
  }
}
