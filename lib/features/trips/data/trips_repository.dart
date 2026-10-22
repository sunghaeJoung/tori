import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/currency.dart';
import '../../../shared/dates.dart';

/// 홈에서 여행을 나누는 기준.
enum TripPhase {
  /// 오늘이 여행 기간 안
  ongoing,

  /// 출발 전
  upcoming,

  /// 도착일이 지났거나 정산을 마침
  past,
}

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

  /// 정산을 확정했는가. 정산을 마치면 날짜와 상관없이 "지난 여행"이다.
  final bool settled;

  TripPhase phaseOn(DateTime today) {
    final day = _day(today);
    if (settled || day.isAfter(_day(endDate))) return TripPhase.past;
    if (day.isBefore(_day(startDate))) return TripPhase.upcoming;
    return TripPhase.ongoing;
  }

  /// 출발까지 남은 날 수 (내일 출발이면 1).
  int daysUntilStart(DateTime today) =>
      _day(startDate).difference(_day(today)).inDays;

  /// 시간·서머타임과 상관없이 날짜끼리 비교하려고 UTC 자정으로 맞춘다.
  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}

/// 여행 멤버.
class Member {
  const Member({required this.id, required this.name, this.userId});

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    name: json['name'] as String,
    userId: json['user_id'] as String?,
  );

  final String id;
  final String name;

  /// "나는 누구?"에서 이 이름을 고른 사용자. 아직 아무도 안 골랐으면 null.
  final String? userId;
}

/// 여행방에서 쓰는 여행 정보와 멤버(순서대로).
class TripDetail {
  const TripDetail({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.inviteCode,
    required this.settled,
    required this.members,
  });

  factory TripDetail.fromJson(Map<String, dynamic> json) => TripDetail(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    currency: Currency.fromCode(json['local_currency'] as String),
    inviteCode: json['invite_code'] as String,
    settled: json['settled_at'] != null,
    members: [
      for (final m in json['members'] as List)
        Member.fromJson(m as Map<String, dynamic>),
    ],
  );

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final Currency currency;
  final String inviteCode;
  final bool settled;
  final List<Member> members;
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
