import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// 앱 전역 테마.
///
/// 화면은 전부 커스텀 위젯으로 그리므로 Material 컴포넌트 테마는 최소한만 맞춘다.
/// (다이얼로그·스낵바처럼 직접 그리지 않는 것들만)
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    primary: AppColors.purple,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'NotoSansKR',
    splashFactory: InkSparkle.splashFactory,
    textTheme: _textTheme,
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.r24),
      titleTextStyle: appText(size: 17, weight: 900),
      contentTextStyle: appText(size: 14, height: 1.6, color: AppColors.mutedStrong),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: appText(size: 13.5, weight: 500, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.r16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.purple,
      selectionColor: AppColors.purpleA(.2),
      selectionHandleColor: AppColors.purple,
    ),
  );
}

/// 기본 TextTheme — 직접 스타일을 주지 않은 텍스트도 잉크색·가변굵기를 갖게 한다.
final TextTheme _textTheme = TextTheme(
  displayLarge: appText(size: 36, weight: 900, emSpacing: -.03),
  headlineLarge: appText(size: 27, weight: 900, height: 1.25, emSpacing: -.02),
  headlineMedium: appText(size: 24, weight: 900, height: 1.3, emSpacing: -.02),
  titleLarge: appText(size: 21, weight: 900, emSpacing: -.02),
  titleMedium: appText(size: 16, weight: 900, emSpacing: -.01),
  titleSmall: appText(size: 15.5, weight: 700, height: 1.35),
  bodyLarge: appText(size: 14, height: 1.7),
  bodyMedium: appText(size: 13, height: 1.65),
  bodySmall: appText(size: 12, color: AppColors.muted),
  labelLarge: appText(size: 15, weight: 700),
  labelMedium: appText(size: 13, weight: 700),
  labelSmall: appText(size: 11.5, weight: 700, emSpacing: .05),
);

/// 안드로이드 오버스크롤 글로우 제거 — 프로토타입은 스크롤바·글로우가 없다.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
