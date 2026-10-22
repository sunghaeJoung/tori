import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/screen_placeholder.dart';

/// 08 지출 추가 · 수정. [expenseId]가 있으면 수정.
class ExpenseFormScreen extends StatelessWidget {
  const ExpenseFormScreen({super.key, required this.tripId, this.expenseId});

  final String tripId;
  final String? expenseId;

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      title: expenseId == null ? '지출 추가' : '지출 수정',
      stage: 6,
      actions: [
        FilledButton(onPressed: () => context.pop(), child: const Text('저장')),
      ],
    );
  }
}
