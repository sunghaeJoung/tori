import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';

import '../../helpers/fake_app.dart';

FilledButton button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

/// 비어 있는 날짜 칸 중 첫 번째(출발이 먼저)를 눌러 달력에서 [day]일을 고른다.
Future<void> pickDay(WidgetTester tester, int day) async {
  await tester.tap(find.text('날짜 선택').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
}

Future<void> addFriend(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField), name);
  await tapButton<FilledButton>(tester, '추가');
}

/// 여행 만들기 1~3단계를 채우고 4단계(멤버) 화면에 선다.
Future<void> fillUntilMembers(
  WidgetTester tester, {
  required String name,
  required int startDay,
  required int endDay,
  required String currencyLabel,
}) async {
  await tester.enterText(find.byType(TextField), name);
  await tester.pump();
  await tapButton<FilledButton>(tester, '다음');
  await pickDay(tester, startDay);
  await pickDay(tester, endDay);
  await tapButton<FilledButton>(tester, '다음');
  await tester.tap(find.text(currencyLabel));
  await tester.pump();
  await tapButton<FilledButton>(tester, '다음');
}

void main() {
  testWidgets('단계마다 입력해야 다음으로 갈 수 있다', (tester) async {
    await pumpApp(tester, location: Routes.newTrip);

    expect(find.text('1 / 4'), findsOneWidget);
    expect(button(tester, '다음').onPressed, isNull);
    await tester.enterText(find.byType(TextField), '상하이');
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');

    expect(find.text('언제 떠나나요?'), findsOneWidget);
    expect(button(tester, '다음').onPressed, isNull);
    await pickDay(tester, 20);
    await pickDay(tester, 23);
    await tapButton<FilledButton>(tester, '다음');

    expect(button(tester, '다음').onPressed, isNull);
    await tester.tap(find.text('위안화'));
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');

    expect(find.text('민지 (나)'), findsOneWidget);
    expect(button(tester, '여행 만들기').onPressed, isNull);
  });

  testWidgets('여행을 만들면 DB에 저장하고 초대 화면으로', (tester) async {
    final repo = FakeTripsRepository();
    await pumpApp(tester, location: Routes.newTrip, repository: repo);
    await fillUntilMembers(
      tester,
      name: ' 상하이 우정여행 ',
      startDay: 20,
      endDay: 23,
      currencyLabel: '위안화',
    );

    for (final name in ['수아', '지훈', '하린']) {
      await addFriend(tester, name);
    }
    await addFriend(tester, '수아');
    expect(find.text('이미 있는 이름이에요'), findsOneWidget);

    await tester.tap(find.byTooltip('지훈 빼기'));
    await tester.pump();
    await tapButton<FilledButton>(tester, '여행 만들기');

    final created = repo.created.single;
    expect(created.name, '상하이 우정여행');
    expect(created.startDate.day, 20);
    expect(created.endDate.day, 23);
    expect(created.currency, Currency.cny);
    expect(created.myName, '민지');
    expect(created.friendNames, ['수아', '하린']);
    expect(appBarTitle('초대하기'), findsOneWidget);
  });

  testWidgets('뒤로를 누르면 이전 단계, 첫 단계에서는 홈으로', (tester) async {
    await pumpApp(tester);
    await tapButton<FilledButton>(tester, '새 여행 만들기');
    await tester.enterText(find.byType(TextField), '부산');
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');
    expect(find.text('2 / 4'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('부산'), findsOneWidget); // 입력한 이름은 남아 있다

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });

  testWidgets('저장에 실패하면 안내하고 그 화면에 남는다', (tester) async {
    final repo = FakeTripsRepository();
    await pumpApp(tester, location: Routes.newTrip, repository: repo);
    await fillUntilMembers(
      tester,
      name: '도쿄',
      startDay: 20,
      endDay: 21,
      currencyLabel: '엔화',
    );
    await addFriend(tester, '수아');

    repo.failWith = Exception('오프라인');
    await tapButton<FilledButton>(tester, '여행 만들기');

    expect(find.textContaining('여행을 만들지 못했어요'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
  });
}
