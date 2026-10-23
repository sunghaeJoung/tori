import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/currency.dart';

/// 초대 코드로 본 여행 미리보기 (`preview_trip` RPC). 아직 멤버가 아니어도 볼 수 있다.
class TripPreview {
  const TripPreview({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.members,
  });

  factory TripPreview.fromJson(Map<String, dynamic> json) => TripPreview(
    name: json['name'] as String,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    currency: Currency.fromCode(json['local_currency'] as String),
    members: [
      for (final m in json['members'] as List)
        PreviewMember.fromJson(m as Map<String, dynamic>),
    ],
  );

  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final Currency currency;
  final List<PreviewMember> members;

  /// 여행을 만든 사람. 만들 때 첫 멤버로 들어간다.
  String get inviterName => members.first.name;
}

class PreviewMember {
  const PreviewMember({
    required this.id,
    required this.name,
    required this.claimed,
    required this.isMe,
  });

  factory PreviewMember.fromJson(Map<String, dynamic> json) => PreviewMember(
    id: json['id'] as String,
    name: json['name'] as String,
    claimed: json['claimed'] as bool,
    isMe: json['is_me'] as bool,
  );

  final String id;
  final String name;

  /// 누군가 이미 이 이름을 골라 들어왔다.
  final bool claimed;

  /// 이 브라우저(나)가 고른 이름이다.
  final bool isMe;
}

class InviteRepository {
  const InviteRepository(this._client);

  final SupabaseClient _client;

  /// 코드가 틀리면 null.
  Future<TripPreview?> preview(String inviteCode) async {
    final json = await _client.rpc<Map<String, dynamic>?>(
      'preview_trip',
      params: {'p_invite_code': inviteCode},
    );
    return json == null ? null : TripPreview.fromJson(json);
  }

  /// 고른 멤버에 내 계정을 연결하고 여행 id를 돌려준다.
  Future<String> claim(String inviteCode, String memberId) =>
      _client.rpc<String>(
        'claim_member',
        params: {'p_invite_code': inviteCode, 'p_member_id': memberId},
      );
}
