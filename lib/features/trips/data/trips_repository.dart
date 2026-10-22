import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/currency.dart';
import '../../../shared/dates.dart';
import 'trip.dart';

class TripsRepository {
  const TripsRepository(this._client);

  final SupabaseClient _client;

  /// 내가 멤버인 여행 (RLS가 걸러준다). 최근에 떠나는 순.
  Future<List<TripSummary>> myTrips() async {
    final rows = await _client
        .from('trips')
        .select(
          'id, name, start_date, end_date, local_currency, settled_at, members(count)',
        )
        .order('start_date', ascending: false);
    return rows.map(TripSummary.fromJson).toList();
  }

  /// 여행 하나와 멤버(순서대로). 내가 멤버가 아니면 RLS 때문에 찾지 못해 에러가 난다.
  Future<TripDetail> tripDetail(String id) async {
    final row = await _client
        .from('trips')
        .select(
          'id, name, start_date, end_date, local_currency, invite_code, settled_at, '
          'members(id, name, user_id, sort_order)',
        )
        .eq('id', id)
        .order('sort_order', referencedTable: 'members')
        .single();
    return TripDetail.fromJson(row);
  }

  /// 여행을 만들고 id를 돌려준다. 멤버 순서는 나 → [friendNames] 순.
  Future<String> createTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required Currency currency,
    required String myName,
    required List<String> friendNames,
  }) {
    return _client.rpc<String>(
      'create_trip',
      params: {
        'p_name': name,
        'p_start_date': toDbDate(startDate),
        'p_end_date': toDbDate(endDate),
        'p_local_currency': currency.code,
        'p_my_name': myName,
        'p_friend_names': friendNames,
      },
    );
  }
}
