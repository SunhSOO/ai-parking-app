import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../services/mock/mock_data.dart';
import '../../../services/providers.dart';
import '../../../services/social_auth/auth_service.dart';
import '../../profile/presentation/profile_controller.dart';

/// 로그인 (프로토타입에 없던 화면 — 같은 디자인 언어로 새로 만든 것).
///
/// 소셜 로그인 → (처음이면) 복지카드 온보딩 → 홈.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  SocialProvider? _pending;
  bool _devPending = false;

  static const _pillars = [
    ('1', AppGradients.chipPurple, '팝업 하나로 끝나는 인증',
        '주차면 반경에 들어오면 앱이 스스로 팝업을 띄우고 인증을 끝냅니다.'),
    ('2', AppGradients.chipMint, '나에게 맞는 혜택만',
        '장애유형·지자체·가구·수급 자격을 대조해 적합도와 근거를 보여 줘요.'),
    ('3', AppGradients.chipBlue, '예약하면 자리까지',
        '체육센터·복지관을 예약하면 목적지 주차면 1면을 함께 잡아 둬요.'),
  ];

  Future<void> _signIn(SocialProvider provider) async {
    setState(() => _pending = provider);
    try {
      await ref.read(authServiceProvider).signIn(provider);
      if (!mounted) return;

      // 처음 들어온 사용자는 복지카드 인증부터.
      ref.invalidate(profileProvider);
      final profile = await ref.read(profileProvider.future);
      if (!mounted) return;

      context.go(profile?.isOnboarded == true ? Routes.home : Routes.onboarding);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.label} 로그인에 실패했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  /// 개발용 로그인. 소셜 provider 키가 없어도 Supabase 경로를 검증하려고 둔 것으로,
  /// 릴리스 빌드에서는 버튼 자체가 렌더되지 않는다.
  ///
  /// 새로 만든 계정은 프로필이 비어 있어 혜택 매칭이 돌지 않으므로,
  /// 데모 자격 정보를 한 번 채워 준다 (목업 모드와 같은 값 → 적합도도 같아야 정상).
  Future<void> _devSignIn() async {
    setState(() => _devPending = true);
    try {
      await ref.read(authServiceProvider).signInWithTestAccount();

      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.fetchProfile();
      if (current == null || !current.isVerified) {
        await repo.saveProfile(MockData.profile());
        await repo.savePrimaryVehicle(MockData.vehicle.plate);
      }

      ref.invalidate(profileProvider);
      ref.invalidate(primaryVehicleProvider);
      if (!mounted) return;
      context.go(Routes.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), duration: const Duration(seconds: 6)),
      );
    } finally {
      if (mounted) setState(() => _devPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandBadge(),
              const SizedBox(height: 18),

              Semantics(
                header: true,
                child: _GradientHeadline(),
              ),
              const SizedBox(height: 12),
              Text(
                '장애인주차면에 차를 세우면 인증 팝업이 저절로 떠서 스스로 끝납니다. '
                '그 이력이 맞춤 복지혜택과 시설 예약으로 이어져요.',
                style: appText(size: 14, height: 1.7, color: AppColors.mutedStrong),
              ),
              const SizedBox(height: 26),

              for (final (number, gradient, title, body) in _pillars) ...[
                _PillarRow(
                  number: number,
                  gradient: gradient,
                  title: title,
                  body: body,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 20),

              _SocialButton(
                label: '카카오로 시작하기',
                background: const Color(0xFFFEE500),
                foreground: const Color(0xFF191600),
                icon: '💬',
                busy: _pending == SocialProvider.kakao,
                onPressed: _pending != null
                    ? null
                    : () => _signIn(SocialProvider.kakao),
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: '네이버로 시작하기',
                background: const Color(0xFF03C75A),
                foreground: Colors.white,
                icon: 'N',
                busy: _pending == SocialProvider.naver,
                onPressed: _pending != null
                    ? null
                    : () => _signIn(SocialProvider.naver),
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: '구글로 시작하기',
                background: AppColors.surface,
                foreground: AppColors.ink,
                icon: 'G',
                bordered: true,
                busy: _pending == SocialProvider.google,
                onPressed: _pending != null
                    ? null
                    : () => _signIn(SocialProvider.google),
              ),

              const SizedBox(height: 18),
              Text(
                '로그인하면 복지카드로 자격을 한 번 확인해요. '
                '촬영본은 인증 직후 폐기되고 자격 여부만 저장됩니다.',
                style: appText(size: 12, height: 1.7, color: AppColors.mutedWeak),
              ),

              // 개발용 — 디버그 빌드 + Supabase 설정이 있을 때만 보인다.
              if (kDebugMode && AppConfig.hasSupabase && AppConfig.hasDevLogin) ...[
                const SizedBox(height: 20),
                SoftButton(
                  label: _devPending ? '연결 중…' : '🛠 개발용 테스트 계정으로 로그인',
                  height: 50,
                  fontSize: 13.5,
                  color: AppColors.mutedStrong,
                  onPressed: _devPending ? null : _devSignIn,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pill,
        boxShadow: AppShadows.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final color in [AppColors.purple, AppColors.mint, AppColors.blue]) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              'G-AILAB · AI PARKING',
              style: appText(
                size: 11.5,
                weight: 700,
                color: AppColors.purple,
                emSpacing: .08,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "자동 인증"만 퍼플→블루 그라디언트로 칠한 제목.
class _GradientHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = appText(size: 32, weight: 900, height: 1.15, emSpacing: -.03);

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: '주차하면 알아서\n'),
          TextSpan(
            text: '자동 인증',
            style: base.copyWith(
              foreground: Paint()
                ..shader = AppGradients.progress.createShader(
                  const Rect.fromLTWH(0, 0, 200, 40),
                ),
            ),
          ),
          const TextSpan(text: ' 되는 앱'),
        ],
      ),
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.number,
    required this.gradient,
    required this.title,
    required this.body,
  });

  final String number;
  final Gradient gradient;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: AppRadius.r20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            size: 40,
            radius: 14,
            gradient: gradient,
            child: Text(
              number,
              style: appText(size: 15, weight: 900, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.cardTitle(15.5)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: appText(size: 12.5, height: 1.6, color: AppColors.mutedStrong),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onPressed,
    this.bordered = false,
    this.busy = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final String icon;
  final VoidCallback? onPressed;
  final bool bordered;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadius.pill,
            border: bordered ? Border.all(color: AppColors.inkA(.12)) : null,
            boxShadow: AppShadows.chip,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: AppRadius.pill,
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                alignment: Alignment.center,
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: foreground,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            icon,
                            style: appText(
                              size: 15,
                              weight: 900,
                              color: foreground,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: appText(size: 15.5, weight: 700, color: foreground),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
