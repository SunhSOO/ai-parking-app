import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/parking_spot.dart';

/// 네이버 지도 Client ID가 아직 없을 때 쓰는 **격자 지도 목업**.
///
/// 프로토타입의 지도 영역을 그대로 재현한다. 핀 위치는 하드코딩이 아니라
/// 실제 좌표를 영역에 투영해서 찍으므로, 실제 지도로 바꿔도 데이터는 그대로 쓴다.
class MockMapView extends StatelessWidget {
  const MockMapView({
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final bounds = _Bounds.of(spots, center);

        return ClipRRect(
          borderRadius: AppRadius.r26,
          child: Container(
            color: const Color(0xFFE4EAF2),
            child: Stack(
              children: [
                // 격자 + 도로
                Positioned.fill(child: CustomPaint(painter: _GridPainter())),

                // 주차면 핀
                for (final spot in spots)
                  Builder(builder: (context) {
                    final p = bounds.project(spot.lat, spot.lng, box);
                    return Positioned(
                      left: p.dx - 26,
                      top: p.dy - 14,
                      child: _Pin(
                        spot: spot,
                        selected: spot.id == selectedId,
                        onTap: () => onSelect?.call(spot.id),
                      ),
                    );
                  }),

                // 현재 위치
                Builder(builder: (context) {
                  final p = bounds.project(center.lat, center.lng, box);
                  return Positioned(
                    left: p.dx - 10,
                    top: p.dy - 10,
                    child: const _CurrentLocationDot(),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 좌표 범위를 화면 박스에 투영한다.
class _Bounds {
  const _Bounds(this.minLat, this.maxLat, this.minLng, this.maxLng);

  final double minLat, maxLat, minLng, maxLng;

  factory _Bounds.of(List<ParkingSpot> spots, ({double lat, double lng}) center) {
    final lats = [center.lat, ...spots.map((s) => s.lat)];
    final lngs = [center.lng, ...spots.map((s) => s.lng)];

    var minLat = lats.reduce((a, b) => a < b ? a : b);
    var maxLat = lats.reduce((a, b) => a > b ? a : b);
    var minLng = lngs.reduce((a, b) => a < b ? a : b);
    var maxLng = lngs.reduce((a, b) => a > b ? a : b);

    // 점이 하나뿐이거나 너무 몰려 있으면 최소 범위를 준다.
    const minSpan = 0.004;
    if (maxLat - minLat < minSpan) {
      final mid = (maxLat + minLat) / 2;
      minLat = mid - minSpan / 2;
      maxLat = mid + minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      final mid = (maxLng + minLng) / 2;
      minLng = mid - minSpan / 2;
      maxLng = mid + minSpan / 2;
    }
    return _Bounds(minLat, maxLat, minLng, maxLng);
  }

  Offset project(double lat, double lng, Size box) {
    const pad = 44.0;
    final w = (box.width - pad * 2).clamp(1.0, double.infinity);
    final h = (box.height - pad * 2).clamp(1.0, double.infinity);

    final x = pad + (lng - minLng) / (maxLng - minLng) * w;
    // 위도는 위로 갈수록 커지므로 y축을 뒤집는다.
    final y = pad + (maxLat - lat) / (maxLat - minLat) * h;
    return Offset(x, y);
  }
}

/// 격자 배경 + 흰 도로 두 줄.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.inkA(.05)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final road = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, size.height * .4, size.width, 18), road);
    canvas.drawRect(Rect.fromLTWH(size.width * .45, 0, 15, size.height), road);
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _Pin extends StatelessWidget {
  const _Pin({required this.spot, required this.selected, required this.onTap});

  final ParkingSpot spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch ((selected, spot.isFull)) {
      (true, _) => (AppColors.ink, Colors.white),
      (_, true) => (const Color(0xFFC9CEDA), const Color(0xFF6B7080)),
      _ => (Colors.white, AppColors.ink),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: '${spot.name} ${spot.leftLabel}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.pill,
              boxShadow: AppShadows.pin,
            ),
            child: Text(
              spot.leftLabel,
              style: appText(size: 12, weight: 900, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '현재 위치',
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.blue,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: AppColors.blueA(.25), spreadRadius: 6),
          ],
        ),
      ),
    );
  }
}
