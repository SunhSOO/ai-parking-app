import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 값 하나만 들고 있는 최소 Notifier.
///
/// Riverpod 3에서 `StateProvider`가 없어졌기 때문에, 화면 로컬 상태(선택된 칩,
/// 선택된 주차면 같은 것)를 담을 자리로 쓴다.
///
/// ```dart
/// final categoryProvider =
///     NotifierProvider<SimpleNotifier<String>, String>(() => SimpleNotifier('all'));
///
/// ref.read(categoryProvider.notifier).set('culture');
/// ```
class SimpleNotifier<T> extends Notifier<T> {
  SimpleNotifier(this.initial);

  final T initial;

  @override
  T build() => initial;

  void set(T value) => state = value;

  void update(T Function(T current) fn) => state = fn(state);
}
