import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../../features/benefits/data/benefit_repository.dart';
import '../../features/benefits/domain/benefit.dart';
import '../../features/bookings/data/booking_repository.dart';
import '../../features/bookings/domain/booking.dart';
import '../../features/certification/data/certification_repository.dart';
import '../../features/certification/domain/certification.dart';
import '../../features/facilities/data/facility_repository.dart';
import '../../features/facilities/domain/facility.dart';
import '../../features/parking_map/data/parking_repository.dart';
import '../../features/parking_map/domain/parking_spot.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/report/data/report_repository.dart';
import '../../features/report/domain/report.dart';
import 'mock_data.dart';

/// 목업 리포지토리 모음.
///
/// Supabase 키가 없을 때 쓰인다. 상태는 메모리에만 있고 앱을 다시 켜면 초기화된다.
/// 네트워크 지연을 흉내 내 로딩 상태가 화면에서 실제로 보이게 한다.
Future<void> _latency([int ms = 220]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

class MockProfileRepository implements ProfileRepository {
  Profile _profile = MockData.profile();
  Vehicle _vehicle = MockData.vehicle;

  @override
  Future<Profile?> fetchProfile() async {
    await _latency();
    return _profile;
  }

  @override
  Future<Profile> saveProfile(Profile profile) async {
    await _latency();
    return _profile = profile;
  }

  @override
  Future<List<Vehicle>> fetchVehicles() async {
    await _latency();
    return [_vehicle];
  }

  @override
  Future<Vehicle> savePrimaryVehicle(String plate) async {
    await _latency();
    return _vehicle = Vehicle(id: _vehicle.id, plate: plate);
  }

  @override
  Future<Profile> setNotif(String key, bool value) async {
    final notif = Map<String, bool>.from(_profile.notif)..[key] = value;
    return _profile = _profile.copyWith(notif: notif);
  }
}

class MockParkingRepository implements ParkingRepository {
  final List<ParkingSpot> _spots = MockData.spots();

  @override
  Future<List<ParkingSpot>> nearby({
    required double lat,
    required double lng,
    int radiusM = 3000,
    int limit = 20,
  }) async {
    await _latency();
    final sorted = [..._spots]
      ..sort((a, b) => (a.distanceM ?? 0).compareTo(b.distanceM ?? 0));
    return sorted
        .where((s) => (s.distanceM ?? 0) <= radiusM)
        .take(limit)
        .toList();
  }

  @override
  Future<ParkingSpot?> byId(String id) async {
    await _latency(60);
    for (final s in _spots) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// 프로토타입과 같은 타이밍(감지 1.1s → 대조 2.5s → 전달 3.9s)으로 단계를 진행시킨다.
/// 실제 앱에서는 서버가 이 전이를 하고 앱은 Realtime으로 받기만 한다.
class MockCertificationRepository implements CertificationRepository {
  MockCertificationRepository({this.spotName = '성남시청 주차장 B2 · 3면'});

  final String spotName;

  final List<Certification> _history = MockData.history();
  Certification? _active;
  StreamController<Certification>? _controller;
  Timer? _timer;

  static const _detect = Duration(milliseconds: 1100);
  static const _match = Duration(milliseconds: 2500);
  static const _done = Duration(milliseconds: 3900);

  @override
  Future<Certification?> active() async => _active;

  @override
  Future<Certification> start(
    String spotId, {
    CertMethod method = CertMethod.autoGeofence,
  }) async {
    // 이미 진행 중이면 그대로 돌려준다 (지오펜스 중복 발화 대응과 동일한 규칙).
    final running = _active;
    if (running != null && running.endedAt == null) return running;

    final cert = Certification(
      id: 'c${DateTime.now().millisecondsSinceEpoch}',
      status: CertStatus.detecting,
      startedAt: DateTime.now(),
      spotId: spotId,
      spotName: spotName,
      plate: MockData.vehicle.plate,
      method: method,
      feeNote: '무료 · 장애인 감면 적용',
    );
    _active = cert;
    _schedule(cert);
    return cert;
  }

  /// 단계 전이를 **타이머로** 예약한다.
  ///
  /// 벽시계(DateTime.now)를 기준으로 계산하지 않는 이유: 위젯 테스트에서
  /// `pump(Duration)`으로 시간을 앞당겨도 벽시계는 그대로라 단계가 진행되지 않는다.
  void _schedule(Certification cert) {
    _timer?.cancel();
    _emitAt(_detect, CertStatus.matching);
    _emitAt(_match, CertStatus.sending);
    _emitAt(_done, CertStatus.verified);
  }

  void _emitAt(Duration delay, CertStatus status) {
    _timer = Timer(delay, () {
      final current = _active;
      if (current == null || current.endedAt != null) return;

      final now = DateTime.now();
      final verified = status == CertStatus.verified;
      final next = current.copyWith(
        status: status,
        verifiedAt: verified ? now : null,
        receiptNo: verified
            ? 'C-${now.year}-'
                '${now.month.toString().padLeft(2, '0')}'
                '${now.day.toString().padLeft(2, '0')}-'
                '${(_history.length + 1).toString().padLeft(3, '0')}'
            : null,
      );
      _active = next;
      _controller?.add(next);
      if (verified) _history.insert(0, next);
    });
  }

  @override
  Stream<Certification> watch(String certificationId) {
    _controller?.close();
    final controller = StreamController<Certification>.broadcast();
    _controller = controller;

    final current = _active;
    if (current != null) {
      scheduleMicrotask(() => controller.add(current));
    }
    return controller.stream;
  }

  @override
  Future<List<Certification>> history({int limit = 20}) async {
    await _latency();
    return _history.take(limit).toList();
  }

  @override
  Future<void> end(String certificationId) async {
    final current = _active;
    if (current == null) return;
    _timer?.cancel();
    _active = current.copyWith(status: CertStatus.ended, endedAt: DateTime.now());
    _controller?.add(_active!);
    _active = null;
  }
}

class MockBenefitRepository implements BenefitRepository {
  final List<Benefit> _benefits = MockData.benefits();
  final Set<String> _applied = {};

  @override
  Future<List<Benefit>> feed({String? categoryId}) async {
    await _latency();
    return _benefits
        .where((b) =>
            categoryId == null || categoryId == 'all' || b.cat == categoryId)
        .map((b) => b.copyWith(applied: _applied.contains(b.id)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  @override
  Future<Benefit?> byId(String id) async {
    await _latency(60);
    for (final b in _benefits) {
      if (b.id == id) return b.copyWith(applied: _applied.contains(b.id));
    }
    return null;
  }

  @override
  Future<void> apply(String benefitId) async {
    await _latency(400);
    _applied.add(benefitId);
  }
}

class MockFacilityRepository implements FacilityRepository {
  final List<Facility> _facilities = MockData.facilities();
  final Map<String, List<FacilitySlot>> _slots = {};

  @override
  Future<List<Facility>> list({String? categoryId, String query = ''}) async {
    await _latency();
    return _facilities
        .where((f) =>
            categoryId == null || categoryId == 'all' || f.cat == categoryId)
        .where((f) => f.matches(query.trim()))
        .toList();
  }

  @override
  Future<Facility?> byId(String id) async {
    await _latency(60);
    for (final f in _facilities) {
      if (f.id == id) return f;
    }
    return null;
  }

  @override
  Future<List<FacilitySlot>> slots(String facilityId, {int days = 7}) async {
    await _latency();
    return _slots[facilityId] ??= MockData.slotsFor(facilityId, days: days);
  }

  /// 예약이 잡히면 잔여를 줄인다 (목업 예약 리포지토리가 호출한다).
  FacilitySlot? consume(String slotId, {int delta = -1}) {
    for (final entry in _slots.entries) {
      final index = entry.value.indexWhere((s) => s.id == slotId);
      if (index < 0) continue;
      final slot = entry.value[index];
      final next = FacilitySlot(
        id: slot.id,
        facilityId: slot.facilityId,
        slotAt: slot.slotAt,
        capacity: slot.capacity,
        remaining: math.max(0, math.min(slot.capacity, slot.remaining + delta)),
      );
      entry.value[index] = next;
      return next;
    }
    return null;
  }
}

class MockBookingRepository implements BookingRepository {
  MockBookingRepository(this._facilities);

  final MockFacilityRepository _facilities;
  final List<Booking> _bookings = MockData.bookings();

  @override
  Future<List<Booking>> list() async {
    await _latency();
    return [..._bookings]..sort((a, b) => a.slotAt.compareTo(b.slotAt));
  }

  @override
  Future<Booking> book(String slotId) async {
    await _latency(400);

    final slot = _facilities.consume(slotId);
    if (slot == null) throw StateError('슬롯을 찾을 수 없습니다');

    final facility = await _facilities.byId(slot.facilityId);
    final hasParking = (facility?.parkingAvailable ?? 0) > 0;

    final booking = Booking(
      id: 'k${DateTime.now().millisecondsSinceEpoch}',
      facilityId: slot.facilityId,
      facilityName: facility?.name ?? '',
      slotAt: slot.slotAt,
      status: hasParking ? BookingStatus.confirmed : BookingStatus.waiting,
      hasParkingHold: hasParking,
      parkingQueuePosition: hasParking ? null : 1,
    );
    _bookings.insert(0, booking);
    return booking;
  }

  @override
  Future<void> cancel(String bookingId) async {
    await _latency(250);
    _bookings.removeWhere((b) => b.id == bookingId);
  }
}

class MockReportRepository implements ReportRepository {
  final List<Warning> _warnings = MockData.warnings();
  int _sequence = 41;

  @override
  Future<Report> submit({
    required ReportReason reason,
    File? photo,
    String? spotId,
    String? memo,
  }) async {
    await _latency(600);
    final now = DateTime.now();
    _sequence++;
    return Report(
      id: 'r${now.millisecondsSinceEpoch}',
      reason: reason,
      status: ReportStatus.received,
      createdAt: now,
      memo: memo,
      receiptNo: 'R-${now.year}-'
          '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
          '${_sequence.toString().padLeft(3, '0')}',
    );
  }

  @override
  Future<List<Warning>> warnings() async {
    await _latency();
    return _warnings;
  }
}
