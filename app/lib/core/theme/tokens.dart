import 'package:flutter/widgets.dart';

/// 프로토타입(`장애인 동승인증 앱.dc.html`)의 Design Tokens를 1:1로 옮긴 것.
///
/// 화면 코드에서는 **여기 정의된 값만** 사용한다. 색·그림자·그라디언트를
/// 화면에 직접 써 넣지 않는다.
class AppColors {
  const AppColors._();

  // 기본
  static const ink = Color(0xFF17163A);
  static const bg = Color(0xFFF3F4F9);
  static const surface = Color(0xFFFFFFFF);

  // Primary — 퍼플
  static const purple = Color(0xFF6A5AE0);
  static const purpleAlt = Color(0xFF7C63EC);
  static const purpleLight = Color(0xFF8B7BF4);
  static const purpleDeep = Color(0xFF5A48D8);

  // Blue
  static const blue = Color(0xFF3AA8F0);
  static const blueAlt = Color(0xFF5D8DF6);
  static const blueText = Color(0xFF2694DE);

  // Mint
  static const mint = Color(0xFF2ED8A7);
  static const mintDeep = Color(0xFF0B7A5C);
  static const mintLight = Color(0xFF7DFFD8);
  static const greenText = Color(0xFF0B9F76);

  // 상태
  static const danger = Color(0xFFE0485A);
  static const dangerAlt = Color(0xFFF06A50);
  static const warning = Color(0xFFE08600);
  static const warningDeep = Color(0xFFC66A00);

  // 다크 서피스 (확인증 카드, 신고 접수 카드)
  static const darkCard = Color(0xFF17163A);
  static const darkCardAlt = Color(0xFF2A2860);

  /// `rgba(23,22,58, a)` — 프로토타입이 잉크색에 알파를 씌워 쓰는 값들.
  static Color inkA(double opacity) => ink.withValues(alpha: opacity);

  /// `rgba(106,90,224, a)`
  static Color purpleA(double opacity) => purple.withValues(alpha: opacity);

  /// `rgba(46,216,167, a)`
  static Color mintA(double opacity) => mint.withValues(alpha: opacity);

  /// `rgba(58,168,240, a)`
  static Color blueA(double opacity) => blue.withValues(alpha: opacity);

  /// `rgba(255,159,67, a)` — 경고/대기 상태 칩
  static Color orangeA(double opacity) =>
      const Color(0xFFFF9F43).withValues(alpha: opacity);

  /// `rgba(255,205,60, a)` — 이동지원 시설 아이콘 칩
  static Color yellowA(double opacity) =>
      const Color(0xFFFFCD3C).withValues(alpha: opacity);

  // 자주 쓰는 조합
  static Color get muted => inkA(.5);
  static Color get mutedStrong => inkA(.55);
  static Color get mutedWeak => inkA(.45);
  static Color get faint => inkA(.35);
  static Color get hairline => inkA(.06);
  static Color get fill => inkA(.06);
  static Color get fillWeak => inkA(.03);
}

/// CSS `linear-gradient`를 Flutter로 옮긴 것.
///
/// CSS 각도 → Flutter 정렬 매핑: 90deg = 좌→우, 135deg·150deg·160deg = 좌상→우하.
class AppGradients {
  const AppGradients._();

  /// `linear-gradient(90deg,#6A5AE0,#7C63EC)` — 주 CTA 버튼, 활성 칩·탭
  static const primary = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.purple, AppColors.purpleAlt],
  );

  /// `linear-gradient(160deg,#6A5AE0,#7C63EC)` — 날짜·시간 선택 칩
  static const primaryDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.purple, AppColors.purpleAlt],
  );

  /// `linear-gradient(135deg,#6A5AE0 0%,#7C63EC 55%,#3AA8F0 130%)` — 홈 히어로 카드
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.purple, AppColors.purpleAlt, AppColors.blue],
    stops: [0.0, 0.55, 1.0],
  );

  /// `linear-gradient(135deg,#6A5AE0,#3AA8F0)` — 프로필 아바타
  static const avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.purple, AppColors.blue],
  );

  /// `linear-gradient(90deg,#6A5AE0,#3AA8F0)` — 진행바, 온보딩 스텝바
  static const progress = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.purple, AppColors.blue],
  );

  /// `linear-gradient(150deg,#17163A,#2A2860)` — 확인증 · 신고 접수 카드
  static const dark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.darkCard, AppColors.darkCardAlt],
  );

  /// `linear-gradient(90deg,#E0485A,#F06A50)` — 신고 접수 CTA
  static const danger = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.danger, AppColors.dangerAlt],
  );

  /// 혜택 카드 아이콘 칩 (`135deg,#6A5AE0,#8B7BF4`)
  static const chipPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.purple, AppColors.purpleLight],
  );

  static const chipMint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.mint, Color(0xFF1FB88C)],
  );

  static const chipBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.blue, AppColors.blueAlt],
  );

  /// `linear-gradient(135deg,rgba(106,90,224,.08),rgba(58,168,240,.08))`
  /// — "이 혜택이 뜬 이유" 카드, "목적지 주차면" 카드
  static LinearGradient get tintPurpleBlue => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.purpleA(.08), AppColors.blueA(.08)],
      );
}

