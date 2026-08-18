import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../services/providers.dart';
import '../domain/report.dart';

/// 내가 받은 경고 목록.
final warningsProvider = FutureProvider<List<Warning>>((ref) async {
  return ref.watch(reportRepositoryProvider).warnings();
});

/// 부정주차 신고 · 경고 (프로토타입 화면 12).
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  ReportReason? _reason;
  File? _photo;
  Report? _submitted;
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Text('📷', style: TextStyle(fontSize: 20)),
              title: Text('사진 찍기', style: appText(size: 15, weight: 700)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
              title: Text('앨범에서 고르기', style: appText(size: 15, weight: 700)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;

    setState(() => _submitting = true);
    try {
      final report = await ref.read(reportRepositoryProvider).submit(
            reason: reason,
            photo: _photo,
          );
      if (!mounted) return;
      setState(() => _submitted = report);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고를 접수하지 못했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _submitted;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ScreenScaffold(
        // 신고 화면에는 탭바가 없으므로 하단 여백도 필요 없다.
        bottomClearance: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackTextButton(label: '홈', onTap: () => context.pop()),
            const SizedBox(height: 14),
            if (submitted == null) ..._form() else ..._done(submitted),
          ],
        ),
      ),
    );
  }

  List<Widget> _form() => [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text('부정주차 신고 🚨', style: AppText.heading(24)),
              ),
              const SizedBox(height: 8),
              Text(
                '사진 한 장이면 돼요. 현장 카메라 기록과 맞춰 보고, 확인되면 담당 지자체로 넘어갑니다.',
                style: appText(size: 13.5, height: 1.75, color: AppColors.mutedStrong),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _PhotoDropZone(photo: _photo, onTap: _pickPhoto),
        const SizedBox(height: 14),

        SurfaceCard(
          radius: AppRadius.r24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('신고 사유', style: appText(size: 13.5, weight: 900)),
              const SizedBox(height: 8),
              for (final reason in ReportReason.values) ...[
                _ReasonRow(
                  reason: reason,
                  selected: _reason == reason,
                  onTap: () => setState(() => _reason = reason),
                ),
                if (reason != ReportReason.values.last) const SizedBox(height: 7),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        GradientButton(
          label: _submitting ? '접수 중…' : '신고 접수',
          gradient: AppGradients.danger,
          shadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              blurRadius: 24,
              color: AppColors.danger.withValues(alpha: .35),
            ),
          ],
          onPressed: (_reason == null || _submitting) ? null : _submit,
        ),
      ];

  List<Widget> _done(Report report) => [
        DarkGradientCard(
          glowColor: AppColors.mintA(.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(
                label: '접수 ${report.receiptNo ?? '—'}',
                background: AppColors.mintLight.withValues(alpha: .15),
                foreground: AppColors.mintLight,
                fontSize: 11.5,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              ),
              const SizedBox(height: 13),
              Text(
                '신고가 접수됐어요 ✓',
                style: appText(
                  size: 25,
                  weight: 900,
                  height: 1.25,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '현장 카메라 영상과 대조 중입니다. 결과는 알림으로 알려 드릴게요. '
                '평균 확인 시간은 약 12분이에요.',
                style: appText(
                  size: 13,
                  height: 1.75,
                  color: Colors.white.withValues(alpha: .8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _WarningCard(),
        const SizedBox(height: 20),
        SoftButton(
          label: '홈으로',
          height: 52,
          fontSize: 14.5,
          onPressed: () => context.go(Routes.home),
        ),
      ];
}

/// 사진 업로드 존 — 점선 테두리 140px.
class _PhotoDropZone extends StatelessWidget {
  const _PhotoDropZone({required this.photo, required this.onTap});

  final File? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: photo == null ? '차량 번호가 보이게 사진 올리기' : '사진 다시 고르기',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.r24,
              border: Border.all(color: AppColors.purpleA(.35), width: 2),
            ),
            alignment: Alignment.center,
            child: photo == null
                ? Text(
                    '📷\n차량 번호가 보이게\n사진을 올려 주세요',
                    textAlign: TextAlign.center,
                    style: appText(size: 13, height: 1.65, color: AppColors.muted),
                  )
                : Image.file(photo!, fit: BoxFit.cover, width: double.infinity),
          ),
        ),
      ),
    );
  }
}

/// 신고 사유 라디오 행.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: reason.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.purpleA(.08) : AppColors.fillWeak,
              borderRadius: AppRadius.r16,
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.purple : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.purple : AppColors.inkA(.2),
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reason.label,
                    style: appText(
                      size: 13.5,
                      weight: selected ? 700 : 500,
                      color: selected ? AppColors.purple : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "내가 받은 경고" 카드.
class _WarningCard extends ConsumerWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(warningsProvider).value ?? const <Warning>[];

    return SurfaceCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('내가 받은 경고', style: appText(size: 13.5, weight: 900)),
          const SizedBox(height: 10),
          if (warnings.isEmpty)
            Text('받은 경고가 없어요 👍', style: AppText.meta(13))
          else
            for (final warning in warnings) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      warning.label,
                      style: appText(size: 13.5, weight: 700),
                    ),
                  ),
                  AppBadge.warning('경고'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  historyTime(warning.occurredAt),
                  if (warning.spotName != null) warning.spotName!,
                ].join(' · '),
                style: appText(size: 12, height: 1.65, color: AppColors.muted),
              ),
              if (warning.detail != null)
                Text(
                  warning.detail!,
                  style: appText(size: 12, height: 1.65, color: AppColors.muted),
                ),
            ],
        ],
      ),
    );
  }
}
