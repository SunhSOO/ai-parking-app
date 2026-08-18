import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

enum SocialProvider {
  kakao('카카오'),
  naver('네이버'),
  google('구글');

  const SocialProvider(this.label);

  final String label;
}

/// 소셜 로그인.
///
/// 구글·카카오는 네이티브 SDK로 받은 ID 토큰을 Supabase에 그대로 넘긴다.
/// **네이버는 Supabase가 기본 제공하는 provider가 아니라서**, 액세스 토큰을
/// Edge Function `naver-auth`에 보내 검증하고 세션을 받아 온다.
abstract class AuthService {
  bool get isSignedIn;

  /// 로그인 상태가 바뀔 때마다 알린다 (라우터 리다이렉트에 쓴다).
  Stream<bool> get changes;

  Future<void> signIn(SocialProvider provider);

  /// 개발용 이메일 계정으로 로그인한다. **디버그 빌드에서만 호출한다.**
  ///
  /// 카카오·네이버·구글 키가 아직 없어도 Supabase 경로(RLS·RPC·Realtime)를
  /// 끝까지 검증할 수 있게 하려고 둔 문이다. 릴리스에서는 버튼 자체가 뜨지 않는다.
  Future<void> signInWithTestAccount();

  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;
  bool _kakaoReady = false;
  bool _googleReady = false;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get changes =>
      _client.auth.onAuthStateChange.map((event) => event.session != null);

  @override
  Future<void> signIn(SocialProvider provider) => switch (provider) {
        SocialProvider.kakao => _signInWithKakao(),
        SocialProvider.naver => _signInWithNaver(),
        SocialProvider.google => _signInWithGoogle(),
      };

  // ------------------------------------------------------------------ 카카오
  Future<void> _signInWithKakao() async {
    if (!AppConfig.hasKakaoLogin) {
      throw StateError('카카오 앱 키가 설정되지 않았습니다');
    }

    if (!_kakaoReady) {
      await KakaoSdk.init(
        nativeAppKey: AppConfig.kakaoNativeAppKey,
        javaScriptAppKey: AppConfig.kakaoJavaScriptKey.isEmpty
            ? null
            : AppConfig.kakaoJavaScriptKey,
      );
      _kakaoReady = true;
    }

    final token = await isKakaoTalkInstalled()
        ? await UserApi.instance.loginWithKakaoTalk()
        : await UserApi.instance.loginWithKakaoAccount();

    final idToken = token.idToken;
    if (idToken == null) {
      // OpenID Connect가 꺼져 있으면 ID 토큰이 안 온다 → 웹 OAuth로 우회한다.
      await _client.auth.signInWithOAuth(OAuthProvider.kakao);
      return;
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
      accessToken: token.accessToken,
    );
  }

  // ------------------------------------------------------------------ 네이버
  Future<void> _signInWithNaver() async {
    final result = await FlutterNaverLogin.logIn();
    final accessToken = result.accessToken?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('네이버 로그인이 취소됐습니다: ${result.errorMessage ?? ''}');
    }

    // Supabase에 네이버 provider가 없어서 Edge Function이 대신 검증하고
    // refresh token을 돌려준다.
    final response = await _client.functions.invoke(
      'naver-auth',
      body: {'access_token': accessToken},
    );

    final data = response.data;
    final refreshToken = data is Map ? data['refresh_token'] as String? : null;
    if (refreshToken == null) {
      throw StateError('네이버 로그인 세션을 받지 못했습니다');
    }

    await _client.auth.setSession(refreshToken);
  }

  // -------------------------------------------------------------------- 구글
  Future<void> _signInWithGoogle() async {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        clientId: AppConfig.googleIosClientId.isEmpty
            ? null
            : AppConfig.googleIosClientId,
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      );
      _googleReady = true;
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('구글 ID 토큰을 받지 못했습니다');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  // 자격증명은 소스에 두지 않는다. config.json 으로 주입한다.
  // (Supabase는 .test / example.com 같은 예약 도메인을 거부하므로 실제 도메인을 쓴다)
  String get _testEmail => AppConfig.devLoginEmail;
  String get _testPassword => AppConfig.devLoginPassword;

  @override
  Future<void> signInWithTestAccount() async {
    if (!AppConfig.hasDevLogin) {
      throw StateError(
        'DEV_LOGIN_EMAIL / DEV_LOGIN_PASSWORD 가 주입되지 않았습니다. '
        'config.json 을 확인하세요.',
      );
    }

    try {
      await _client.auth.signInWithPassword(
        email: _testEmail,
        password: _testPassword,
      );
      return;
    } on AuthException {
      // 아직 없는 계정이면 만든다.
    }

    final signUp = await _client.auth.signUp(
      email: _testEmail,
      password: _testPassword,
    );

    if (signUp.session != null) return;

    // 세션이 안 왔다면 이메일 확인이 켜져 있다는 뜻이다.
    try {
      await _client.auth.signInWithPassword(
        email: _testEmail,
        password: _testPassword,
      );
    } on AuthException catch (e) {
      throw StateError(
        '테스트 계정 로그인 실패: ${e.message}\n'
        'Supabase 대시보드 > Authentication > Sign In / Providers 에서 '
        '"Confirm email"을 끄면 개발용 로그인이 됩니다.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // 구글로 로그인하지 않았으면 무시한다.
    }
  }
}

/// 목업 모드용. 어떤 버튼을 눌러도 바로 로그인된 것으로 친다.
class MockAuthService implements AuthService {
  MockAuthService({this.signedIn = true}) : _signedIn = signedIn;

  /// 목업 모드의 초기 로그인 상태 (테스트에서 false로 두면 로그인 화면부터 볼 수 있다)
  final bool signedIn;

  final _controller = StreamController<bool>.broadcast();
  bool _signedIn;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<void> signIn(SocialProvider provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    debugPrint('[mock-auth] ${provider.label} 로그인 (실제 인증 없음)');
    _signedIn = true;
    _controller.add(true);
  }

  @override
  Future<void> signInWithTestAccount() => signIn(SocialProvider.google);

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _controller.add(false);
  }
}
