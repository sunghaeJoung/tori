import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/exchange_rate/frankfurter_api.dart';
import 'package:tori/core/money/currency.dart';

import '../../helpers/fake_app.dart';

void main() {
  Future<({FakeTripsRepository trips, FakeSettlementRepository settlements})>
  openTrip(
    WidgetTester tester, {
    TripTab tab = TripTab.settle,
    Object? rateError,
  }) async {
    usePhoneSize(tester);
    final trips = FakeTripsRepository();
    final settlements = FakeSettlementRepository(trips);
    await pumpApp(
      tester,
      location: Routes.trip('t1', tab: tab),
      repository: trips,
      expenses: FakeExpensesRepository(expenses: sampleExpenses()),
      settlements: settlements,
      rateError: rateError,
    );
    return (trips: trips, settlements: settlements);
  }

  testWidgets('잔액 탭: 오늘 환율로 원화 환산, 내 행 표시', (tester) async {
    await openTrip(tester, tab: TripTab.balances);
    expect(
      find.text('오늘 환율(1위안 = 192.35원)로 계산한 참고 금액이에요. 정확한 금액은 정산할 때 확정돼요.'),
      findsOneWidget,
    );
    expect(find.text('민지 (나)'), findsOneWidget);
    expect(find.text('+556,400원'), findsOneWidget); // 수아
    expect(find.text('-334,370원'), findsOneWidget); // 지훈
    expect(find.text('-226.67위안 · +600,000원'), findsOneWidget); // 수아 통화별
    expect(find.text('받을 돈'), findsOneWidget);
  });

  testWidgets('정산 시작 → 오늘 환율 확인 → 확정하면 송금 목록', (tester) async {
    final fakes = await openTrip(tester);
    expect(find.text('여행이 끝났나요?'), findsOneWidget);

    await tapButton<FilledButton>(tester, '정산 시작하기');
    expect(appBarTitle('정산 환율 확인'), findsOneWidget);
    expect(find.text('1위안 = 192.35원'), findsOneWidget);
    expect(find.text('2026년 11월 9일 기준 · 유럽중앙은행 고시'), findsOneWidget);
    expect(find.text('약 1,049,260원'), findsWidgets);

    await tapButton<FilledButton>(tester, '이 환율로 정산하기');
    final (rate, plan) = fakes.settlements.confirmed.single;
    expect(rate.krwPerUnit, Decimal.parse('192.35'));
    expect(plan, [
      (from: 'm3', to: 'm2', amountKrw: 334370),
      (from: 'm1', to: 'm2', amountKrw: 222030),
    ]);

    // 여행방 정산 탭으로 돌아온다
    expect(inTripRoom, findsOneWidget);
    expect(find.text('송금 2건이면 끝나요'), findsOneWidget);
    expect(find.text('0 / 2 완료'), findsOneWidget);
    expect(find.text('내가 보낼 돈'), findsOneWidget);
    expect(find.text('222,030원'), findsOneWidget);
    expect(find.text('≈ 1,154.30위안'), findsOneWidget);
    expect(
      find.text('1위안 = 192.35원 (2026년 11월 9일 기준)\n송금 금액은 10원 단위로 반올림했어요'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '송금 완료').first);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 완료'), findsOneWidget);
    expect(find.text('송금 완료됨'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '송금 완료'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('정산 끝내기'));
    await tapButton<FilledButton>(tester, '정산 끝내기');
    expect(find.text('정산 끝!'), findsOneWidget);
    expect(find.textContaining('3명이 함께 쓴'), findsOneWidget);
  });

  testWidgets('환율을 못 불러오면 직접 입력해서 정산', (tester) async {
    final fakes = await openTrip(tester, rateError: Exception('막힘'));
    await tapButton<FilledButton>(tester, '정산 시작하기');
    expect(find.text('환율을 불러오지 못했어요'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, '이 환율로 정산하기');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tapButton<TextButton>(tester, '환율 직접 입력하기');
    await tester.enterText(find.byType(TextField), '190');
    await tester.pump();
    await tapButton<FilledButton>(tester, '이 환율로 정산하기');

    final (rate, _) = fakes.settlements.confirmed.single;
    expect(rate.krwPerUnit, Decimal.parse('190'));
    expect(rate.date, DateTime(2026, 11, 7)); // 오늘
  });

  testWidgets('정산 뒤 지출이 바뀌면 다시 정산하라고 안내', (tester) async {
    usePhoneSize(tester);
    final trips = FakeTripsRepository()
      ..settledRate = sampleRate
      ..settlementStale = true;
    await pumpApp(
      tester,
      location: Routes.trip('t1', tab: TripTab.settle),
      repository: trips,
      expenses: FakeExpensesRepository(expenses: sampleExpenses()),
    );
    expect(find.text('지출이 바뀌었어요. 정산을 다시 해주세요.'), findsOneWidget);
    expect(find.text('정산 시작하기'), findsOneWidget);
  });

  testWidgets('지출이 없으면 정산을 시작할 수 없다', (tester) async {
    await pumpApp(tester, location: Routes.trip('t1', tab: TripTab.settle));
    final button = find.widgetWithText(FilledButton, '지출을 먼저 추가해주세요');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('원화 여행은 환율 없이 정산', (tester) async {
    usePhoneSize(tester);
    final trips = FakeTripsRepository()..currency = Currency.krw;
    final settlements = FakeSettlementRepository(trips);
    await pumpApp(
      tester,
      location: Routes.rate('t1'),
      repository: trips,
      settlements: settlements,
      expenses: FakeExpensesRepository(
        expenses: [sampleExpenses().last], // 항공권 900,000원, 수아 결제
      ),
    );
    expect(find.text('환율 없이 바로 정산해요'), findsOneWidget);
    expect(find.text('환율 직접 입력하기'), findsNothing);

    await tapButton<FilledButton>(tester, '정산하기');
    final (rate, plan) = settlements.confirmed.single;
    expect(rate.krwPerUnit, Decimal.one);
    expect(plan, hasLength(2));
  });

  test('직접 입력 환율 단위: 엔화는 100엔', () {
    expect(ExchangeRate.inputUnitOf(Currency.jpy), 100);
    expect(ExchangeRate.inputUnitOf(Currency.cny), 1);
  });
}
