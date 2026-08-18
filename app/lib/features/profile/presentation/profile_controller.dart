import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers.dart';
import '../domain/profile.dart';

/// 현재 사용자 프로필. 온보딩·홈·혜택 피드·마이페이지가 모두 이걸 본다.
final profileProvider = AsyncNotifierProvider<ProfileController, Profile?>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() =>
      ref.watch(profileRepositoryProvider).fetchProfile();

  Future<void> save(Profile profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).saveProfile(profile),
    );
  }

  /// 혜택 알림 토글. 실패하면 이전 값으로 되돌린다.
  Future<void> toggleNotif(String key, bool value) async {
    final previous = state.value;
    if (previous != null) {
      // 토글은 즉시 반응해야 하므로 낙관적으로 먼저 반영한다.
      final notif = Map<String, bool>.from(previous.notif)..[key] = value;
      state = AsyncValue.data(previous.copyWith(notif: notif));
    }

    try {
      final updated =
          await ref.read(profileRepositoryProvider).setNotif(key, value);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    }
  }
}

/// 등록 차량 (대표 1대).
final primaryVehicleProvider = FutureProvider<Vehicle?>((ref) async {
  final vehicles = await ref.watch(profileRepositoryProvider).fetchVehicles();
  return vehicles.isEmpty ? null : vehicles.first;
});
