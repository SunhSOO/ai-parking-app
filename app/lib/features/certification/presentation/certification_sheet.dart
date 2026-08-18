import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../domain/certification.dart';
import 'certification_controller.dart';

/// 자동 인증 바텀시트.
///
/// 라우트가 아니라 셸 위에 얹히는 **오버레이**다. 탭을 옮겨 다녀도 그대로 떠 있고,
/// "숨기기"를 눌러도 인증 자체는 백그라운드에서 계속 진행된다.
class CertificationSheet extends ConsumerStatefulWidget {
  const CertificationSheet({super.key});

  @override
  ConsumerState<CertificationSheet> createState() => _CertificationSheetState();
}

class _CertificationSheetState extends ConsumerState<CertificationSheet>
    with SingleTickerProviderStateMixin {
  /// 프로토타입: `sheet .32s cubic-bezier(.2,.8,.2,1)`
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  bool _announced = false;

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// 완료 순간을 화면을 보지 않는 사용자에게도 알린다 (스크린리더 + 햅틱).
  void _onVerified(BuildContext context) {
    if (_announced) return;
    _announced = true;
    HapticFeedback.mediumImpact();

    if (!MediaQuery.supportsAnnounceOf(context)) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      '인증이 완료됐습니다. 단속 대상에서 제외됐어요.',
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(certificationControllerProvider);
    final cert = state.certification;
    if (cert == null) return const SizedBox.shrink();

    final done = cert.isVerified;
    final running = cert.isRunning;
    final failed = cert.status == CertStatus.failed;
    if (done) _onVerified(context);

    return Positioned.fill(
      child: FadeTransition(
        opacity: _enter,
        child: Stack(
          children: [
            // 딤 + 블러. 뒤쪽 탭을 실수로 누르지 못하게 막는다.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ColoredBox(color: AppColors.inkA(.45)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .12),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _enter,
                  curve: const Cubic(.2, .8, .2, 1),
                )),
                child: _Sheet(
                  cert: cert,
                  // 진행률은 서버가 알려 준 단계에서만 나온다 — 실제보다 앞서 나가지 않게.
                  progress: cert.status.progress,
                  done: done,
                  running: running,
                  failed: failed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends ConsumerWidget {
  const _Sheet({
    required this.cert,
    required this.progress,
    required this.done,
    required this.running,
    required this.failed,
  });

  final Certification cert;
  final double progress;
  final bool done;
  final bool running;
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(certificationControllerProvider.notifier);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheet,
        boxShadow: AppShadows.sheet,
      ),
      padding: EdgeInsets.fromLTRB(22, 14, 22, 26 + bottomInset),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.inkA(.12),
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),

            // 상태 점 + 킥커 + "자동 실행" 배지
            Row(
              children: [
                BlinkDot(
                  color: failed
                      ? AppColors.danger
                      : (done ? AppColors.mint : AppColors.purple),
                  size: 8,
                  animate: running,
                  period: const Duration(seconds: 1),
                ),
                const SizedBox(width: 9),
                Text(
                  cert.status.kicker,
                  style: appText(
                    size: 12,
                    weight: 900,
                    color: failed ? AppColors.danger : AppColors.purple,
                    emSpacing: .04,
                  ),
                ),
                const Spacer(),
                AppBadge.mint('자동 실행'),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              switch ((failed, done)) {
                (true, _) => '인증하지 못했어요',
                (_, true) => '인증됐어요 🎉',
                _ => '장애인주차면에\n도착했어요',
              },
              style: appText(size: 25, weight: 900, height: 1.25, emSpacing: -.02),
            ),
            const SizedBox(height: 5),
            Text(
              switch ((failed, done)) {
                (true, _) =>
                  '${cert.failReason ?? '알 수 없는 이유로 실패했어요'}. 마이페이지에서 차량을 등록하면 다음부터는 자동으로 인증돼요.',
                (_, true) when !cert.transmitted =>
                  '${cert.spotName ?? ''}. 인증 기록이 저장됐어요. '
                      '단속 시스템 연동은 준비 중이라 아직 전달되지 않았어요.',
                (_, true) => '${cert.spotName ?? ''}. 단속 대상에서 제외됐어요.',
                _ =>
                  '${cert.spotName ?? ''} · 반경 ${cert.radiusM}m. 그대로 두시면 인증이 끝나요.',
              },
              style: appText(size: 13, height: 1.65, color: AppColors.mutedStrong),
            ),

            const SizedBox(height: 16),
            ProgressBar(value: progress),
            const SizedBox(height: 14),

            _StepRow(
              label: '주차면 반경 ${cert.radiusM}m 진입',
              note: cert.stepDetectDone ? '확인' : '측정 중',
              done: cert.stepDetectDone,
            ),
            const SizedBox(height: 7),
            _StepRow(
              label: '등록 차량 ${cert.plate ?? ''} 대조',
              note: cert.stepMatchDone ? '일치' : '대기',
              done: cert.stepMatchDone,
            ),
            const SizedBox(height: 7),
            _StepRow(
              label: '단속 시스템에 인증 전달',
              // 아직 안 보냈으면 보냈다고 하지 않는다.
              note: cert.stepSendDone
                  ? '전달됨'
                  : (done ? '연동 대기' : '대기'),
              done: cert.stepSendDone,
            ),

            const SizedBox(height: 16),

            if (failed)
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '닫기',
                      height: 52,
                      fontSize: 15,
                      onPressed: controller.dismiss,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GradientButton(
                      label: '차량 등록하기',
                      height: 52,
                      fontSize: 15,
                      onPressed: () {
                        controller.dismiss();
                        context.go(Routes.profile);
                      },
                    ),
                  ),
                ],
              )
            else if (done)
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: '확인',
                      height: 52,
                      fontSize: 15,
                      onPressed: controller.dismiss,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SoftButton(
                    label: '확인증',
                    height: 52,
                    fontSize: 15,
                    expand: false,
                    onPressed: () {
                      controller.dismiss();
                      context.go(Routes.certification);
                    },
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '누르지 않아도 끝나요. 화면을 꺼도 계속 진행됩니다.',
                      style: appText(
                        size: 12,
                        height: 1.6,
                        color: AppColors.mutedWeak,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SoftButton(
                    label: '숨기기',
                    height: AppSizes.minTouch,
                    fontSize: 13,
                    expand: false,
                    onPressed: controller.hide,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.note, required this.done});

  final String label;
  final String note;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $note',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: done ? AppColors.mintA(.08) : AppColors.inkA(.03),
            borderRadius: AppRadius.r16,
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.mint : AppColors.inkA(.08),
                ),
                child: Text(
                  done ? '✓' : '·',
                  style: appText(
                    size: 12,
                    weight: 900,
                    color: done ? Colors.white : AppColors.faint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: appText(
                    size: 13,
                    weight: done ? 700 : 500,
                    color: done ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                note,
                style: appText(
                  size: 11,
                  weight: 700,
                  color: done ? AppColors.mintDeep : AppColors.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
