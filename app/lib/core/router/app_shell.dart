import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/certification/presentation/certification_controller.dart';
import '../../features/certification/presentation/certification_sheet.dart';
import '../theme/tokens.dart';
import '../widgets/floating_tab_bar.dart';
import 'app_router.dart';

/// 탭 5개를 감싸는 셸. 각 탭은 자기 네비게이션 스택을 유지한다
/// (혜택 상세를 보다 다른 탭에 갔다 돌아오면 그 상세가 그대로 있다).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _onTap(int index) {
    // 이미 있는 탭을 다시 누르면 그 탭의 첫 화면으로 되돌린다.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // 자동 인증 시트는 라우트가 아니라 셸 위의 오버레이다.
    // 탭을 옮겨도 떠 있고, 시트를 닫아도 인증은 백그라운드에서 계속된다.
    final sheetVisible = ref.watch(
      certificationControllerProvider.select((s) => s.sheetVisible),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          shell,
          Positioned(
            left: 14,
            right: 14,
            bottom: 14 + bottomInset,
            child: FloatingTabBar(
              items: tabLabels,
              currentIndex: shell.currentIndex,
              onTap: _onTap,
            ),
          ),
          if (sheetVisible) const CertificationSheet(),
        ],
      ),
    );
  }
}
