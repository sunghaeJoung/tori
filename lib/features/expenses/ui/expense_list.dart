import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/settlement.dart';
import '../../../shared/dates.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../trips/data/trip.dart';
import '../data/expense.dart';
import '../providers.dart';
import 'category_icon.dart';

/// 07 여행방의 지출 탭: 총 지출·내 잔액 카드와 날짜별 지출 목록.
class ExpenseList extends ConsumerWidget {
  const ExpenseList({super.key, required this.trip, required this.me});

  final TripDetail trip;

  /// 이 여행에서 내 멤버. 모르면 null (내 몫·내 잔액을 빼고 보여준다).
  final Member? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider(trip.id));
    return AsyncView(
      value: expenses,
      onRetry: () => ref.invalidate(expensesProvider(trip.id)),
      errorTitle: '지출을 불러오지 못했어요',
      data: (expenses) => RefreshIndicator(
        onRefresh: () => ref.refresh(expensesProvider(trip.id).future),
        child: ListView(
          // 아래 '지출 추가' 버튼에 마지막 지출이 가리지 않게
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            _SummaryCard(trip: trip, expenses: expenses, me: me),
            const SizedBox(height: 16),
            if (expenses.isEmpty)
              const EmptyState(title: '아직 지출이 없어요', message: '첫 지출을 추가해보세요')
            else
              ..._groupByDay(expenses)
                  .map((day) => _DayGroup(trip: trip, me: me, expenses: day)),
          ],
        ),
      ),
    );
  }

  /// 이미 날짜순으로 정렬된 지출을 날짜별로 묶는다.
  static List<List<Expense>> _groupByDay(List<Expense> expenses) {
    final days = <List<Expense>>[];
    for (final e in expenses) {
      if (days.lastOrNull?.first.spentAt != e.spentAt) days.add([]);
      days.last.add(e);
    }
    return days;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.trip,
    required this.expenses,
    required this.me,
  });

  final TripDetail trip;
  final List<Expense> expenses;
  final Member? me;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // 현지 통화 먼저, 원화(미리 결제한 항공권 등)는 뒤에
    final currencies = {trip.currency, Currency.krw};
    final totals = {
      for (final c in currencies)
        c: expenses
            .where((e) => e.currency == c)
            .fold(0, (sum, e) => sum + e.amount),
    }..removeWhere((c, total) => total == 0 && c != trip.currency);
    final balances = computeBalances([
      for (final m in trip.members) m.id,
    ], expenses.map((e) => e.toEntry()));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: ToriColors.surface,
        border: Border.all(color: ToriColors.cardBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text('총 지출', style: text.bodySmall),
          Text(
            totals.entries.map((t) => formatMoney(t.value, t.key)).join(' + '),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (me case final me? when balances.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 잔액',
                  style: text.bodyMedium?.copyWith(color: ToriColors.textMuted),
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      for (final MapEntry(key: c, value: byMember)
                          in balances.entries)
                        MoneyText(
                          byMember[me.id]!,
                          c,
                          balance: true,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.trip,
    required this.me,
    required this.expenses,
  });

  final TripDetail trip;
  final Member? me;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              formatMonthDay(expenses.first.spentAt),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final e in expenses) _ExpenseRow(trip: trip, me: me, expense: e),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.trip,
    required this.me,
    required this.expense,
  });

  final TripDetail trip;
  final Member? me;
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final payer = trip.members
        .where((m) => m.id == expense.paidBy)
        .firstOrNull
        ?.name;
    final myShare = me == null ? null : expense.shares[me!.id];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(Routes.expense(trip.id, expense.id)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            spacing: 14,
            children: [
              CategoryTile(expense.category),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      expense.title,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${payer ?? '알 수 없음'} 결제 · ${expense.shares.length}명',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 3,
                children: [
                  MoneyText(
                    expense.amount,
                    expense.currency,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (me != null)
                    Text(
                      myShare == null
                          ? '참여 안 함'
                          : '내 몫 ${formatMoney(myShare, expense.currency)}',
                      style: text.bodySmall?.copyWith(fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
