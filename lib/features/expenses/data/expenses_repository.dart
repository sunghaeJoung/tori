import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/currency.dart';
import '../../../shared/dates.dart';
import 'expense.dart';

class ExpensesRepository {
  const ExpensesRepository(this._client);

  final SupabaseClient _client;

  /// 여행의 지출(부담액 포함). 최근 날짜 순, 같은 날이면 나중에 넣은 것 먼저.
  Future<List<Expense>> list(String tripId) async {
    final rows = await _client
        .from('expenses')
        .select(
          'id, title, amount, currency, paid_by, category, spent_at, '
          'expense_splits(member_id, share_amount)',
        )
        .eq('trip_id', tripId)
        .order('spent_at', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Expense.fromJson).toList();
  }

  /// 지출을 저장하고 id를 돌려준다. [expenseId]가 있으면 수정.
  /// 지출과 부담액은 save_expense RPC가 한 번에 저장한다.
  ///
  /// 수정하려던 지출이 이미 지워졌으면 [ExpenseNotFound].
  Future<String> save({
    required String tripId,
    String? expenseId,
    required String title,
    required int amount,
    required Currency currency,
    required String paidBy,
    required ExpenseCategory category,
    required DateTime spentAt,
    required Map<String, int> shares,
  }) async {
    try {
      return await _client.rpc<String>(
        'save_expense',
        params: {
          'p_trip_id': tripId,
          'p_expense_id': expenseId,
          'p_title': title,
          'p_amount': amount,
          'p_currency': currency.code,
          'p_paid_by': paidBy,
          'p_category': category.code,
          'p_spent_at': toDbDate(spentAt),
          'p_member_ids': shares.keys.toList(),
          'p_shares': shares.values.toList(),
        },
      );
    } on PostgrestException catch (e) {
      // save_expense가 '지출을 찾을 수 없다'(no_data_found)로 거절한 경우
      if (e.code == 'P0002') throw const ExpenseNotFound();
      rethrow;
    }
  }

  Future<void> delete(String expenseId) =>
      _client.from('expenses').delete().eq('id', expenseId);
}
