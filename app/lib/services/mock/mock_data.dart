import '../../features/benefits/domain/benefit.dart';
import '../../features/bookings/domain/booking.dart';
import '../../features/certification/domain/certification.dart';
import '../../features/facilities/domain/facility.dart';
import '../../features/parking_map/domain/parking_spot.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/report/domain/report.dart';

/// 목업 모드에서 쓰는 데이터. `supabase/seed.sql`과 같은 내용이다.
///
/// Supabase 키가 없어도 12개 화면이 전부 돌아가게 하는 것이 목적이다.
/// 시드를 고칠 일이 생기면 **양쪽을 같이** 고친다.
class MockData {
  const MockData._();

  static final DateTime _now = DateTime.now();

  // ---------------------------------------------------------------- 프로필
  static Profile profile() => Profile(
        id: 'mock-user',
        name: '선형수',
        disabilityType: '지체장애',
        disabilityGrade: '2급',
        walkingImpaired: true,
        sido: '경기도',
        sigungu: '성남시 중원구',
        birthYear: _now.year - 41,
        householdSize: 2,
        incomeBracket: '차상위계층',
        permitType: PermitType.self,
        interests: const ['culture', 'sports'],
        notif: const {
          'mobility': true,
          'care': true,
          'health': false,
          'culture': true,
          'tax': true,
        },
        cardVerifiedAt: _now.subtract(const Duration(days: 30)),
        onboardedAt: _now.subtract(const Duration(days: 30)),
      );

  static const vehicle = Vehicle(id: 'mock-vehicle', plate: '12가 3456');

  // ---------------------------------------------------------------- 주차면
  /// 프로토타입의 4개 + 시설에 연결된 4개.
  /// 거리는 성남시청(37.4200, 127.1265) 기준 근사값을 미리 넣어 뒀다.
  static List<ParkingSpot> spots() => [
        ParkingSpot(
          id: 'p1',
          name: '성남시청 주차장 B2',
          address: '경기도 성남시 중원구 성남대로 997',
          lat: 37.4200,
          lng: 127.1265,
          total: 6,
          available: 3,
          cameraZone: true,
          distanceM: 180,
          updatedAt: _now.subtract(const Duration(minutes: 3)),
        ),
        ParkingSpot(
          id: 'p2',
          name: '중원구청 앞 노상',
          address: '경기도 성남시 중원구 광명로 265',
          lat: 37.4306,
          lng: 127.1373,
          total: 3,
          available: 1,
          cameraZone: true,
          distanceM: 340,
          updatedAt: _now.subtract(const Duration(minutes: 3)),
        ),
        ParkingSpot(
          id: 'p3',
          name: '반다비체육센터 지상',
          address: '경기도 성남시 중원구 산성대로 476',
          lat: 37.4128,
          lng: 127.1430,
          total: 6,
          available: 4,
          note: '예약 연동',
          distanceM: 1200,
          updatedAt: _now.subtract(const Duration(minutes: 3)),
        ),
        ParkingSpot(
          id: 'p4',
          name: '중앙시장 공영주차장',
          address: '경기도 성남시 중원구 산성대로 371',
          lat: 37.4396,
          lng: 127.1372,
          total: 4,
          available: 0,
          distanceM: 620,
          updatedAt: _now.subtract(const Duration(minutes: 3)),
        ),
        ParkingSpot(
          id: 'p5',
          name: '중원공공수영장 주차장',
          lat: 37.4351,
          lng: 127.1461,
          total: 4,
          available: 2,
          distanceM: 2400,
        ),
        ParkingSpot(
          id: 'p6',
          name: '성남재활의학과 주차장',
          lat: 37.4419,
          lng: 127.1298,
          total: 3,
          available: 1,
          distanceM: 3100,
        ),
        ParkingSpot(
          id: 'p7',
          name: '중원평생학습관 주차장',
          lat: 37.4262,
          lng: 127.1402,
          total: 5,
          available: 3,
          distanceM: 1800,
        ),
        ParkingSpot(
          id: 'p8',
          name: '성남시장애인복지관 주차장',
          lat: 37.4290,
          lng: 127.1355,
          total: 8,
          available: 5,
          distanceM: 2000,
        ),
      ];

