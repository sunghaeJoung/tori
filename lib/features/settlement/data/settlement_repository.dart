import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/exchange_rate/frankfurter_api.dart';
import '../../../core/money/settlement.dart';
import '../../../shared/dates.dart';
import 'settlement.dart';

class SettlementRepository {
  const SettlementRepository(this._client);

  final SupabaseClient _client;

  /// 확정한 송금 목록. 큰 금액부터.
  Future<List<SettlementTransfer>> transfers(String tripId) async {
    final rows = await _client
        .from('settlements')
        .select('id, from_member, to_member, amount_krw, done_at')
        .eq('trip_id', tripId)
        .order('amount_krw', ascending: false)
        .order('id');
    return rows.map(SettlementTransfer.fromJson).toList();
  }

  /// 환율과 송금 목록으로 정산을 확정한다. 이미 정산했으면 송금 목록을 새로 만든다.
  Future<void> confirm(
    String tripId,
    ExchangeRate rate,
    List<Transfer> transfers,
  ) {
    return _client.rpc<void>(
      'confirm_settlement',
      params: {
        'p_trip_id': tripId,
        // numeric으로 정확히 넘기려고 글자로 보낸다
        'p_rate': rate.krwPerUnit.toString(),
        'p_rate_date': toDbDate(rate.date),
        'p_from': [for (final t in transfers) t.from],
        'p_to': [for (final t in transfers) t.to],
        'p_amounts': [for (final t in transfers) t.amountKrw],
      },
    );
  }

  Future<void> setDone(String transferId, {required bool done}) => _client
      .from('settlements')
      .update({
        'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
      })
      .eq('id', transferId);
}
