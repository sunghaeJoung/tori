import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/features/expenses/data/expense.dart';

import '../../helpers/fake_app.dart';

void main() {
  testWidgets('지출이 없으면 안내', (tester) async {
    await pumpApp(tester, location: Routes.trip('t1'));
    expect(inTripRoom, findsOneWidget);
    expect(find.text('아직 지출이 없어요'), findsOneWidget);
    expect(find.text('0.00위안'), findsOneWidget); // 총 지출
  });

  testWidgets('총 지출·내 잔액과 날짜별 지출', (tester) async {
    usePhoneSize(tester);
    await pumpApp(
      tester,
      location: Routes.trip('t1'),
      expenses: FakeExpensesRepository(expenses: sampleExpenses()),
    );

    // 776.00위안 × 192.35 + 900,000원 = 1,049,263.6원
    expect(find.text('총 지출 (오늘 환율 기준)'), findsOneWidget);
    expect(find.text('약 1,049,260원'), findsOneWidget);
    expect(find.text('776.00위안 + 900,000원'), findsOneWidget);
    // 민지: +405.33위안 × 192.35 - 300,000원 = -222,034.77원
    expect(find.text('-222,030원'), findsOneWidget);
    expect(find.text(' · 줄 돈'), findsOneWidget);

    expect(find.text('11월 7일 (토)'), findsOneWidget);
    expect(find.text('11월 6일 (금)'), findsOneWidget);
    expect(find.text('지훈 결제 · 2명'), findsOneWidget);
    expect(find.text('내 몫 48.00위안'), findsOneWidget);
    expect(find.text('수아 결제 · 3명'), findsOneWidget);
    expect(find.text('내 몫 300,000원'), findsOneWidget);
  });

  testWidgets('환율을 못 불러오면 통화별로 보여준다', (tester) async {
    usePhoneSize(tester);
    await pumpApp(
      tester,
      location: Routes.trip('t1'),
      expenses: FakeExpensesRepository(expenses: sampleExpenses()),
      rateError: Exception('오프라인'),
    );
    expect(find.text('총 지출'), findsOneWidget);
    expect(find.text('776.00위안 + 900,000원'), findsOneWidget);
    expect(find.text('+405.33위안'), findsOneWidget);
    expect(find.text('-300,000원'), findsOneWidget);
  });

  testWidgets('내가 안 나눈 지출은 "참여 안 함"', (tester) async {
    final expenses = FakeExpensesRepository(
      expenses: [
        Expense(
          id: 'e9',
          title: '택시',
          amount: 5850,
          currency: Currency.cny,
          paidBy: 'm2',
          category: ExpenseCategory.transport,
          spentAt: DateTime(2026, 11, 8),
          shares: const {'m2': 2925, 'm3': 2925},
        ),
      ],
    );
    await pumpApp(tester, location: Routes.trip('t1'), expenses: expenses);
    expect(find.text('참여 안 함'), findsOneWidget);
  });

  testWidgets('친구가 바꾼 지출이 실시간으로 반영된다', (tester) async {
    final trips = FakeTripsRepository();
    final expenses = FakeExpensesRepository();
    await pumpApp(
      tester,
      location: Routes.trip('t1'),
      repository: trips,
      expenses: expenses,
    );
    expect(trips.watching, 1);

    expenses.expenses.add(sampleExpenses().first);
    trips.emitChange();
    await tester.pumpAndSettle();
    expect(find.text('맥주'), findsOneWidget);

    // 여행방을 떠나면 구독을 끝낸다
    await tester.tap(find.byTooltip('홈으로'));
    await tester.pumpAndSettle();
    expect(trips.watching, 0);
  });

  testWidgets('지출을 누르면 수정 화면', (tester) async {
    await pumpApp(
      tester,
      location: Routes.trip('t1'),
      expenses: FakeExpensesRepository(expenses: sampleExpenses()),
    );
    await tester.tap(find.text('맥주'));
    await tester.pumpAndSettle();
    expect(appBarTitle('지출 수정'), findsOneWidget);
  });

  testWidgets('지출을 못 불러오면 다시 시도', (tester) async {
    final expenses = FakeExpensesRepository(expenses: sampleExpenses())
      ..failWith = Exception('오프라인');
    await pumpApp(tester, location: Routes.trip('t1'), expenses: expenses);
    expect(find.text('지출을 불러오지 못했어요'), findsOneWidget);

    expenses.failWith = null;
    await tapButton<FilledButton>(tester, '다시 시도');
    expect(find.text('맥주'), findsOneWidget);
  });
}
