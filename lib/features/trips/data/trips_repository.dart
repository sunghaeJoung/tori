import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/currency.dart';
import '../../../shared/dates.dart';
import 'trip.dart';

var _channelCount = 0;

class TripsRepository {
  const TripsRepository(this._client);

  final SupabaseClient _client;

  /// 내가 멤버인 여행 (RLS가 걸러준다). 최근에 떠나는 순.
  Future<List<TripSummary>> myTrips() async {
    final rows = await _client
        .from('trips')
        .select(
          'id, name, start_date, end_date, local_currency, settled_at, '
          'expenses_changed_at, members(count)',
        )
        .order('start_date', ascending: false);
    return rows.map(TripSummary.fromJson).toList();
  }

  /// 여행 하나와 멤버(순서대로). 내가 멤버가 아니면 RLS 때문에 찾지 못해 에러가 난다.
  Future<TripDetail> tripDetail(String id) async {
    final row = await _client
        .from('trips')
        .select(
          'id, name, start_date, end_date, local_currency, invite_code, '
          'settled_at, settle_rate, settle_rate_date, expenses_changed_at, '
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

  /// 여행의 지출이 바뀔 때마다(누가 추가·수정·삭제) [onChange]를 부른다.
  /// 구독이 연결될 때마다(처음, 끊겼다 다시 이어질 때)도 부른다.
  /// 연결되기 전이나 끊긴 사이에 놓친 변경을 다시 불러오도록.
  /// 돌려준 함수를 부르면 구독을 끝내고, 그 뒤로는 [onChange]를 부르지 않는다.
  ///
  /// DB 트리거가 지출이 바뀔 때 이 여행 행의 expenses_changed_at을 갱신하므로
  /// 여행 행 하나만 구독하면 된다.
  void Function() watchChanges(String tripId, void Function() onChange) {
    var active = true;
    void notify() {
      if (active) onChange();
    }

    // 같은 여행방을 금방 다시 열 때, 나가는 중인 앞 채널과 이름이 겹치지 않게 번호를 붙인다
    final channel = _client
        .channel('trip:$tripId:${_channelCount++}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tripId,
          ),
          callback: (_) => notify(),
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) notify();
        });
    return () {
      active = false;
      // 오프라인이면 구독 해제가 실패할 수 있다. 화면은 이미 떠났으니 무시한다
      _client.removeChannel(channel).ignore();
    };
  }
}
