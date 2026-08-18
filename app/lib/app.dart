import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/background_services.dart';

class AiParkingApp extends ConsumerWidget {
  const AiParkingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AI 주차 인증',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // 글자 크기는 사용자 설정을 존중하되, 레이아웃이 깨지는 극단값은 막는다.
        final scaler = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: BackgroundServices(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
