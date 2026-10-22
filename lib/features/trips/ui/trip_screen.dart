import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/screen_placeholder.dart';

/// 07·09·11 여행방 (지출 내역 · 잔액 · 정산 탭).
class TripScreen extends StatelessWidget {
  const TripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      title: '여행방',
      stage: 6,
      actions: [
        FilledButton(
          onPressed: () => context.push(Routes.newExpense(tripId)),
          child: const Text('지출 추가'),
        ),
        FilledButton.tonal(
          onPressed: () => context.push(Routes.invite(tripId)),
          child: const Text('친구 초대'),
        ),
        TextButton(
          onPressed: () => context.push(Routes.settle(tripId)),
          child: const Text('정산하기'),
        ),
      ],
    );
  }
}
