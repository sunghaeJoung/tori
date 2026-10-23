import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/async_view.dart';
import '../../expenses/ui/expense_list.dart';
import '../providers.dart';

/// 07 여행방. 잔액·정산 탭은 7단계에서 붙인다.
class TripScreen extends ConsumerWidget {
  const TripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDetailProvider(tripId));
    final userId = ref.watch(authUserProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '홈으로',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.popOrGo(Routes.home),
        ),
        title: Text(trip.value?.name ?? ''),
        actions: [
          IconButton(
            tooltip: '친구 초대',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => context.push(Routes.invite(tripId)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView(
        value: trip,
        onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        errorTitle: '여행을 불러오지 못했어요',
        data: (trip) => ExpenseList(trip: trip, me: trip.memberOf(userId)),
      ),
      floatingActionButton: trip.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newExpense(tripId)),
              icon: const Icon(Icons.add),
              label: const Text('지출 추가'),
            )
          : null,
    );
  }
}
