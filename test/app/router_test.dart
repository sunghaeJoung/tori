import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';

import '../helpers/fake_app.dart';

void main() {
  group('onboardingRedirect', () {
    Uri u(String s) => Uri.parse(s);

    test('닉네임이 없으면 첫 실행 화면으로, 가려던 주소는 from에 남긴다', () {
      expect(onboardingRedirect(u('/'), null), '/onboarding');
      expect(
        onboardingRedirect(u('/join/ABCD2345'), null),
        '/onboarding?from=%2Fjoin%2FABCD2345',
      );
      expect(onboardingRedirect(u('/onboarding'), null), isNull);
    });

    test('닉네임이 있으면 첫 실행 화면에서 from(또는 홈)으로', () {
      expect(onboardingRedirect(u('/trips/t1'), '민지'), isNull);
      expect(onboardingRedirect(u('/onboarding'), '민지'), '/');
      expect(
        onboardingRedirect(u('/onboarding?from=%2Fjoin%2FABCD2345'), '민지'),
        '/join/ABCD2345',
      );
    });

    test('from이 외부 주소면 무시하고 홈으로', () {
      expect(
        onboardingRedirect(u('/onboarding?from=https://evil.com'), '민지'),
        '/',
      );
      expect(onboardingRedirect(u('/onboarding?from=//evil.com'), '민지'), '/');
    });
  });

  testWidgets('닉네임이 없으면 첫 실행 → 이름 저장 → 원래 링크로', (tester) async {
    await pumpApp(tester, nickname: null, location: Routes.join('ABCD2345'));
    expect(find.text('친구들에게 보일 이름'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  수아 ');
    await tester.pumpAndSettle();
    await tapButton<FilledButton>(tester, '시작하기');

    expect(appBarTitle('나는 누구?'), findsOneWidget);
  });

  testWidgets('이름이 DB 기준 20자를 넘으면 이유를 보여주고 못 누른다', (tester) async {
    await pumpApp(tester, nickname: null);
    await tester.enterText(find.byType(TextField), '👨‍👩‍👧' * 5);
    await tester.pump();
    expect(find.text('이름은 20자까지 쓸 수 있어요'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '시작하기'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('이름이 비어 있으면 시작하기를 못 누른다', (tester) async {
    await pumpApp(tester, nickname: null);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '시작하기'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('여행방 → 지출 추가 → 저장하면 여행방으로 돌아온다', (tester) async {
    await pumpApp(tester, location: Routes.trip('t1'));
    await tapButton<FilledButton>(tester, '지출 추가');
    expect(appBarTitle('지출 추가'), findsOneWidget);

    await tapButton<FilledButton>(tester, '저장');
    expect(appBarTitle('여행방'), findsOneWidget);
  });

  testWidgets('여행방 → 정산 환율 → 취소하면 여행방으로 돌아온다', (tester) async {
    await pumpApp(tester, location: Routes.trip('t1'));
    await tapButton<TextButton>(tester, '정산하기');
    expect(appBarTitle('정산 환율 확인'), findsOneWidget);

    await tapButton<TextButton>(tester, '취소');
    expect(appBarTitle('여행방'), findsOneWidget);
  });

  testWidgets('주소로 바로 들어가기', (tester) async {
    await pumpApp(tester, location: Routes.newTrip);
    expect(find.text('여행 이름을 정해주세요'), findsOneWidget);

    await pumpApp(tester, location: Routes.join('ABCD2345'));
    expect(appBarTitle('나는 누구?'), findsOneWidget);

    await pumpApp(tester, location: Routes.expense('t1', 'e1'));
    expect(appBarTitle('지출 수정'), findsOneWidget);
  });

  testWidgets('없는 주소는 안내 화면 → 홈으로', (tester) async {
    await pumpApp(tester, location: '/nowhere');
    expect(find.text('페이지를 찾을 수 없어요'), findsOneWidget);

    await tapButton<FilledButton>(tester, '홈으로');
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });
}
