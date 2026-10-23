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
  /// 수정하려던 지출이 이미 지워졌으면 code `P0002` [PostgrestException].
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
  }) {
    return _client.rpc<String>(
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
  }

  Future<void> delete(String expenseId) =>
      _client.from('expenses').delete().eq('id', expenseId);

  /// 여행의 지출이 바뀔 때마다(누가 추가·수정·삭제) [onChange]를 부른다.
  /// 연결이 끊겼다가 다시 이어져도 부른다 (그사이 놓친 변경을 다시 불러오도록).
  /// 돌려준 함수를 부르면 구독을 끝낸다.
  ///
  /// DB 트리거가 지출이 바뀔 때 trips 행의 expenses_changed_at을 갱신하므로
  /// 여행 행 하나만 구독한다.
  void Function() watchTrip(String tripId, void Function() onChange) {
    var subscribedOnce = false;
    final channel = _client
        .channel('trip:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tripId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe((status, _) {
          if (status != RealtimeSubscribeStatus.subscribed) return;
          if (subscribedOnce) onChange();
          subscribedOnce = true;
        });
    return () => _client.removeChannel(channel);
  }
}
