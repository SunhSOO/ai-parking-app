import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/ios_switch.dart';
import '../../../core/widgets/rows.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../domain/profile.dart';
import 'profile_controller.dart';

/// 마이페이지 · 장애정보 (프로토타입 화면 11).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final vehicle = ref.watch(primaryVehicleProvider).value;

    return ScreenScaffold(
      child: switch (profileAsync) {
        AsyncValue(hasError: true) => ErrorState(
            message: '프로필을 불러오지 못했어요',
            onRetry: () => ref.invalidate(profileProvider),
          ),
        AsyncValue(value: final profile?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileCard(profile: profile),
              const SizedBox(height: 14),
              _QualificationCard(profile: profile, plate: vehicle?.plate),
              const SizedBox(height: 14),
              _NotificationCard(profile: profile),
              const SizedBox(height: 14),
              SoftButton(
                label: '등록증 다시 인증하기',
                height: 50,
                onPressed: () => context.push(Routes.onboarding),
              ),
            ],
          ),
        _ => const Loading(height: 400),
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: AppRadius.r26,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GradientAvatar(initials: profile.initials, size: 58, fontSize: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    profile.name ?? '이름 없음',
                    style: appText(size: 19, weight: 900),
                  ),
                ),
                const SizedBox(height: 2),
                Text(profile.profileSummary, style: AppText.meta(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualificationCard extends StatelessWidget {
  const _QualificationCard({required this.profile, this.plate});

  final Profile profile;
  final String? plate;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('장애 유형·정도', profile.disabilityLabel.isEmpty ? '미확인' : profile.disabilityLabel),
      ('거주 지자체', profile.sigungu ?? '미확인'),
      (
        '연령 · 가구',
        [
          if (profile.age != null) '${profile.age}세',
          if (profile.householdSize != null) '${profile.householdSize}인 가구',
        ].join(' · '),
      ),
      ('수급 자격', profile.incomeBracket ?? '해당 없음'),
      ('등록 차량', plate ?? '미등록'),
      ('주차 표지', profile.permitType.permitLabel),
    ];

    return SurfaceCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('장애·자격 정보', style: appText(size: 13.5, weight: 900)),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            KeyValueRow(
              label: rows[i].$1,
              value: rows[i].$2.isEmpty ? '미확인' : rows[i].$2,
              valueSize: 13,
              verticalPadding: 11,
              last: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = notifCategories.entries.toList();

    return SurfaceCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('받고 싶은 혜택 알림', style: appText(size: 13.5, weight: 900)),
          const SizedBox(height: 6),
          for (var i = 0; i < entries.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 50),
              decoration: i == entries.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.inkA(.05)),
                      ),
                    ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entries[i].value,
                      style: appText(size: 13.5, weight: 500),
                    ),
                  ),
                  IosSwitch(
                    semanticLabel: '${entries[i].value} 알림',
                    value: profile.notif[entries[i].key] ?? false,
                    onChanged: (value) => ref
                        .read(profileProvider.notifier)
                        .toggleNotif(entries[i].key, value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
