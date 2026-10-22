// ignore_for_file: avoid_print
// RLS·RPC 점검: 서로 다른 익명 사용자 둘(A, B)로 남의 여행에 접근할 수 없는지 확인한다.
//
// 실행: dart run tool/rls_check.dart [env/dev.json]
//
// 실제 Supabase 프로젝트에 익명 사용자 2명과 "RLS 점검" 여행 1개가 남는다.
// 앱과 같은 공개용(publishable) 키만 쓴다.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final env = jsonDecode(
    File(args.isEmpty ? 'env/dev.json' : args.first).readAsStringSync(),
  ) as Map<String, dynamic>;
  final url = env['SUPABASE_URL'] as String;
  final key = env['SUPABASE_PUBLISHABLE_KEY'] as String;

  final guest = _Client(url, key);
  final a = _Client(url, key);
  final b = _Client(url, key);
  await a.signUpAnonymously();
  await b.signUpAnonymously();
  print('익명 사용자 A, B 로그인\n');

  // A가 여행을 만든다
  final created = await a.rpc('create_trip', {
    'p_name': 'RLS 점검',
    'p_start_date': '2026-11-06',
    'p_end_date': '2026-11-09',
    'p_local_currency': 'CNY',
    'p_my_name': '민지',
    'p_friend_names': ['수아', '지훈', '하린'],
  });
  final id = jsonDecode(created.body) as String;
  final trips = await a.get('trips', 'id=eq.$id&select=invite_code');
  final code = (jsonDecode(trips.body) as List).single['invite_code'] as String;
  final members = jsonDecode(
    (await a.get(
      'members',
      'trip_id=eq.$id&select=id,name,user_id&order=sort_order',
    )).body,
  ) as List;

  check('A는 자기 여행을 본다', trips.statusCode == 200);
  check('초대 코드는 8자리', RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code));
  check(
    'A는 멤버 4명을 순서대로 보고, 첫 멤버(민지)에 연결돼 있다',
    members.length == 4 &&
        members.first['name'] == '민지' &&
        members.first['user_id'] != null &&
        members.skip(1).every((m) => m['user_id'] == null),
  );

  // 로그인 안 한 요청
  check(
    '로그인 안 하면 여행이 안 보인다',
    isEmptyOrDenied(await guest.get('trips', 'id=eq.$id')),
  );
  check(
    '로그인 안 하면 RPC를 못 쓴다',
    !isOk(await guest.rpc('preview_trip', {'p_invite_code': code})),
  );

  // B는 아직 멤버가 아니다
  check('B에게 A의 여행이 안 보인다', isEmptyOrDenied(await b.get('trips', 'id=eq.$id')));
  check(
    'B에게 A의 멤버가 안 보인다',
    isEmptyOrDenied(await b.get('members', 'trip_id=eq.$id')),
  );
  check(
    'B는 A의 여행에 지출을 못 넣는다',
    !isOk(await b.insert('expenses', expense(id, members[1]['id'] as String))),
  );
  check(
    'B는 A의 여행 이름을 못 바꾼다',
    isEmptyOrDenied(await b.patch('trips', 'id=eq.$id', {'name': '해킹'})),
  );
  check(
    'B는 여행을 직접 만들 수 없다 (create_trip RPC로만)',
    !isOk(
      await b.insert('trips', {
        'name': '직접',
        'start_date': '2026-11-06',
        'end_date': '2026-11-09',
        'local_currency': 'KRW',
        'invite_code': 'ABCDEFGH',
      }),
    ),
  );

  // 초대 코드로 미리보기·입장
  final wrong = await b.rpc('preview_trip', {'p_invite_code': 'ZZZZZZZZ'});
  check('틀린 초대 코드는 null', isOk(wrong) && wrong.body == 'null');
  final preview = await b.rpc('preview_trip', {
    'p_invite_code': code.toLowerCase(),
  });
  final previewBody = jsonDecode(preview.body) as Map<String, dynamic>;
  final previewMembers = previewBody['members'] as List;
  check(
    'B는 초대 코드로 이름·기간·통화·멤버 이름만 본다',
    previewBody['name'] == 'RLS 점검' &&
        !previewBody.containsKey('id') &&
        !previewBody.containsKey('invite_code') &&
        previewMembers.length == 4 &&
        previewMembers.first['claimed'] == true &&
        previewMembers.first['is_me'] == false &&
        previewMembers.every((m) => !(m as Map).containsKey('user_id')),
  );
  check(
    '다른 여행의 멤버 id로는 입장 못 한다',
    !isOk(
      await b.rpc('claim_member', {
        'p_invite_code': code,
        'p_member_id': '00000000-0000-0000-0000-000000000000',
      }),
    ),
  );
  final claim = await b.rpc('claim_member', {
    'p_invite_code': code,
    'p_member_id': members[1]['id'],
  });
  check('B가 "수아"를 골라 입장한다', isOk(claim) && jsonDecode(claim.body) == id);
  check(
    '입장한 B는 여행을 본다',
    (jsonDecode((await b.get('trips', 'id=eq.$id')).body) as List).length == 1,
  );

  // DB 제약조건
  check(
    '분배 없이 지출만 넣으면 거부 (분배 합계 = 지출 금액)',
    deniedWith(
      await a.insert('expenses', expense(id, members.first['id'] as String)),
      '분배 합계',
    ),
  );
  check(
    '여행 통화가 아닌 지출은 거부 (CNY 여행에 USD)',
    deniedWith(
      await a.insert(
        'expenses',
        expense(id, members.first['id'] as String, currency: 'USD'),
      ),
      '지출 통화',
    ),
  );
  check(
    '초대 코드는 바꿀 수 없다',
    deniedWith(
      await a.patch('trips', 'id=eq.$id', {'invite_code': 'ABCDEFGH'}),
      'permission denied',
    ),
  );
  check(
    '멤버를 직접 추가할 수 없다',
    deniedWith(
      await a.insert('members', {'trip_id': id, 'name': '몰래', 'sort_order': 9}),
      'permission denied',
    ),
  );

  print('\n${_failed == 0 ? '모두 통과' : '$_failed개 실패'}');
  exit(_failed == 0 ? 0 : 1);
}

