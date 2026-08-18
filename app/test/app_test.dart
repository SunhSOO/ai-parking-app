import 'package:ai_parking/app.dart';
import 'package:ai_parking/core/util/format.dart';
import 'package:ai_parking/core/widgets/floating_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이 테스트들은 전부 **목업 모드**에서 돈다 (dart-define이 없으므로).
/// 즉 `MockAuthService` + `Mock*Repository`가 쓰이고 실제 네트워크·플러그인은
/// 건드리지 않는다.
///
/// 주의: 화면에 무한 반복 애니메이션(BlinkDot)이 있어 `pumpAndSettle`은 절대
/// 끝나지 않는다. 항상 [settle]처럼 정해진 시간만큼만 pump 한다.

Future<void> pumpApp(WidgetTester tester) async {
  // 프로토타입 프레임과 같은 390×846으로 맞춘다.
  // 기본값(800×600)이면 가로로 늘어나 탭 좌표가 어긋난다.
  tester.view.physicalSize = const Size(390 * 3, 846 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const ProviderScope(child: AiParkingApp()));
  // 테스트 환경에는 위치 플러그인이 없어 응답이 오지 않는다.
  // 5초 타임아웃이 지나야 기준 좌표로 떨어지므로 그만큼 시간을 앞당긴다.
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  await settle(tester);
}

/// 목업 리포지토리의 지연(약 220ms)과 전환 애니메이션이 끝날 만큼만 진행시킨다.
Future<void> settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 300));
}

/// 스크롤해서 보이게 한 뒤 누른다. 화면이 길어 대부분의 요소가 뷰포트 밖에 있다.
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder finder, [
  int ms = 700,
]) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder, warnIfMissed: false);
  await settle(tester, ms);
}

Future<void> tapText(WidgetTester tester, String text, [int ms = 700]) =>
    tapAndSettle(tester, find.text(text).first, ms);

Finder tab(String label) => find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.text(label),
    );

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(tab(label));
  await settle(tester);
}

