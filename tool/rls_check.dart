// ignore_for_file: avoid_print
// RLS·RPC 점검: 서로 다른 익명 사용자(A, B, C)로 남의 여행에 접근할 수 없는지 확인한다.
//
// 실행: dart run tool/rls_check.dart [env/dev.json]
//
// 실제 Supabase 프로젝트에 익명 사용자 3명과 여행 2개("RLS 점검", "C 여행")가 남는다.
// 앱과 같은 공개용(publishable) 키만 쓴다.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tori/core/money/split.dart';

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
  final members = await a.rows(
    'members',
    'trip_id=eq.$id&select=id,name,user_id&order=sort_order',
  );

  check('A는 자기 여행을 본다', trips.statusCode == 200);
  final home = await a.rows(
    'trips',
    'select=id,name,start_date,end_date,local_currency,settled_at,members(count)',
  );
  check(
    '홈 목록 조회: 내 여행 1개, 멤버 수 4',
    home.length == 1 && (home.single['members'] as List).single['count'] == 4,
  );
  final nickname = await a.updateUser({'nickname': '민지'});
  check(
    '익명 계정에 닉네임을 저장한다 (user_metadata)',
    isOk(nickname) &&
        (jsonDecode(nickname.body)['user_metadata'] as Map)['nickname'] == '민지',
  );
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
    deniedWith(
      await b.rpc('save_expense', expense(id, members, paidBy: 1)),
      '여행 멤버가 아니다',
    ),
  );
  check(
    'B는 A의 여행 이름을 못 바꾼다',
    isEmptyOrDenied(await b.patch('trips', 'id=eq.$id', {'name': '해킹'})),
  );
  check(
    'B는 여행을 직접 만들 수 없다 (create_trip RPC로만)',
    deniedWith(
      await b.insert('trips', {
        'name': '직접',
        'start_date': '2026-11-06',
        'end_date': '2026-11-09',
        'local_currency': 'KRW',
        'invite_code': 'ABCDEFGH',
      }),
      'permission denied',
    ),
  );
  check(
    'B에게 A의 분배·송금이 안 보인다',
    isEmptyOrDenied(await b.get('expense_splits', 'select=*')) &&
        isEmptyOrDenied(await b.get('settlements', 'trip_id=eq.$id')),
  );
  check(
    '분배는 부담액만, 송금은 완료 체크만 고칠 수 있다',
    deniedWith(
          await a.patch('expense_splits', 'member_id=eq.${members[0]['id']}', {
            'expense_id': '00000000-0000-0000-0000-000000000000',
          }),
          'permission denied',
        ) &&
        deniedWith(
          await a.patch('settlements', 'trip_id=eq.$id', {'amount_krw': 10}),
          'permission denied',
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
  check('입장한 B는 여행을 본다', (await b.rows('trips', 'id=eq.$id')).length == 1);
  final detail = await b.rows(
    'trips',
    'id=eq.$id&select=id,name,invite_code,members(id,name,user_id,sort_order)'
        '&members.order=sort_order',
  );
  final detailMembers = detail.single['members'] as List;
  check(
    '여행방 조회: 멤버가 순서대로, 수아에 B가 연결돼 있다',
    detailMembers.map((m) => m['name']).join(',') == '민지,수아,지훈,하린' &&
        detailMembers[1]['user_id'] != null,
  );
  final again = jsonDecode(
    (await b.rpc('preview_trip', {'p_invite_code': code})).body,
  ) as Map<String, dynamic>;
  check(
    '다시 열면 B가 고른 이름이 "나"로 표시된다',
    (again['members'] as List)[1]['is_me'] == true,
  );

  // 지출 (save_expense RPC)
  final changedBefore = await _expensesChangedAt(a, id);
  final saved = await a.rpc('save_expense', expense(id, members));
  final expenseId = jsonDecode(saved.body) as String;
  final rows = await b.rows(
    'expenses',
    'id=eq.$expenseId&select=amount,expense_splits(member_id,share_amount)',
  );
  final shares = [
    for (final s in rows.single['expense_splits'] as List) s['share_amount'],
  ]..sort();
  check(
    'A가 지출을 저장하고 B(멤버)가 분배까지 본다 (680.00위안 ÷ 4)',
    isOk(saved) && shares.join(',') == '17000,17000,17000,17000',
  );
  check(
    '지출이 바뀌면 여행의 expenses_changed_at이 갱신된다 (실시간 알림용)',
    (await _expensesChangedAt(a, id)).isAfter(changedBefore),
  );
  final edited = await b.rpc(
    'save_expense',
    expense(id, members, expenseId: expenseId, amount: 5850, split: [0, 1]),
  );
  final editedSplits = await a.rows(
    'expense_splits',
    'expense_id=eq.$expenseId&select=*',
  );
  check(
    'B가 지출을 고치면 분배도 통째로 바뀐다 (2명)',
    isOk(edited) && editedSplits.length == 2,
  );
  check(
    '지출·분배를 직접 넣거나 고칠 수 없다 (RPC로만)',
    deniedWith(
          await a.insert('expenses', {
            'trip_id': id,
            'title': '직접',
            'amount': 100,
            'currency': 'CNY',
            'paid_by': members.first['id'],
            'category': 'food',
            'spent_at': '2026-11-06',
          }),
          'permission denied',
        ) &&
        deniedWith(
          await a.insert('expense_splits', {
            'expense_id': expenseId,
            'member_id': members.first['id'],
            'share_amount': 1,
          }),
          'permission denied',
        ) &&
        deniedWith(
          await a.patch('expenses', 'id=eq.$expenseId', {'amount': 1}),
          'permission denied',
        ),
  );

  // C: 아무 여행에도 들어가지 않은 사용자. 자기 여행을 만들어 둔다
  final c = _Client(url, key);
  await c.signUpAnonymously();
  final cTrip = jsonDecode(
    (await c.rpc('create_trip', {
      'p_name': 'C 여행',
      'p_start_date': '2026-11-06',
      'p_end_date': '2026-11-09',
      'p_local_currency': 'CNY',
      'p_my_name': '외부인',
    })).body,
  ) as String;
  final cMembers = await c.rows('members', 'trip_id=eq.$cTrip&select=id');
  check(
    'C에게 A 여행의 지출·분배가 안 보인다',
    isEmptyOrDenied(await c.get('expenses', 'trip_id=eq.$id')) &&
        isEmptyOrDenied(
          await c.get('expense_splits', 'expense_id=eq.$expenseId'),
        ),
  );
  check(
    'C는 자기 여행 id를 내세워 A의 지출을 고칠 수 없다',
    deniedWith(
      await c.rpc(
        'save_expense',
        expense(cTrip, cMembers, expenseId: expenseId),
      ),
      '지출을 찾을 수 없다',
    ),
  );
  check(
    'C는 A의 지출을 지울 수 없다',
    isEmptyOrDenied(await c.delete('expenses', 'id=eq.$expenseId')) &&
        (await a.rows('expenses', 'id=eq.$expenseId')).length == 1,
  );

  // DB 제약조건
  check(
    '분배 합계가 금액과 다르면 거부',
    deniedWith(
      await a.rpc(
        'save_expense',
        expense(id, members)..['p_shares'] = [17000, 17000, 17000, 16999],
      ),
      '분배 합계',
    ),
  );
  check(
    '나눌 사람이 없으면 거부',
    deniedWith(
      await a.rpc('save_expense', expense(id, members, split: [])),
      '나눌 사람',
    ),
  );
  check(
    '여행 통화가 아닌 지출은 거부 (CNY 여행에 USD)',
    deniedWith(
      await a.rpc('save_expense', expense(id, members, currency: 'USD')),
      '지출 통화',
    ),
  );
  check(
    '다른 여행의 멤버가 내거나 나눠 낼 수 없다',
    !isOk(
          await a.rpc(
            'save_expense',
            expense(id, members)..['p_paid_by'] = cMembers.first['id'],
          ),
        ) &&
        deniedWith(
          await a.rpc(
            'save_expense',
            expense(id, members)
              ..['p_member_ids'] = [cMembers.first['id']]
              ..['p_shares'] = [68000],
          ),
          '다른 여행의 멤버',
        ),
  );
  final deleted = await a.delete('expenses', 'id=eq.$expenseId');
  check(
    'A가 지출을 지우면 분배도 함께 지워진다',
    isOk(deleted) &&
        isEmptyOrDenied(
          await a.get('expense_splits', 'expense_id=eq.$expenseId'),
        ),
  );

  // 정산 (confirm_settlement RPC)
  await a.rpc('save_expense', expense(id, members)); // 민지가 680.00위안, 4명
  // 1위안 = 192.35원: 수아·지훈·하린이 민지에게 32,700원씩 (170.00위안 × 192.35 = 32,699.5)
  Map<String, Object?> settlement(String tripId, {int amount = 32700}) => {
    'p_trip_id': tripId,
    'p_rate': 192.35,
    'p_rate_date': '2026-11-09',
    'p_from': [for (final m in members.skip(1)) m['id']],
    'p_to': [for (final _ in members.skip(1)) members.first['id']],
    'p_amounts': [for (final _ in members.skip(1)) amount],
  };
  check(
    'C는 A의 여행을 정산할 수 없다',
    deniedWith(await c.rpc('confirm_settlement', settlement(id)), '여행 멤버가 아니다'),
  );
  check(
    '송금액은 10원 단위만',
    !isOk(await a.rpc('confirm_settlement', settlement(id, amount: 32699))),
  );
  check(
    '정산 열(환율·확정 시각)은 직접 못 바꾼다',
    deniedWith(
      await a.patch('trips', 'id=eq.$id', {
        'settled_at': '2026-11-09T00:00:00Z',
      }),
      'permission denied',
    ),
  );
  final confirmed = await b.rpc('confirm_settlement', settlement(id));
  final settled = (await a.rows(
    'trips',
    'id=eq.$id&select=settle_rate,settled_at,expenses_changed_at,changed_at',
  )).single;
  final transfers = await a.rows('settlements', 'trip_id=eq.$id&select=*');
  check(
    'B(멤버)가 정산을 확정하면 환율·송금 3건이 저장된다',
    isOk(confirmed) &&
        settled['settle_rate'] == 192.35 &&
        settled['settled_at'] != null &&
        transfers.length == 3,
  );
  check(
    'C에게 A 여행의 송금이 안 보이고 완료 체크도 못 한다',
    isEmptyOrDenied(await c.get('settlements', 'trip_id=eq.$id')) &&
        isEmptyOrDenied(
          await c.patch('settlements', 'trip_id=eq.$id', {
            'done_at': '2026-11-09T00:00:00Z',
          }),
        ),
  );
  final done = await b.patch('settlements', 'id=eq.${transfers.first['id']}', {
    'done_at': DateTime.now().toUtc().toIso8601String(),
  });
  final afterDone = (await a.rows(
    'trips',
    'id=eq.$id&select=changed_at',
  )).single;
  check(
    '송금 완료를 체크하면 여행의 changed_at이 갱신된다 (실시간 알림용)',
    isOk(done) &&
        DateTime.parse(afterDone['changed_at'] as String)
            .isAfter(DateTime.parse(settled['changed_at'] as String)),
  );
  await a.rpc('save_expense', expense(id, members, amount: 100));
  final stale = (await a.rows(
    'trips',
    'id=eq.$id&select=settled_at,expenses_changed_at',
  )).single;
  check(
    '정산 뒤 지출이 바뀌면 expenses_changed_at > settled_at (다시 정산)',
    DateTime.parse(stale['expenses_changed_at'] as String)
        .isAfter(DateTime.parse(stale['settled_at'] as String)),
  );
  check(
    '정산을 다시 하면 송금 목록을 새로 만든다',
    isOk(await a.rpc('confirm_settlement', settlement(id))) &&
        (await a.rows('settlements', 'trip_id=eq.$id&select=id')).length == 3 &&
        (await a.rows(
          'settlements',
          'trip_id=eq.$id&done_at=not.is.null',
        )).isEmpty,
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

/// save_expense RPC 인자. 기본은 680.00위안, 첫 멤버가 내고 전원이 균등하게 나눈다.
/// [split]은 나눌 멤버의 순번.
Map<String, Object?> expense(
  String tripId,
  List<dynamic> members, {
  String? expenseId,
  int paidBy = 0,
  int amount = 68000,
  String currency = 'CNY',
  List<int>? split,
}) {
  final ids = [
    for (final i in split ?? List.generate(members.length, (i) => i))
      members[i]['id'],
  ];
  return {
    'p_trip_id': tripId,
    'p_expense_id': expenseId,
    'p_title': '훠궈',
    'p_amount': amount,
    'p_currency': currency,
    'p_paid_by': members[paidBy]['id'],
    'p_category': 'food',
    'p_spent_at': '2026-11-06',
    'p_member_ids': ids,
    'p_shares': ids.isEmpty
        ? <int>[]
        : splitEvenly(amount, ids.cast<String>()).values.toList(),
  };
}

Future<DateTime> _expensesChangedAt(_Client client, String tripId) async {
  final rows = await client.rows(
    'trips',
    'id=eq.$tripId&select=expenses_changed_at',
  );
  return DateTime.parse(rows.single['expenses_changed_at'] as String);
}

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

  Future<http.Response> updateUser(Map<String, Object?> data) => http.put(
    Uri.parse('$url/auth/v1/user'),
    headers: _headers,
    body: jsonEncode({'data': data}),
  );

  Future<http.Response> rpc(String name, Map<String, Object?> params) =>
      _post('rpc/$name', params);

  /// 조회해서 행 목록으로. 막히면 예외.
  Future<List<dynamic>> rows(String table, String query) async {
    final r = await get(table, query);
    if (!isOk(r)) throw StateError('조회 실패 (${r.statusCode}): ${r.body}');
    return jsonDecode(r.body) as List;
  }

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

  Future<http.Response> delete(String table, String query) =>
      http.delete(Uri.parse('$url/rest/v1/$table?$query'), headers: _headers);

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