Map<String, Object?> expense(
  String tripId,
  String paidBy, {
  String currency = 'CNY',
}) => {
  'trip_id': tripId,
  'title': '훠궈',
  'amount': 68000,
  'currency': currency,
  'paid_by': paidBy,
  'category': 'food',
  'spent_at': '2026-11-06',
};

var _failed = 0;

void check(String name, bool ok) {
  if (!ok) _failed++;
  print('${ok ? '✓' : '✗'} $name');
}

bool isOk(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;

/// 실패했고, 에러에 [reason]이 들어 있다 (다른 이유로 막힌 게 아님을 확인).
bool deniedWith(http.Response r, String reason) {
  final ok = !isOk(r) && r.body.contains(reason);
  if (!ok) print('  응답 ${r.statusCode}: ${r.body}');
  return ok;
}

bool isEmptyOrDenied(http.Response r) => !isOk(r) || r.body.trim() == '[]';

class _Client {
  _Client(this.url, this.key);

  final String url;
  final String key;
  String? _token;

  Map<String, String> get _headers => {
    'apikey': key,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> signUpAnonymously() async {
    final r = await http.post(
      Uri.parse('$url/auth/v1/signup'),
      headers: _headers,
      body: jsonEncode({'data': {}}),
    );
    if (!isOk(r)) throw StateError('익명 로그인 실패 (${r.statusCode}): ${r.body}');
    _token =
        (jsonDecode(r.body) as Map<String, dynamic>)['access_token'] as String;
  }

  Future<http.Response> rpc(String name, Map<String, Object?> params) =>
      _post('rpc/$name', params);

  Future<http.Response> get(String table, String query) =>
      http.get(Uri.parse('$url/rest/v1/$table?$query'), headers: _headers);

  Future<http.Response> insert(String table, Map<String, Object?> row) =>
      _post(table, row);

  Future<http.Response> _post(String path, Map<String, Object?> body) =>
      http.post(
        Uri.parse('$url/rest/v1/$path'),
        headers: _headers,
        body: jsonEncode(body),
      );

  Future<http.Response> patch(
    String table,
    String query,
    Map<String, Object?> row,
  ) => http.patch(
    Uri.parse('$url/rest/v1/$table?$query'),
    headers: _headers,
    body: jsonEncode(row),
  );
}