  // ---------------------------------------------------------------- 혜택
  /// 적합도와 근거 태그는 서버의 `match_benefits()`가 데모 프로필로 계산했을 때와
  /// 같은 값을 미리 넣어 둔 것이다.
  static List<Benefit> benefits() => [
        Benefit(
          id: 'b1',
          cat: 'tax',
          catLabel: '세금·요금',
          title: '장애인 자동차 취득세·자동차세 감면',
          summary: '본인 명의 차량 1대의 취득세 전액과 자동차세를 감면받을 수 있어요.',
          score: 98,
          org: '성남시 세무과',
          dueLabelOverride: '상시 신청',
          reasons: const ['지체장애 2급', '본인 명의 차량', '성남시 거주'],
          detailRows: const [
            ['지원 내용', '취득세 전액 · 자동차세 감면'],
            ['대상', '장애 정도가 심한 장애인 본인 명의 차량'],
            ['필요 서류', '복지카드, 자동차등록증'],
            ['처리 기간', '약 3일'],
          ],
          foot: '앱에 등록된 차량 정보와 복지카드 인증을 그대로 보내므로 서류를 다시 찍지 않아도 돼요.',
        ),
        Benefit(
          id: 'b2',
          cat: 'mobility',
          catLabel: '이동·교통',
          title: '장애인 콜택시 이용권 월 20회',
          summary: '휠체어 탑재 차량과 임차 택시를 월 20회까지 할인 요금으로 이용할 수 있어요.',
          score: 95,
          org: '경기도교통약자이동지원센터',
          dueDate: _now.add(const Duration(days: 9)),
          reasons: const ['보행상 장애', '성남시 거주', '지체장애 2급'],
          detailRows: const [
            ['지원 내용', '월 20회 · 시내 3,000원 정액'],
            ['대상', '보행상 장애가 있는 등록장애인'],
            ['필요 서류', '복지카드'],
            ['처리 기간', '약 5일'],
          ],
          foot: '이용권을 받으면 시설 예약 화면에서 콜택시 배차를 함께 예약할 수 있어요.',
        ),
        Benefit(
          id: 'b3',
          cat: 'culture',
          catLabel: '문화·체육',
          title: '반다비체육센터 이용료 70% 감면',
          summary: '장애인 전용 체육시설 수영·운동 프로그램 이용료를 감면해 줍니다.',
          score: 92,
          org: '성남시 체육진흥과',
          dueDate: _now.add(const Duration(days: 25)),
          reasons: const ['중위소득 100% 이하', '관심: 체육·재활', '성남시 거주'],
          detailRows: const [
            ['지원 내용', '월 이용료 70% 감면'],
            ['대상', '등록장애인 및 동반 보호자 1인'],
            ['필요 서류', '복지카드, 소득 확인 동의'],
            ['처리 기간', '약 7일'],
          ],
          foot: '앱 이용 패턴(체육시설 검색·예약)을 근거로 우선순위를 올려 추천한 항목이에요.',
        ),
        Benefit(
          id: 'b4',
          cat: 'care',
          catLabel: '돌봄·활동지원',
          title: '활동지원 급여 추가 지원',
          summary: '국가 활동지원 급여에 더해 성남시가 월 최대 40시간을 추가로 지원해요.',
          score: 88,
          org: '중원구 주민센터',
          dueDate: _now.add(const Duration(days: 20)),
          reasons: const ['2인 가구', '활동지원 수급 중', '성남시 거주'],
          detailRows: const [
            ['지원 내용', '월 최대 40시간 추가'],
            ['대상', '활동지원 수급자 중 시 거주자'],
            ['필요 서류', '수급 확인서, 가구 구성 확인'],
            ['처리 기간', '약 14일'],
          ],
          foot: '가구 구성·수급 자격은 마이페이지에 저장된 정보로 자동 대조됩니다.',
        ),
        Benefit(
          id: 'b5',
          cat: 'health',
          catLabel: '건강·재활',
          title: '보조기기 교부 — 전동 보조장치',
          summary: '이동 보조기기와 부속 장치를 신청 순서에 따라 교부합니다.',
          score: 84,
          org: '한국장애인개발원',
          dueDate: _now.add(const Duration(days: 55)),
          reasons: const ['지체장애 2급', '3년간 교부 이력 없음'],
          detailRows: const [
            ['지원 내용', '기기별 최대 100% 지원'],
            ['대상', '등록장애인'],
            ['필요 서류', '진단서, 복지카드'],
            ['처리 기간', '약 30일'],
          ],
          foot: '교부 대기 순번이 바뀌면 알림으로 알려 드려요.',
        ),
        Benefit(
          id: 'b6',
          cat: 'culture',
          catLabel: '문화·체육',
          title: '문화누리카드 연간 13만원',
          summary: '공연·전시·여행·체육 이용에 쓸 수 있는 연간 지원금이에요.',
          score: 79,
          org: '한국문화예술위원회',
          dueDate: _now.add(const Duration(days: 104)),
          reasons: const ['차상위계층', '관심: 문화·평생학습'],
          detailRows: const [
            ['지원 내용', '연 13만원 충전'],
            ['대상', '수급자 및 차상위계층'],
            ['필요 서류', '자격 확인 동의'],
            ['처리 기간', '즉시'],
          ],
          foot: '카드 잔액은 시설 예약 화면에서 결제 수단으로 바로 쓸 수 있어요.',
        ),
      ];

