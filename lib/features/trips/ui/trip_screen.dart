import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../balances/ui/balances_tab.dart';
import '../../balances/ui/trip_summary_card.dart';
import '../../expenses/ui/expense_list.dart';
import '../../settlement/ui/settle_tab.dart';
import '../providers.dart';

/// 07·09·11 여행방. 총 지출·내 잔액 카드 아래 지출 · 잔액 · 정산 탭.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({
    super.key,
    required this.tripId,
    this.initialTab = TripTab.expenses,
  });

  final String tripId;
  final TripTab initialTab;

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  late var _tab = widget.initialTab;

  @override
  void didUpdateWidget(TripScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 여행방에 다른 탭 주소로 다시 왔을 때 (정산 확정 → 정산 탭)
    if (widget.initialTab != oldWidget.initialTab) _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
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
        data: (trip) {
          final me = trip.memberOf(userId);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    TripSummaryCard(trip: trip, me: me),
                    SegmentedTabs(
                      options: [for (final t in TripTab.values) (t, t.label)],
                      selected: _tab,
                      onSelect: (t) => setState(() => _tab = t),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (_tab) {
                  TripTab.expenses => ExpenseList(trip: trip, me: me),
                  TripTab.balances => BalancesTab(trip: trip, me: me),
                  TripTab.settle => SettleTab(trip: trip, me: me),
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: trip.hasValue && _tab != TripTab.settle
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newExpense(tripId)),
              icon: const Icon(Icons.add),
              label: const Text('지출 추가'),
            )
          : null,
    );
  }
}
