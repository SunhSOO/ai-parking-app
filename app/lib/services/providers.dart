import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../features/benefits/data/benefit_repository.dart';
import '../features/bookings/data/booking_repository.dart';
import '../features/certification/data/certification_repository.dart';
import '../features/facilities/data/facility_repository.dart';
import '../features/parking_map/data/parking_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/report/data/report_repository.dart';
import 'mock/mock_repositories.dart';
import 'social_auth/auth_service.dart';

/// 리포지토리 주입 지점.
///
/// `SUPABASE_URL`/`SUPABASE_ANON_KEY`가 주입돼 있으면 Supabase 구현을,
/// 없으면 목업 구현을 쓴다. 화면 코드는 어느 쪽인지 알 필요가 없다.

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!AppConfig.hasSupabase) {
    throw StateError('Supabase가 설정되지 않았습니다 (목업 모드)');
  }
  return Supabase.instance.client;
});

/// 소셜 로그인. 목업 모드에서는 항상 로그인된 상태로 시작해 12개 화면을 바로 볼 수 있다.
final authServiceProvider = Provider<AuthService>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseAuthService(ref.watch(supabaseClientProvider))
      : MockAuthService();
});

// 목업은 메모리 상태를 갖기 때문에 앱 전체에서 하나만 만들어 공유해야 한다.
final _mockFacilityRepositoryProvider =
    Provider<MockFacilityRepository>((ref) => MockFacilityRepository());

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseProfileRepository(ref.watch(supabaseClientProvider))
      : MockProfileRepository();
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseParkingRepository(ref.watch(supabaseClientProvider))
      : MockParkingRepository();
});

final certificationRepositoryProvider = Provider<CertificationRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseCertificationRepository(ref.watch(supabaseClientProvider))
      : MockCertificationRepository();
});

final benefitRepositoryProvider = Provider<BenefitRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseBenefitRepository(ref.watch(supabaseClientProvider))
      : MockBenefitRepository();
});

final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseFacilityRepository(ref.watch(supabaseClientProvider))
      : ref.watch(_mockFacilityRepositoryProvider);
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseBookingRepository(ref.watch(supabaseClientProvider))
      : MockBookingRepository(ref.watch(_mockFacilityRepositoryProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseReportRepository(ref.watch(supabaseClientProvider))
      : MockReportRepository();
});