  // ---------------------------------------------------------------- 시설
  static List<Facility> facilities() => const [
        Facility(
          id: 'f1',
          cat: 'sports',
          name: '성남 반다비체육센터',
          tag: '장애인 전용',
          description: '장애인 전용 수영장·체력단련실. 전담 생활체육지도사 상주.',
          icon: '🏊',
          lat: 37.4128,
          lng: 127.1430,
          distanceM: 1200,
          parkingSpotId: 'p3',
          parkingAvailable: 4,
          parkingTotal: 6,
        ),
        Facility(
          id: 'f2',
          cat: 'sports',
          name: '중원공공수영장 장애인 시간대',
          tag: '전용 시간대',
          description: '매일 14–16시 장애인 우선 레인 2개 운영.',
          icon: '🏊',
          lat: 37.4351,
          lng: 127.1461,
          distanceM: 2400,
          parkingSpotId: 'p5',
          parkingAvailable: 2,
          parkingTotal: 4,
        ),
        Facility(
          id: 'f3',
          cat: 'rehab',
          name: '성남재활의학과 물리치료',
          tag: '재활·치료',
          description: '도수치료·보행 재훈련 8주 과정. 건강보험 적용.',
          icon: '💪',
          lat: 37.4419,
          lng: 127.1298,
          distanceM: 3100,
          parkingSpotId: 'p6',
          parkingAvailable: 1,
          parkingTotal: 3,
        ),
        Facility(
          id: 'f4',
          cat: 'culture',
          name: '중원평생학습관 문화강좌',
          tag: '문화·학습',
          description: '수어 서예, 사진, 디지털 기초 등 배리어프리 강좌 12개.',
          icon: '🎨',
          lat: 37.4262,
          lng: 127.1402,
          distanceM: 1800,
          parkingSpotId: 'p7',
          parkingAvailable: 3,
          parkingTotal: 5,
        ),
        Facility(
          id: 'f5',
          cat: 'life',
          name: '성남시장애인복지관 생활지원',
          tag: '생활지원',
          description: '가사·목욕 지원, 동행 지원 신청 창구.',
          icon: '🏠',
          lat: 37.4290,
          lng: 127.1355,
          distanceM: 2000,
          parkingSpotId: 'p8',
          parkingAvailable: 5,
          parkingTotal: 8,
        ),
        Facility(
          id: 'f6',
          cat: 'move',
          name: '장애인 콜택시 사전 배차',
          tag: '이동지원',
          description: '시설 예약 시간에 맞춰 왕복 배차를 미리 잡아 둘 수 있어요.',
          icon: '🚕',
          lat: 37.4200,
          lng: 127.1265,
        ),
      ];

