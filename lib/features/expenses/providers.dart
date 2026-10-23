import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../trips/data/trip.dart';
import '../trips/providers.dart';
import 'data/expense.dart';
import 'data/expense_draft.dart';
import 'data/expenses_repository.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(supabaseProvider)),
);

/// 여행의 지출 목록. 친구가 바꾸면 실시간으로 다시 불러온다.
/// 여행방을 떠나면 버려서, 다시 열 때 새로 불러온다.
final expensesProvider = FutureProvider.autoDispose
    .family<List<Expense>, String>((ref, tripId) async {
      ref.watch(tripChangesProvider(tripId));
      await ref.watch(authUserProvider.future);
      return ref.watch(expensesRepositoryProvider).list(tripId);
    });

final expenseActionsProvider = Provider<ExpenseActions>(ExpenseActions.new);

class ExpenseActions {
  ExpenseActions(this._ref);

  final Ref _ref;

  /// 지출을 저장한다. [expenseId]가 있으면 수정. [draft]는 [ExpenseDraft.canSave]여야 한다.
  Future<void> save(
    TripDetail trip,
    ExpenseDraft draft, {
    String? expenseId,
  }) async {
    await _ref
        .read(expensesRepositoryProvider)
        .save(
          tripId: trip.id,
          expenseId: expenseId,
          title: draft.titleOrDefault,
          amount: draft.amount,
          currency: draft.currency,
          paidBy: draft.paidBy!,
          category: draft.category,
          spentAt: draft.spentAt,
          shares: draft.sharesIn(trip.memberIds),
        );
    _ref.invalidate(expensesProvider(trip.id));
  }

  Future<void> delete(String tripId, String expenseId) async {
    await _ref.read(expensesRepositoryProvider).delete(expenseId);
    _ref.invalidate(expensesProvider(tripId));
  }
}
