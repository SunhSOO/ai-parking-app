import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers.dart';
import '../domain/certification.dart';

/// 자동 인증 시트의 표시 상태.
///
/// 핵심 규칙: **시트를 닫아도 인증은 계속 진행된다.** 그래서 [hidden]은 화면 표시
/// 여부일 뿐이고, 실제 진행 상태는 [certification]이 서버(또는 목업)에서 받은 값이다.
class CertificationState {
  const CertificationState({this.certification, this.hidden = false});

  final Certification? certification;

  /// 사용자가 "숨기기"를 눌렀는지
  final bool hidden;

  /// 시트를 지금 띄워야 하는지
  bool get sheetVisible => certification != null && !hidden;

  bool get isRunning => certification?.isRunning ?? false;
  bool get isVerified => certification?.isVerified ?? false;

  CertificationState copyWith({
    Certification? certification,
    bool? hidden,
    bool clearCertification = false,
  }) =>
      CertificationState(
        certification:
            clearCertification ? null : (certification ?? this.certification),
        hidden: hidden ?? this.hidden,
      );
}

class CertificationController extends Notifier<CertificationState> {
  StreamSubscription<Certification>? _sub;

  @override
  CertificationState build() {
    ref.onDispose(() => _sub?.cancel());
    // 앱을 다시 켰을 때 진행 중이던 세션을 이어받는다.
    Future.microtask(refresh);
    return const CertificationState();
  }

  /// 서버에 진행 중인 인증이 있는지 다시 확인한다.
  ///
  /// 앱이 백그라운드에 있는 동안 **지오펜스 콜백이 별도 isolate에서** 인증을
  /// 시작했을 수 있으므로, 앱이 다시 앞으로 나올 때마다 호출해야 한다.
  Future<void> refresh() async {
    final active = await ref.read(certificationRepositoryProvider).active();
    if (active == null) return;
    if (state.certification?.id == active.id) return;

    state = CertificationState(certification: active);
    _listen(active.id);
  }

  /// 지오펜스 진입(또는 "지금 인증 실행")으로 인증을 시작한다.
  Future<void> start(String spotId, {CertMethod method = CertMethod.autoGeofence}) async {
    final repo = ref.read(certificationRepositoryProvider);
    final cert = await repo.start(spotId, method: method);
    state = CertificationState(certification: cert);
    _listen(cert.id);
  }

  void _listen(String certificationId) {
    _sub?.cancel();
    _sub = ref
        .read(certificationRepositoryProvider)
        .watch(certificationId)
        .listen((cert) {
      state = state.copyWith(certification: cert);
    });
  }

  /// "숨기기" — 시트만 닫는다. 백그라운드 진행은 그대로.
  void hide() => state = state.copyWith(hidden: true);

  void show() => state = state.copyWith(hidden: false);

  /// 완료 후 "확인" — 시트를 닫는다. 인증 자체는 주차면을 뜰 때까지 유효하다.
  void dismiss() => state = state.copyWith(hidden: true);

  /// 주차면 이탈 — 인증 종료
  Future<void> end() async {
    final cert = state.certification;
    if (cert == null) return;
    await ref.read(certificationRepositoryProvider).end(cert.id);
    await _sub?.cancel();
    state = const CertificationState();
  }
}

final certificationControllerProvider =
    NotifierProvider<CertificationController, CertificationState>(
  CertificationController.new,
);

/// 인증 이력 — 확인증 화면과 홈의 "이번 달 인증" 통계가 함께 쓴다.
final certificationHistoryProvider =
    FutureProvider.autoDispose<List<Certification>>((ref) async {
  // 인증이 끝날 때마다 이력을 다시 읽는다.
  ref.watch(certificationControllerProvider.select((s) => s.isVerified));
  return ref.watch(certificationRepositoryProvider).history();
});
