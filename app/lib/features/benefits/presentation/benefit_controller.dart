import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/simple_notifier.dart';
import '../../../services/providers.dart';
import '../domain/benefit.dart';

/// 피드에서 선택된 카테고리 칩.
final benefitCategoryProvider =
    NotifierProvider<SimpleNotifier<String>, String>(
  () => SimpleNotifier('all'),
);

/// 신청 상태가 바뀌면 피드를 다시 읽게 하는 카운터.
final _benefitRevisionProvider = NotifierProvider<SimpleNotifier<int>, int>(
  () => SimpleNotifier(0),
);

/// 카테고리 필터가 적용된 혜택 피드 (적합도 내림차순).
final benefitFeedProvider = FutureProvider<List<Benefit>>((ref) async {
  ref.watch(_benefitRevisionProvider);
  final category = ref.watch(benefitCategoryProvider);
  return ref.watch(benefitRepositoryProvider).feed(categoryId: category);
});

/// 필터와 무관한 전체 목록 — 홈의 "새 맞춤 혜택" 개수에 쓴다.
final allBenefitsProvider = FutureProvider<List<Benefit>>((ref) async {
  ref.watch(_benefitRevisionProvider);
  return ref.watch(benefitRepositoryProvider).feed();
});

final benefitDetailProvider =
    FutureProvider.family<Benefit?, String>((ref, id) async {
  ref.watch(_benefitRevisionProvider);
  return ref.watch(benefitRepositoryProvider).byId(id);
});

/// 혜택 신청. 성공하면 피드·상세가 모두 "신청 접수됨"으로 바뀐다.
final applyBenefitProvider = Provider((ref) {
  return (String benefitId) async {
    await ref.read(benefitRepositoryProvider).apply(benefitId);
    ref.read(_benefitRevisionProvider.notifier).update((n) => n + 1);
  };
});
