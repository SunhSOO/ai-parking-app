import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../domain/booking.dart';
import 'booking_controller.dart';

/// 내 예약 관리 (프로토타입 화면 10).
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final items = bookings.value ?? const <Booking>[];

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: '내 예약',
            subtitle:
                items.isEmpty ? '예약 없음' : '다가오는 예약 ${items.length}건',
          ),
          const SizedBox(height: 12),

          if (bookings.isLoading && items.isEmpty)
            const Loading()
          else if (bookings.hasError)
            ErrorState(
              message: '예약을 불러오지 못했어요',
              onRetry: () => ref.invalidate(bookingsProvider),
            )
          else if (items.isEmpty)
            const EmptyState(
              message: '아직 예약이 없어요 🗓️\n체육·생활시설에서 시간을 골라 보세요.',
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _BookingCard(booking: items[i]),
                ],
              ],
            ),

          const SizedBox(height: 12),
          GradientButton(
            label: '시설 더 찾아보기',
            height: 52,
            fontSize: 15,
            shadow: AppShadows.primaryButtonSmall,
            onPressed: () => context.go(Routes.facilities),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약을 취소할까요?'),
        content: Text('${booking.title}\n${booking.whenLabel}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('닫기', style: appText(size: 14, weight: 700, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('예약 취소', style: appText(size: 14, weight: 700, color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      await ref.read(bookingsProvider.notifier).cancel(booking.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('취소하지 못했어요: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmed = booking.status == BookingStatus.confirmed;

    return SurfaceCard(
      radius: AppRadius.r24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(booking.title, style: AppText.cardTitle())),
              const SizedBox(width: 10),
              confirmed
                  ? AppBadge.mint(booking.status.label)
                  : AppBadge.warning(booking.status.label),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.whenLabel,
            style: appText(size: 14, weight: 900, color: AppColors.purple),
          ),
          const SizedBox(height: 4),
          Text(
            booking.metaLabel,
            style: appText(size: 12, height: 1.6, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: '예약 취소',
                  fontSize: 13.5,
                  onPressed: () => _confirmCancel(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftButton(
                  label: '주차면 보기',
                  fontSize: 13.5,
                  background: AppColors.purpleA(.1),
                  color: AppColors.purple,
                  onPressed: () => context.go(Routes.map),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
