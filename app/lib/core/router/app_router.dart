import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/benefits/presentation/benefit_detail_screen.dart';
import '../../features/benefits/presentation/benefit_feed_screen.dart';
import '../../features/bookings/presentation/bookings_screen.dart';
import '../../features/certification/presentation/certification_screen.dart';
import '../../features/facilities/presentation/facilities_screen.dart';
import '../../features/facilities/presentation/facility_book_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/parking_map/presentation/parking_map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/report/presentation/report_screen.dart';
import '../../services/providers.dart';
import 'app_shell.dart';

/// 라우트 경로 상수. 화면 코드에서 문자열을 직접 쓰지 않는다.
class Routes {
  const Routes._();

  static const login = '/login';
  static const onboarding = '/onboarding';
  static const report = '/report';

  static const home = '/home';
  static const certification = '/certification';
  static const map = '/map';
  static const benefits = '/benefits';
  static const facilities = '/facilities';
  static const bookings = '/bookings';
  static const profile = '/profile';

  static String benefitDetail(String id) => '/benefits/$id';
  static String facilityBook(String id) => '/facilities/$id/book';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// 탭 순서 — 홈 / 주차면 / 혜택 / 예약 / 마이
const tabLabels = ['홈', '주차면', '혜택', '예약', '마이'];

/// 로그인 상태가 바뀌면 go_router가 redirect를 다시 평가하게 한다.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<bool> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<bool> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _AuthRefresh(auth.changes);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.isSignedIn;
      final atLogin = state.matchedLocation == Routes.login;

      if (!signedIn && !atLogin) return Routes.login;
      if (signedIn && atLogin) return Routes.home;
      return null;
    },
    routes: [
      // ---------------------------------------------------------------- 셸 바깥
      // 탭바가 뜨지 않는 전체 화면들
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.report,
        builder: (context, state) => const ReportScreen(),
      ),

      // ------------------------------------------------------------------- 셸
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          // 0. 홈 — 인증 확인증도 홈 탭에서 활성으로 보인다
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: Routes.certification,
                builder: (context, state) => const CertificationScreen(),
              ),
            ],
          ),

          // 1. 주차면 지도
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (context, state) => const ParkingMapScreen(),
              ),
            ],
          ),

          // 2. 혜택 — 피드와 상세
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.benefits,
                builder: (context, state) => const BenefitFeedScreen(),
                routes: [
                  GoRoute(
                    path: ':benefitId',
                    builder: (context, state) => BenefitDetailScreen(
                      benefitId: state.pathParameters['benefitId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. 예약 — 내 예약 / 시설 검색 / 시설 예약
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.bookings,
                builder: (context, state) => const BookingsScreen(),
              ),
              GoRoute(
                path: Routes.facilities,
                builder: (context, state) => const FacilitiesScreen(),
                routes: [
                  GoRoute(
                    path: ':facilityId/book',
                    builder: (context, state) => FacilityBookScreen(
                      facilityId: state.pathParameters['facilityId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 4. 마이페이지
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
