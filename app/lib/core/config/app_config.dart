/// 빌드 시 주입되는 설정값.
///
/// 키를 소스에 넣지 않는다. 실행할 때 파일로 넘긴다:
/// ```
/// flutter run --dart-define-from-file=config.json
/// ```
/// `config.example.json`을 복사해 `config.json`을 만들어 쓴다 (git에 올리지 않음).
///
/// 값이 비어 있으면 해당 기능은 **목업 모드**로 동작한다. 키가 하나도 없어도
/// 12개 화면이 전부 돌아가야 한다 — 키 발급을 기다리며 개발이 멈추지 않게 하기 위함이다.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase 대시보드의 **publishable key** (예전 이름: anon key).
  /// 클라이언트에 노출돼도 되는 키다 — service_role 키는 절대 여기 넣지 않는다.
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// 네이버 클라우드 플랫폼 > Maps > Dynamic Map 의 Client ID
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

  /// 카카오 개발자 > 앱 키 > 네이티브 앱 키
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  /// 카카오 JavaScript 키 (웹 OAuth 폴백용)
  static const kakaoJavaScriptKey = String.fromEnvironment('KAKAO_JS_KEY');

  /// 구글 OAuth — iOS 클라이언트 ID / 서버(웹) 클라이언트 ID
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// 개발용 테스트 계정. 소스에 자격증명을 두지 않으려고 주입으로 뺐다.
  /// 디버그 빌드에서만 쓰이고, 값이 없으면 로그인 화면에 버튼 자체가 뜨지 않는다.
  static const devLoginEmail = String.fromEnvironment('DEV_LOGIN_EMAIL');
  static const devLoginPassword = String.fromEnvironment('DEV_LOGIN_PASSWORD');

  static bool get hasDevLogin =>
      devLoginEmail.isNotEmpty && devLoginPassword.isNotEmpty;

  /// Supabase Edge Function `naver-auth` 사용 여부는 URL 유무로 판단한다.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get hasNaverMap => naverMapClientId.isNotEmpty;

  static bool get hasKakaoLogin => kakaoNativeAppKey.isNotEmpty;

  static bool get hasGoogleLogin => googleServerClientId.isNotEmpty;

  /// 목업 모드에서 화면 상단에 배지를 띄워 실제 데이터가 아님을 알린다.
  static bool get isMockMode => !hasSupabase;
}