void main() {
  testWidgets('앱이 뜨고 홈과 플로팅 탭바 5개가 보인다', (tester) async {
    await pumpApp(tester);

    for (final label in ['홈', '주차면', '혜택', '예약', '마이']) {
      expect(tab(label), findsOneWidget, reason: '탭 "$label"이 없다');
    }
    expect(find.text('선형수님'), findsOneWidget);
    expect(find.text('주차하면\n알아서 인증돼요'), findsOneWidget);
  });

  testWidgets('탭을 누르면 각 화면으로 이동한다', (tester) async {
    await pumpApp(tester);

    await tapTab(tester, '혜택');
    expect(find.text('내게 맞는 혜택 ✨'), findsOneWidget);

    await tapTab(tester, '예약');
    expect(find.text('내 예약'), findsOneWidget);

    await tapTab(tester, '주차면');
    expect(find.text('주변 장애인주차면'), findsOneWidget);

    await tapTab(tester, '마이');
    expect(find.text('장애·자격 정보'), findsOneWidget);
  });

  group('자동 인증', () {
    testWidgets('실행하면 3단계를 거쳐 완료되고 시트가 뜬다', (tester) async {
      await pumpApp(tester);

      await tapText(tester, '지금 인증 실행', 300);

      // 시트가 떴고 첫 단계가 진행 중이다.
      expect(find.text('장애인주차면에\n도착했어요'), findsOneWidget);
      // 시트 하단과 (뒤에 가려진) 홈 히어로에 같은 문구가 함께 떠 있다.
      expect(find.text('누르지 않아도 끝나요. 화면을 꺼도 계속 진행됩니다.'), findsWidgets);
      expect(find.text('측정 중'), findsOneWidget);

      // 프로토타입 타이밍: 감지 1.1s → 대조 2.5s → 전달 3.9s
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('인증됐어요 🎉'), findsOneWidget);
      expect(find.text('일치'), findsOneWidget); // 차량 대조는 실제로 끝났다

      // 단속 시스템(G.Eye-Parking) 연동 전에는 "전달됨"이라고 하면 안 된다.
      // 보내지 않고 보냈다고 표시하면 사용자가 그걸 믿고 차를 두고 간다.
      expect(find.text('연동 대기'), findsOneWidget);
      expect(find.text('전달됨'), findsNothing);

      // 완료 시에만 나오는 두 버튼
      expect(find.text('확인증'), findsOneWidget);
      expect(find.text('숨기기'), findsNothing);
    });

    testWidgets('"숨기기"를 눌러도 인증은 계속 진행된다', (tester) async {
      await pumpApp(tester);

      await tapText(tester, '지금 인증 실행', 300);
      await tapText(tester, '숨기기', 300);

      // 시트는 사라졌지만
      expect(find.text('장애인주차면에\n도착했어요'), findsNothing);
      // 홈 히어로는 계속 진행 중을 보여 준다.
      expect(find.text('자동 인증 진행 중'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));

      // 인증은 백그라운드에서 끝났다.
      expect(find.text('인증 완료 · 단속 제외'), findsOneWidget);
      expect(find.text('확인증 보기'), findsOneWidget);
    });
  });

  group('복지혜택', () {
    testWidgets('적합도 순으로 보이고 카테고리로 걸러진다', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, '혜택');

      expect(find.text('98%'), findsOneWidget);
      expect(find.text('장애인 자동차 취득세·자동차세 감면'), findsOneWidget);
      expect(find.text('장애인 콜택시 이용권 월 20회'), findsOneWidget);

      await tapText(tester, '이동·교통');

      expect(find.text('장애인 콜택시 이용권 월 20회'), findsOneWidget);
      expect(find.text('장애인 자동차 취득세·자동차세 감면'), findsNothing);
    });

    testWidgets('상세에서 신청하면 접수됨으로 바뀐다', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, '혜택');

      await tapText(tester, '장애인 콜택시 이용권 월 20회');

      expect(find.text('🎯 이 혜택이 뜬 이유'), findsOneWidget);
      expect(find.text('보행상 장애'), findsWidgets);

      await tapText(tester, '바로 신청하기', 900);

      expect(find.text('✓ 신청 접수됨 · 진행 보기'), findsOneWidget);
    });
  });

  group('시설 예약', () {
    testWidgets('날짜·시간을 고르면 예약되고 내 예약에 추가된다', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, '예약');

      expect(find.text('다가오는 예약 2건'), findsOneWidget);

      await tapText(tester, '시설 더 찾아보기');
      expect(find.text('체육·생활시설'), findsOneWidget);

      await tapText(tester, '성남 반다비체육센터');

      // 날짜를 고르기 전에는 CTA가 비활성이다.
      expect(find.text('날짜와 시간을 골라 주세요'), findsOneWidget);

      final today = DateTime.now();
      await tapAndSettle(
        tester,
        find.bySemanticsLabel('${monthDay(today)} ${weekdayLabel(today)}요일'),
      );
      await tapText(tester, '13:00');

      expect(find.textContaining('13:00 예약하기'), findsOneWidget);
      await tapAndSettle(tester, find.textContaining('13:00 예약하기'), 900);

      expect(find.text('다가오는 예약 3건'), findsOneWidget);
    });

    testWidgets('예약을 취소하면 확인 다이얼로그를 거쳐 목록에서 빠진다', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, '예약');

      expect(find.text('다가오는 예약 2건'), findsOneWidget);

      await tapText(tester, '예약 취소');
      expect(find.text('예약을 취소할까요?'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(TextButton, '예약 취소'),
        900,
      );

      expect(find.text('다가오는 예약 1건'), findsOneWidget);
    });
  });

  group('신고', () {
    testWidgets('사유를 고르기 전에는 접수되지 않고, 접수하면 접수번호가 나온다', (tester) async {
      await pumpApp(tester);

      await tapText(tester, '🚨 부정주차 신고하기');
      expect(find.text('부정주차 신고 🚨'), findsOneWidget);

      // 사유를 안 골랐으므로 눌러도 접수 화면 그대로다.
      await tapText(tester, '신고 접수');
      expect(find.text('부정주차 신고 🚨'), findsOneWidget);

      await tapText(tester, '표지는 있지만 본인 미탑승');
      await tapText(tester, '신고 접수', 1200);

      expect(find.text('신고가 접수됐어요 ✓'), findsOneWidget);
      expect(find.textContaining('접수 R-'), findsOneWidget);
      expect(find.text('내가 받은 경고'), findsOneWidget);
    });
  });

  group('마이페이지', () {
    testWidgets('자격 정보가 보이고 알림 토글이 동작한다', (tester) async {
      await pumpApp(tester);
      await tapTab(tester, '마이');

      expect(find.text('지체장애 2급 · 성남시 중원구'), findsOneWidget);
      expect(find.text('12가 3456'), findsOneWidget);

      final toggle = find.bySemanticsLabel('이동·교통 알림');
      expect(toggle, findsOneWidget);

      await tapAndSettle(tester, toggle);

      // 토글은 낙관적으로 즉시 반영된다 — 예외 없이 넘어가면 통과.
      expect(find.text('받고 싶은 혜택 알림'), findsOneWidget);
    });
  });
}
