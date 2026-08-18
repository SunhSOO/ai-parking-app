import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/rows.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../services/geofence_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/providers.dart';
import '../../parking_map/presentation/parking_controller.dart';
import '../../profile/domain/profile.dart';
import '../../profile/presentation/profile_controller.dart';

/// 온보딩 · 장애인등록증 인증 3단계 (프로토타입 화면 1).
///
/// 복지카드 **촬영본은 저장하지 않는다.** 검증 결과(자격 여부)만 프로필에 남는다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  PermitType _permit = PermitType.self;
  final _plateController = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;

  static const _steps = [
    (
      title: '복지카드로 시작해요',
      desc: '장애인등록증을 한 번만 확인하면, 이후 주차 인증은 앱이 알아서 합니다.',
      cta: '카드 촬영하기',
    ),
    (
      title: '이 정보가 맞나요?',
      desc: '읽어온 자격 정보로 맞춤 혜택을 골라 드려요. 저장되는 건 자격 여부뿐입니다.',
      cta: '맞아요, 다음',
    ),
    (
      title: '차량을 등록해 주세요',
      desc: '주차장 카메라가 읽은 번호판과 대조해, 인증된 주차는 단속에서 자동 제외해요.',
      cta: '가입 마치기',
    ),
  ];

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    await _finish();
  }

  /// 자동 인증에 필요한 권한을 온보딩 마지막에 한 번만 요청한다.
  ///
  /// 순서가 중요하다: 알림 → 위치(사용 중) → 위치(항상). iOS는 "항상 허용"을
  /// 곧바로 물어볼 수 없어 사용 중 권한을 받은 뒤에 승격을 요청해야 한다.
  /// 거부해도 가입은 계속 진행된다 — 홈이 "앱을 열어 둔 동안만 인증됨"으로 안내한다.
  Future<void> _requestPermissions() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await NotificationService.instance.requestPermission();
      await GeofenceService.instance.requestLocationPermission();
    } catch (e) {
      debugPrint('[onboarding] 권한 요청 실패: $e');
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await _requestPermissions();
      final plate = _plateController.text.trim();
      if (plate.isNotEmpty) {
        await ref.read(profileRepositoryProvider).savePrimaryVehicle(plate);
        ref.invalidate(primaryVehicleProvider);
      }

      final profile = ref.read(profileProvider).value;
      if (profile != null) {
        await ref.read(profileProvider.notifier).save(
              profile.copyWith(
                permitType: _permit,
                cardVerifiedAt: DateTime.now(),
                onboardedAt: DateTime.now(),
              ),
            );
      }

      ref.invalidate(backgroundPermissionProvider);
      if (!mounted) return;
      context.go(Routes.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장하지 못했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final vehicle = ref.watch(primaryVehicleProvider).value;

    // 기존 정보가 있으면 한 번만 채워 둔다 (마이페이지에서 다시 들어온 경우).
    if (!_prefilled && profile != null) {
      _prefilled = true;
      _permit = profile.permitType;
      _plateController.text = vehicle?.plate ?? '';
    }

    final step = _steps[_step];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StepBar(step: _step),
                    const SizedBox(height: 20),

                    AppBadge.purple('STEP ${_step + 1} / 3', fontSize: 11.5),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(step.title, style: AppText.heading(27)),
                    ),
                    const SizedBox(height: 8),
                    Text(step.desc, style: AppText.body()),
                    const SizedBox(height: 20),

                    switch (_step) {
                      0 => const _ScanStep(),
                      1 => _InfoStep(profile: profile),
                      _ => _VehicleStep(
                          controller: _plateController,
                          permit: _permit,
                          onPermit: (p) => setState(() => _permit = p),
                        ),
                    },
                  ],
                ),
              ),
            ),

            // CTA는 스크롤과 무관하게 항상 아래에 붙어 있다.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                children: [
                  GradientButton(
                    label: _saving ? '저장 중…' : step.cta,
                    onPressed: _saving ? null : _next,
                  ),
                  const SizedBox(height: 8),
                  GhostButton(
                    label: '나중에 하기',
                    fontSize: 13.5,
                    weight: 500,
                    color: AppColors.mutedWeak,
                    onPressed: () => context.go(Routes.home),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 1 — 복지카드 촬영.
class _ScanStep extends StatelessWidget {
  const _ScanStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 212,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.r26,
            boxShadow: AppShadows.cardRaised,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Floaty(child: _CardIllustration()),
              const SizedBox(height: 14),
              Text(
                '복지카드를 사각형 안에\n맞춰 주세요',
                textAlign: TextAlign.center,
                style: appText(size: 13, height: 1.6, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const BlinkDot(color: AppColors.mint),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '촬영본은 인증 직후 폐기되고 자격 여부만 저장돼요',
                  style: appText(size: 12.5, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 복지카드 일러스트 — 84×56, 2px 퍼플 테두리.
class _CardIllustration extends StatelessWidget {
  const _CardIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.purple, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 9,
            top: 9,
            child: Container(
              width: 18,
              height: 24,
              decoration: BoxDecoration(
                gradient: AppGradients.avatar,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Positioned(
            right: 9,
            top: 13,
            child: _Line(width: 36, color: AppColors.inkA(.2)),
          ),
          Positioned(
            right: 9,
            top: 23,
            child: _Line(width: 26, color: AppColors.inkA(.12)),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.pill),
    );
  }
}

/// Step 2 — 읽어온 자격 정보 확인.
class _InfoStep extends StatelessWidget {
  const _InfoStep({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const Loading();

    final rows = <(String, String)>[
      ('이름', profile!.name ?? '—'),
      ('장애 유형·정도', profile!.disabilityLabel.isEmpty ? '—' : profile!.disabilityLabel),
      ('거주 지자체', profile!.sigungu ?? '—'),
      (
        '연령 · 가구',
        [
          if (profile!.age != null) '${profile!.age}세',
          if (profile!.householdSize != null) '${profile!.householdSize}인 가구',
        ].join(' · '),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SurfaceCard(
          radius: AppRadius.r24,
          shadow: AppShadows.cardRaised,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++)
                KeyValueRow(
                  label: rows[i].$1,
                  value: rows[i].$2.isEmpty ? '—' : rows[i].$2,
                  verticalPadding: 13,
                  last: i == rows.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '읽어온 정보가 맞나요? 다르면 마이페이지에서 언제든 고칠 수 있어요.',
            style: appText(size: 12.5, height: 1.7, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

/// Step 3 — 차량 번호와 주차 표지 종류.
class _VehicleStep extends StatelessWidget {
  const _VehicleStep({
    required this.controller,
    required this.permit,
    required this.onPermit,
  });

  final TextEditingController controller;
  final PermitType permit;
  final ValueChanged<PermitType> onPermit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            '차량 번호',
            style: appText(size: 12, weight: 700, color: AppColors.muted),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.r18,
            border: Border.all(color: AppColors.purpleA(.25), width: 2),
          ),
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            style: appText(size: 19, weight: 900, emSpacing: .05),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '12가 3456',
              hintStyle: appText(
                size: 19,
                weight: 900,
                emSpacing: .05,
                color: AppColors.inkA(.25),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(
            '주차 가능 표지',
            style: appText(size: 12, weight: 700, color: AppColors.muted),
          ),
        ),
        Row(
          children: [
            for (final option in PermitType.values) ...[
              if (option != PermitType.values.first) const SizedBox(width: 8),
              Expanded(
                child: _PermitOption(
                  label: option.label,
                  selected: permit == option,
                  onTap: () => onPermit(option),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        const NoticeBox(
          text: '등록한 번호판은 주차장 카메라가 읽은 번호와 대조돼요. '
              '자동 인증이 붙은 주차는 단속에서 제외됩니다.',
        ),
        const SizedBox(height: 10),
        // 다음 단계에서 뜰 권한 팝업을 미리 설명한다. 갑자기 뜨면 거부율이 높아진다.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '가입을 마치면 위치와 알림 권한을 물어봐요. '
            '화면을 꺼 둔 상태에서도 인증이 끝나려면 위치를 "항상 허용"으로 두셔야 해요.',
            style: appText(size: 12.5, height: 1.7, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _PermitOption extends StatelessWidget {
  const _PermitOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? AppGradients.primary : null,
              color: selected ? null : AppColors.surface,
              borderRadius: AppRadius.r18,
              boxShadow:
                  selected ? AppShadows.primaryButtonSmall : AppShadows.chip,
            ),
            child: Text(
              label,
              style: appText(
                size: 14.5,
                weight: 700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
