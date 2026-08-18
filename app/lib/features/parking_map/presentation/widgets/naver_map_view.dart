import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/parking_spot.dart';

/// 실제 네이버 지도.
///
/// `NAVER_MAP_CLIENT_ID`가 주입돼 있을 때만 쓰인다 (없으면 [MockMapView]).
/// 주차면마다 마커를 찍고, 잔여 면수를 캡션으로 붙인다.
class NaverMapView extends StatefulWidget {
  const NaverMapView({
    super.key,
    required this.spots,
    required this.center,
    this.selectedId,
    this.onSelect,
  });

  final List<ParkingSpot> spots;
  final ({double lat, double lng}) center;
  final String? selectedId;
  final ValueChanged<String>? onSelect;

  @override
  State<NaverMapView> createState() => _NaverMapViewState();
}

class _NaverMapViewState extends State<NaverMapView> {
  NaverMapController? _controller;

  @override
  void didUpdateWidget(NaverMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spots != widget.spots ||
        oldWidget.selectedId != widget.selectedId) {
      _syncMarkers();
    }
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.clearOverlays(type: NOverlayType.marker);

    for (final spot in widget.spots) {
      final marker = NMarker(
        id: spot.id,
        position: NLatLng(spot.lat, spot.lng),
        caption: NOverlayCaption(
          text: '${spot.name} · ${spot.leftLabel}',
          textSize: 11,
        ),
        iconTintColor: switch ((spot.id == widget.selectedId, spot.isFull)) {
          (true, _) => AppColors.ink,
          (_, true) => const Color(0xFFC9CEDA),
          _ => AppColors.purple,
        },
      );
      marker.setOnTapListener((_) => widget.onSelect?.call(spot.id));
      await controller.addOverlay(marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.r26,
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(widget.center.lat, widget.center.lng),
            zoom: 14.5,
          ),
          locationButtonEnable: true,
          indoorEnable: false,
          scaleBarEnable: false,
          logoAlign: NLogoAlign.leftBottom,
        ),
        onMapReady: (controller) {
          _controller = controller;
          _syncMarkers();
        },
      ),
    );
  }
}
