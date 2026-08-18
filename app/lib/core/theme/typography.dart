import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Noto Sans KR **가변 폰트** 하나로 400/500/700/900을 낸다.
///
/// 가변 폰트는 `fontWeight`만으로는 굵기가 바뀌지 않는다. 반드시
/// `fontVariations: [FontVariation('wght', …)]`를 함께 줘야 한다.
/// 그래서 화면에서 `TextStyle(...)`을 직접 만들지 말고 **항상 [appText]를 통한다.**
///
/// 프로토타입의 CSS 값을 그대로 옮기기 쉽도록 인자 이름을 맞췄다.
/// - [size]      → `font-size` (px)
/// - [weight]    → `font-weight` (400 · 500 · 700 · 900)
/// - [height]    → `line-height` (배수)
/// - [emSpacing] → `letter-spacing` (em 단위, 예: -.02)
TextStyle appText({
  double size = 14,
  int weight = 400,
  Color? color,
  double? height,
  double emSpacing = 0,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: 'NotoSansKR',
    fontSize: size,
    fontWeight: _weightOf(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    color: color ?? AppColors.ink,
    height: height,
    letterSpacing: emSpacing == 0 ? null : emSpacing * size,
    decoration: decoration,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

FontWeight _weightOf(int w) => switch (w) {
      <= 400 => FontWeight.w400,
      <= 500 => FontWeight.w500,
      <= 700 => FontWeight.w700,
      _ => FontWeight.w900,
    };

/// 프로토타입에서 반복되는 텍스트 스타일 묶음.
/// 일회성 크기는 [appText]를 직접 쓴다.
class AppText {
  const AppText._();

  /// 화면 제목 — `21px/900, -.02em` (홈 인사, 각 화면 h3)
  static TextStyle get screenTitle =>
      appText(size: 21, weight: 900, emSpacing: -.02);

  /// 큰 제목 — `24~27px/900` (온보딩, 혜택 상세)
  static TextStyle heading(double size) =>
      appText(size: size, weight: 900, height: 1.3, emSpacing: -.02);

  /// 섹션 헤더 — `16px/900` ("오늘의 알림", "인증 이력")
  static TextStyle get section =>
      appText(size: 16, weight: 900, emSpacing: -.01);

  /// 카드 제목 — `15~15.5px/700`
  static TextStyle cardTitle([double size = 15.5]) =>
      appText(size: size, weight: 700, height: 1.35);

  /// 본문 — `13~14px/1.7, muted`
  static TextStyle body([double size = 14]) =>
      appText(size: size, height: 1.7, color: AppColors.mutedStrong);

  /// 카드 메타 — `11.5~12.5px, muted`
  static TextStyle meta([double size = 12]) =>
      appText(size: size, color: AppColors.muted);

  /// 키-값 표의 키 — `12.5~13px, muted`
  static TextStyle get rowKey => appText(size: 13, color: AppColors.muted);

  /// 키-값 표의 값 — `13~14.5px/700`
  static TextStyle rowValue([double size = 14.5]) =>
      appText(size: size, weight: 700);

  /// 칩·배지 라벨 — `11~11.5px/700, .04~.06em`
  static TextStyle badge([double size = 11.5]) =>
      appText(size: size, weight: 700, emSpacing: .05);

  /// 버튼 라벨 — `14~16px/700`
  static TextStyle button([double size = 16]) =>
      appText(size: size, weight: 700);

  /// 통계 숫자 — `24px/900`
  static TextStyle stat(Color color) =>
      appText(size: 24, weight: 900, color: color, emSpacing: -.02);
}