  /// 프로토타입의 6개 시간대 × 7일.
  static List<FacilitySlot> slotsFor(String facilityId, {int days = 7}) {
    const times = [
      (hour: 9, minute: 0, capacity: 4, remaining: 2),
      (hour: 10, minute: 30, capacity: 4, remaining: 0),
      (hour: 13, minute: 0, capacity: 6, remaining: 4),
      (hour: 14, minute: 30, capacity: 4, remaining: 1),
      (hour: 16, minute: 0, capacity: 6, remaining: 3),
      (hour: 18, minute: 30, capacity: 4, remaining: 0),
    ];

    final today = DateTime(_now.year, _now.month, _now.day);
    return [
      for (var d = 0; d < days; d++)
        for (final t in times)
          FacilitySlot(
            id: '$facilityId-$d-${t.hour}${t.minute}',
            facilityId: facilityId,
            slotAt: today.add(Duration(days: d, hours: t.hour, minutes: t.minute)),
            capacity: t.capacity,
            remaining: t.remaining,
          ),
    ];
  }

  // ---------------------------------------------------------------- 예약
  static List<Booking> bookings() {
    final today = DateTime(_now.year, _now.month, _now.day);
    return [
      Booking(
        id: 'k1',
        facilityId: 'f1',
        facilityName: '성남 반다비체육센터',
        programLabel: '수영',
        slotAt: today.add(const Duration(days: 1, hours: 10, minutes: 30)),
        status: BookingStatus.confirmed,
        hasParkingHold: true,
      ),
      Booking(
        id: 'k2',
        facilityId: 'f3',
        facilityName: '성남재활의학과 물리치료',
        slotAt: today.add(const Duration(days: 3, hours: 15)),
        status: BookingStatus.waiting,
        hasParkingHold: false,
        parkingQueuePosition: 2,
        callTaxiRequested: true,
      ),
    ];
  }

  // ---------------------------------------------------------------- 인증 이력
  static List<Certification> history() => [
        Certification(
          id: 'h1',
          status: CertStatus.ended,
          spotName: '성남시청 주차장 B2 · 3면',
          plate: vehicle.plate,
          startedAt: _now.subtract(const Duration(days: 2, hours: 5)),
          verifiedAt: _now.subtract(const Duration(days: 2, hours: 5)),
          endedAt: _now.subtract(const Duration(days: 2, hours: 3)),
          receiptNo: 'C-2026-0809-011',
        ),
        Certification(
          id: 'h2',
          status: CertStatus.ended,
          spotName: '반다비체육센터 지상 · 1면',
          plate: vehicle.plate,
          method: CertMethod.bookingLinked,
          startedAt: _now.subtract(const Duration(days: 5, hours: 9)),
          endedAt: _now.subtract(const Duration(days: 5, hours: 7)),
        ),
        Certification(
          id: 'h3',
          status: CertStatus.failed,
          spotName: '판교역 공영주차장 · 2면',
          plate: vehicle.plate,
          startedAt: _now.subtract(const Duration(days: 18)),
          endedAt: _now.subtract(const Duration(days: 18)),
          failReason: '인증 없음',
        ),
        Certification(
          id: 'h4',
          status: CertStatus.ended,
          spotName: '중원구청 앞 노상 · 1면',
          plate: vehicle.plate,
          startedAt: _now.subtract(const Duration(days: 24)),
          endedAt: _now.subtract(const Duration(days: 24)),
        ),
      ];

  // ---------------------------------------------------------------- 경고
  static List<Warning> warnings() => [
        Warning(
          id: 'w1',
          label: '인증 없이 주차 1회',
          occurredAt: _now.subtract(const Duration(days: 18)),
          spotName: '판교역 공영주차장',
          detail: '인증 없는 주차가 3회 누적되면 표지 점검 대상이 돼요.',
        ),
      ];
}
