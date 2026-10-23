import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/features/expenses/data/expense.dart';

import '../../helpers/fake_app.dart';

/// 휴대폰 크기로 띄운다 (키패드 위 입력칸이 화면에 들어오게).
Future<void> pumpForm(
  WidgetTester tester, {
  String? expenseId,
  FakeExpensesRepository? expenses,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // 여행방에서 열어야 저장 뒤 돌아갈 곳이 있다
  await pumpApp(tester, location: Routes.trip('t1'), expenses: expenses);
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(
    expenseId == null
        ? Routes.newExpense('t1')
        : Routes.expense('t1', expenseId),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String keys) async {
  for (final key in keys.split(' ')) {
    await tester.tap(
      key == 'del'
          ? find.byIcon(Icons.backspace_outlined)
          : find.bySemanticsLabel(key).last,
    );
    await tester.pump();
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pump();
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(FilledButton, '저장'));

void main() {
  testWidgets('금액·카테고리·나눌 사람을 고르고 저장하면 여행방에 보인다', (tester) async {
    final expenses = FakeExpensesRepository();
    await pumpForm(tester, expenses: expenses);
    expect(appBarTitle('지출 추가'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull, reason: '금액 0');

    await press(tester, '1 2 8 . 5');
    expect(find.text('128.5위안'), findsOneWidget);
    expect(find.text('3명 · 1인당 42.83위안~42.84위안'), findsOneWidget);

    await tapText(tester, '술');
    await tapText(tester, '수아'); // 나눌 사람에서 빼기 (마지막 '수아' 칩)
    expect(find.text('2명 · 1인당 64.25위안'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    final saved = expenses.saved.single;
    expect(saved.expenseId, isNull);
    expect(saved.title, '술'); // 내용을 비워 두면 카테고리 이름
    expect(saved.amount, 12850);
    expect(saved.currency, Currency.cny);
    expect(saved.paidBy, 'm1'); // 기본은 나
    expect(saved.category, ExpenseCategory.drink);
    expect(saved.spentAt, DateTime(2026, 11, 7)); // 오늘
    expect(saved.shares, {'m1': 6425, 'm3': 6425});

    expect(inTripRoom, findsOneWidget);
    expect(find.text('지훈 결제 · 2명'), findsNothing);
    expect(find.text('민지 결제 · 2명'), findsOneWidget);
  });

  testWidgets('원화로 바꾸면 소수가 없어지고 키패드에 00', (tester) async {
    final expenses = FakeExpensesRepository();
    await pumpForm(tester, expenses: expenses);
    await press(tester, '9 6 . 5');

    await tester.tap(find.text('원'));
    await tester.pump();
    expect(find.text('96원'), findsOneWidget);
    expect(find.bySemanticsLabel('00'), findsOneWidget);

    await press(tester, '00');
    await tester.enterText(find.byType(TextField), '항공권');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(expenses.saved.single.currency, Currency.krw);
    expect(expenses.saved.single.amount, 9600);
    expect(expenses.saved.single.title, '항공권');
  });

  testWidgets('나눌 사람을 모두 빼면 저장할 수 없다', (tester) async {
    await pumpForm(tester);
    await press(tester, '1');
    await tapText(tester, '모두 해제');
    expect(find.text('나눌 사람을 골라주세요'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tapText(tester, '모두 선택');
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('저장된 값을 채워 고친다', (tester) async {
    final expenses = FakeExpensesRepository(expenses: sampleExpenses());
    await pumpForm(tester, expenseId: 'e3', expenses: expenses);
    expect(appBarTitle('지출 수정'), findsOneWidget);
    expect(find.text('96위안'), findsOneWidget);
    expect(find.text('맥주'), findsOneWidget);
    expect(find.text('2명 · 1인당 48.00위안'), findsOneWidget);

    await press(tester, 'del 0 0');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    final saved = expenses.saved.single;
    expect(saved.expenseId, 'e3');
    expect(saved.amount, 90000);
    expect(saved.paidBy, 'm3');
    expect(saved.shares, {'m1': 45000, 'm3': 45000});
    expect(inTripRoom, findsOneWidget);
  });

  testWidgets('삭제는 두 번 눌러야 지운다', (tester) async {
    final expenses = FakeExpensesRepository(expenses: sampleExpenses());
    await pumpForm(tester, expenseId: 'e3', expenses: expenses);

    await tester.tap(find.text('삭제'));
    await tester.pump();
    expect(expenses.deleted, isEmpty);

    await tester.tap(find.text('한 번 더 누르면 삭제'));
    await tester.pumpAndSettle();
    expect(expenses.deleted, ['e3']);
    expect(inTripRoom, findsOneWidget);
    expect(find.text('맥주'), findsNothing);
  });

  testWidgets('없는 지출이면 안내', (tester) async {
    await pumpForm(tester, expenseId: 'gone');
    expect(find.text('지출을 찾을 수 없어요'), findsOneWidget);

    await tapButton<FilledButton>(tester, '여행방으로');
    expect(inTripRoom, findsOneWidget);
  });

  testWidgets('저장에 실패하면 안내하고 그 화면에 남는다', (tester) async {
    final expenses = FakeExpensesRepository(expenses: sampleExpenses());
    await pumpForm(tester, expenseId: 'e3', expenses: expenses);

    expenses.failWith = const PostgrestException(
      message: '지출을 찾을 수 없다',
      code: 'P0002',
    );
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('다른 친구가 이 지출을 지웠어요'), findsOneWidget);
    expect(appBarTitle('지출 수정'), findsOneWidget);

    expenses.failWith = Exception('오프라인');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
  });
}
