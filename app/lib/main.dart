import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 프로토타입은 밝은 배경 + 어두운 글씨. 상태바 아이콘도 어둡게 맞춘다.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF3F4F9),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 키가 없으면 목업 모드로 뜬다 — 개발이 키 발급을 기다리며 멈추지 않게.
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
  } else {
    debugPrint('[config] Supabase 키가 없어 목업 모드로 실행합니다. '
        'config.json 을 만들고 --dart-define-from-file=config.json 으로 실행하세요.');
  }

  runApp(const ProviderScope(child: AiParkingApp()));
}
