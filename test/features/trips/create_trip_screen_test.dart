import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';

import '../../helpers/fake_app.dart';

FilledButton nextButton(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

/// [field] 중 첫 번째(출발이 먼저)를 눌러 달력에서 [day]일을 고르고 확인을 누른다.
Future<void> pickDay(WidgetTester tester, String field, int day) async {
  await tester.tap(find.text(field).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('이름 → 날짜 → 통화 → 멤버를 거쳐 여행을 만들고 초대 화면으로', (tester) async {
    final repo = FakeTripsRepository();
    await pumpApp(tester, location: Routes.newTrip, repository: repo);

    // 1. 이름
    expect(find.text('1 / 4'), findsOneWidget);
    expect(nextButton(tester, '다음').onPressed, isNull);
    await tester.enterText(find.byType(TextField), ' 상하이 우정여행 ');
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');

    // 2. 날짜 (도착을 출발보다 앞으로 고를 수 없다)
    expect(find.text('언제 떠나나요?'), findsOneWidget);
    expect(nextButton(tester, '다음').onPressed, isNull);
    await pickDay(tester, '날짜 선택', 20);
    await pickDay(tester, '날짜 선택', 23);
    await tapButton<FilledButton>(tester, '다음');

    // 3. 통화
    expect(nextButton(tester, '다음').onPressed, isNull);
    await tester.tap(find.text('위안화'));
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');

    // 4. 멤버: 나는 처음부터 있고, 친구를 한 명 이상 넣어야 한다
    expect(find.text('민지 (나)'), findsOneWidget);
    expect(nextButton(tester, '여행 만들기').onPressed, isNull);
    for (final name in ['수아', '지훈', '하린']) {
      await tester.enterText(find.byType(TextField), name);
      await tapButton<FilledButton>(tester, '추가');
    }
    await tester.enterText(find.byType(TextField), '수아');
    await tapButton<FilledButton>(tester, '추가');
    expect(find.text('이미 있는 이름이에요'), findsOneWidget);

    await tester.tap(find.byTooltip('지훈 빼기'));
    await tester.pump();
    await tapButton<FilledButton>(tester, '여행 만들기');

    final created = repo.created.single;
    expect(created['name'], '상하이 우정여행');
    expect((created['startDate']! as DateTime).day, 20);
    expect((created['endDate']! as DateTime).day, 23);
    expect(created['currency'], Currency.cny);
    expect(created['myName'], '민지');
    expect(created['friendNames'], ['수아', '하린']);
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
    final repo = FakeTripsRepository()..failWith = Exception('오프라인');
    await pumpApp(tester, location: Routes.newTrip, repository: repo);

    await tester.enterText(find.byType(TextField), '도쿄');
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');
    await pickDay(tester, '날짜 선택', 20);
    await pickDay(tester, '날짜 선택', 21);
    await tapButton<FilledButton>(tester, '다음');
    await tester.tap(find.text('엔화'));
    await tester.pump();
    await tapButton<FilledButton>(tester, '다음');
    await tester.enterText(find.byType(TextField), '수아');
    await tapButton<FilledButton>(tester, '추가');
    await tapButton<FilledButton>(tester, '여행 만들기');

    expect(find.textContaining('여행을 만들지 못했어요'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
  });
}