/// CSS `box-shadow` → `BoxShadow`.
class AppShadows {
  const AppShadows._();

  /// `0 6px 18px rgba(23,22,58,.05)` — 기본 카드
  static List<BoxShadow> get card => [
        BoxShadow(
          offset: const Offset(0, 6),
          blurRadius: 18,
          color: AppColors.inkA(.05),
        ),
      ];

  /// `0 8px 24px rgba(23,22,58,.06)` — 온보딩 카드처럼 조금 더 뜬 카드
  static List<BoxShadow> get cardRaised => [
        BoxShadow(
          offset: const Offset(0, 8),
          blurRadius: 24,
          color: AppColors.inkA(.06),
        ),
      ];

  /// `0 4px 12px rgba(23,22,58,.05~.06)` — 비활성 칩
  static List<BoxShadow> get chip => [
        BoxShadow(
          offset: const Offset(0, 4),
          blurRadius: 12,
          color: AppColors.inkA(.05),
        ),
      ];

  /// `0 16px 36px rgba(106,90,224,.35)` — 홈 히어로 카드
  static List<BoxShadow> get hero => [
        BoxShadow(
          offset: const Offset(0, 16),
          blurRadius: 36,
          color: AppColors.purpleA(.35),
        ),
      ];

  /// `0 16px 36px rgba(23,22,58,.3)` — 다크 확인증 카드
  static List<BoxShadow> get darkCard => [
        BoxShadow(
          offset: const Offset(0, 16),
          blurRadius: 36,
          color: AppColors.inkA(.3),
        ),
      ];

  /// `0 10px 24px rgba(106,90,224,.35)` — 주 CTA 버튼
  static List<BoxShadow> get primaryButton => [
        BoxShadow(
          offset: const Offset(0, 10),
          blurRadius: 24,
          color: AppColors.purpleA(.35),
        ),
      ];

  /// `0 8px 18px rgba(106,90,224,.3)` — 보조 퍼플 버튼·선택된 칩
  static List<BoxShadow> get primaryButtonSmall => [
        BoxShadow(
          offset: const Offset(0, 8),
          blurRadius: 18,
          color: AppColors.purpleA(.3),
        ),
      ];

  /// `0 12px 32px rgba(23,22,58,.14)` — 플로팅 탭바
  static List<BoxShadow> get tabBar => [
        BoxShadow(
          offset: const Offset(0, 12),
          blurRadius: 32,
          color: AppColors.inkA(.14),
        ),
      ];

  /// `0 8px 20px rgba(0,0,0,.12)` — 히어로 위의 흰 버튼
  static List<BoxShadow> get onHeroButton => [
        const BoxShadow(
          offset: Offset(0, 8),
          blurRadius: 20,
          color: Color(0x1F000000),
        ),
      ];

  /// `0 6px 14px rgba(23,22,58,.18)` — 지도 핀
  static List<BoxShadow> get pin => [
        BoxShadow(
          offset: const Offset(0, 6),
          blurRadius: 14,
          color: AppColors.inkA(.18),
        ),
      ];

  /// `0 -12px 40px rgba(23,22,58,.2)` — 자동 인증 바텀시트
  static List<BoxShadow> get sheet => [
        BoxShadow(
          offset: const Offset(0, -12),
          blurRadius: 40,
          color: AppColors.inkA(.2),
        ),
      ];

  /// `0 2px 6px rgba(23,22,58,.2)` — 토글 스위치 노브
  static List<BoxShadow> get knob => [
        BoxShadow(
          offset: const Offset(0, 2),
          blurRadius: 6,
          color: AppColors.inkA(.2),
        ),
      ];
}

/// 모서리 반경. 칩·버튼은 항상 pill(StadiumBorder)이다.
class AppRadius {
  const AppRadius._();

  static const pill = BorderRadius.all(Radius.circular(999));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r18 = BorderRadius.all(Radius.circular(18));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r22 = BorderRadius.all(Radius.circular(22));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const r26 = BorderRadius.all(Radius.circular(26));
  static const r28 = BorderRadius.all(Radius.circular(28));

  /// 자동 인증 바텀시트 — `34px 34px 42px 42px`
  static const sheet = BorderRadius.vertical(
    top: Radius.circular(34),
    bottom: Radius.circular(42),
  );
}

/// 터치 타깃 최소 크기. 접근성 요건이라 화면에서 임의로 줄이지 않는다.
class AppSizes {
  const AppSizes._();

  /// 모든 탭 가능 요소의 최소 높이
  static const minTouch = 44.0;

  /// 주 CTA 버튼
  static const ctaHeight = 56.0;

  /// 보조 버튼 / 카드 안 액션
  static const actionHeight = 46.0;

  /// 화면 좌우 여백 (프로토타입: padding 0 20px + 카드 내부 6px)
  static const screenPadding = 20.0;

  /// 플로팅 탭바가 가리는 높이 — 스크롤 뷰 하단 패딩
  static const tabBarClearance = 96.0;
}
