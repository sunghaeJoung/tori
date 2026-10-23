import 'package:decimal/decimal.dart';

import '../../../core/exchange_rate/exchange_rate.dart';
import '../../../core/money/currency.dart';

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
    settled: json['settled_at'] != null && !_isStale(json),
  );

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  /// 여행지 통화 (정산은 항상 원화).
  final Currency currency;
  final int memberCount;

  /// 정산을 확정했고 그 뒤로 지출이 바뀌지 않았는가.
  /// 정산을 마치면 날짜와 상관없이 "지난 여행"이다.
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
    required this.members,
    required this.expensesVersion,
    this.settledRate,
    this.settlementStale = false,
  });

  factory TripDetail.fromJson(Map<String, dynamic> json) => TripDetail(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    currency: Currency.fromCode(json['local_currency'] as String),
    inviteCode: json['invite_code'] as String,
    settledRate: json['settled_at'] == null
        ? null
        : ExchangeRate(
            currency: Currency.fromCode(json['local_currency'] as String),
            // numeric이 JSON 숫자로 온다. double 오차 없이 글자로 바꿔 읽는다
            krwPerUnit: Decimal.parse(json['settle_rate'].toString()),
            date: DateTime.parse(json['settle_rate_date'] as String),
          ),
    settlementStale: _isStale(json),
    expensesVersion: json['expenses_changed_at'] as String,
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
  final List<Member> members;

  /// 확정한 정산 환율과 기준일. 정산 전이면 null. 원화 여행은 1.
  final ExchangeRate? settledRate;

  /// 정산한 뒤 지출이 바뀌었다. 다시 정산해야 한다.
  final bool settlementStale;

  /// 지출이 마지막으로 바뀐 시각(DB 값 그대로). 정산을 확정할 때 이 버전으로 계산했다고 알린다.
  final String expensesVersion;

  /// 정산을 확정했고 그 뒤로 지출이 바뀌지 않았다.
  bool get settled => settledRate != null && !settlementStale;

  /// 멤버 id (멤버 순서). 지출 나누기의 나머지를 앞사람부터 주는 기준.
  List<String> get memberIds => [for (final m in members) m.id];

  Member? memberById(String id) => members.where((m) => m.id == id).firstOrNull;

  /// 이 여행에서 [userId] 사용자가 고른 멤버. 아직 안 골랐거나 로그인 전이면 null.
  Member? memberOf(String? userId) => userId == null
      ? null
      : members.where((m) => m.userId == userId).firstOrNull;
}

/// 정산한 뒤 지출이 바뀌었는가 (trips 행의 settled_at · expenses_changed_at).
bool _isStale(Map<String, dynamic> json) {
  final settledAt = json['settled_at'] as String?;
  if (settledAt == null) return false;
  return DateTime.parse(json['expenses_changed_at'] as String)
      .isAfter(DateTime.parse(settledAt));
}
