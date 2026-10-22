import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/currency.dart';
import '../../../shared/dates.dart';

/// 홈 목록에 보이는 여행 요약.
class TripSummary {
  const TripSummary({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.memberCount,
    required this.settled,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) => TripSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    currency: Currency.fromCode(json['local_currency'] as String),
    memberCount: (json['members'] as List).single['count'] as int,
    settled: json['settled_at'] != null,
  );

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  /// 여행지 통화 (정산은 항상 원화).
  final Currency currency;
  final int memberCount;

  /// 정산을 확정했는가. 홈에서 "지난 여행"으로 간다.
  final bool settled;
}

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
