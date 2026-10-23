import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tori/app/router.dart';

import '../../helpers/fake_app.dart';

void main() {
  testWidgets('초대한 사람·여행 정보와 멤버를 보여준다', (tester) async {
    await pumpApp(tester, location: Routes.join('ABCD2345'));

    expect(find.text('민지님이 초대했어요'), findsOneWidget);
    expect(find.text('상하이 우정여행'), findsOneWidget);
    expect(find.text('2026.11.06 – 11.09 · 위안화 · 3명'), findsOneWidget);
    expect(find.text('참여 중'), findsOneWidget); // 민지
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '내 이름을 골라주세요'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('이름을 고르면 그 멤버로 들어가 여행방으로', (tester) async {
    final invites = FakeInviteRepository();
    await pumpApp(tester, location: Routes.join('ABCD2345'), invites: invites);

    await tester.tap(find.text('지훈'));
    await tester.pump();
    await tapButton<FilledButton>(tester, '지훈으로 참여하기');

    expect(invites.joined.single, ('ABCD2345', 'm3'));
    expect(inTripRoom, findsOneWidget);
  });

  testWidgets('이미 들어온 이름을 고르면 주의 문구', (tester) async {
    await pumpApp(tester, location: Routes.join('ABCD2345'));
    await tester.tap(find.text('민지').last);
    await tester.pump();
    expect(find.textContaining('본인일 때만 골라주세요'), findsOneWidget);
    expect(find.text('민지로 참여하기'), findsOneWidget);
  });

  testWidgets('틀린 코드면 안내하고 홈으로', (tester) async {
    await pumpApp(tester, location: Routes.join('ZZZZZZZZ'));
    expect(find.text('초대 코드를 찾을 수 없어요'), findsOneWidget);

    await tapButton<FilledButton>(tester, '홈으로');
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });

  testWidgets('입장에 실패하면 안내하고 그대로 남는다', (tester) async {
    final invites = FakeInviteRepository();
    await pumpApp(tester, location: Routes.join('ABCD2345'), invites: invites);
    await tester.tap(find.text('수아'));
    await tester.pump();

    invites.failWith = Exception('오프라인');
    await tapButton<FilledButton>(tester, '수아로 참여하기');

    expect(find.textContaining('들어가지 못했어요'), findsOneWidget);
    expect(find.text('나는 누구인가요?'), findsOneWidget);
  });

  testWidgets('코드·멤버가 바뀌어 거절되면 다시 고르라고 안내', (tester) async {
    final invites = FakeInviteRepository();
    await pumpApp(tester, location: Routes.join('ABCD2345'), invites: invites);
    await tester.tap(find.text('수아'));
    await tester.pump();

    invites.claimFailWith = const PostgrestException(
      message: '초대 코드나 멤버가 맞지 않다',
      code: 'P0002',
    );
    await tapButton<FilledButton>(tester, '수아로 참여하기');

    expect(find.text('여행 정보가 바뀌었어요. 이름을 다시 골라주세요'), findsOneWidget);
  });
}
