import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../trips/providers.dart';
import 'data/expense.dart';
import 'data/expenses_repository.dart';
import 'ui/expense_draft.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(supabaseProvider)),
);

/// 여행의 지출 목록. 여행방을 떠나면 버려서, 다시 열 때 새로 불러온다.
final expensesProvider = FutureProvider.autoDispose
    .family<List<Expense>, String>((ref, tripId) async {
      await ref.watch(authUserProvider.future);
      return ref.watch(expensesRepositoryProvider).list(tripId);
    });

/// 여행방이 열려 있는 동안 친구들의 변경을 실시간으로 받아 지출·여행 정보를 다시 불러온다.
final tripLiveUpdatesProvider = Provider.autoDispose.family<void, String>((
  ref,
  tripId,
) {
  final stop = ref.watch(expensesRepositoryProvider).watchTrip(tripId, () {
    ref
      ..invalidate(expensesProvider(tripId))
      ..invalidate(tripDetailProvider(tripId));
  });
  ref.onDispose(stop);
});

final expenseActionsProvider = Provider<ExpenseActions>(ExpenseActions.new);

class ExpenseActions {
  ExpenseActions(this._ref);

  final Ref _ref;

  /// 지출을 저장한다. [expenseId]가 있으면 수정. [memberIds]는 여행 멤버 순서.
  Future<void> save(
    String tripId,
    ExpenseDraft draft, {
    String? expenseId,
    required List<String> memberIds,
  }) async {
    await _ref
        .read(expensesRepositoryProvider)
        .save(
          tripId: tripId,
          expenseId: expenseId,
          title: draft.titleOrDefault,
          amount: draft.amount,
          currency: draft.currency,
          paidBy: draft.paidBy!,
          category: draft.category,
          spentAt: draft.spentAt,
          shares: draft.sharesIn(memberIds),
        );
    _ref.invalidate(expensesProvider(tripId));
  }

  Future<void> delete(String tripId, String expenseId) async {
    await _ref.read(expensesRepositoryProvider).delete(expenseId);
    _ref.invalidate(expensesProvider(tripId));
  }
}
