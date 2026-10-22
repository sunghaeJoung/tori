import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/screen_placeholder.dart';

/// 10 정산 환율 확인.
class RateScreen extends StatelessWidget {
  const RateScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      title: '정산 환율 확인',
      stage: 7,
      actions: [
        FilledButton(
          onPressed: () => context.pop(),
          child: const Text('이 환율로 정산하기'),
        ),
        TextButton(onPressed: () => context.pop(), child: const Text('취소')),
      ],
    );
  }
}
