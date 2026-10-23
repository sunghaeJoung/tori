import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/exchange_rate/exchange_rate.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/money/split.dart';
import 'package:tori/features/expenses/data/expense.dart';
import 'package:tori/features/settlement/data/settlement.dart';

void main() {
  // development.md 3-5: 4명 중국 여행, 1위안 = 192.35원
  const m = '민지', s = '수아', j = '지훈', h = '하린';
  const all = [m, s, j, h];

  Expense e(
    String id,
    int amount,
    Currency c,
    String paidBy,
    Map<String, int> shares,
  ) => Expense(
    id: id,
    title: id,
    amount: amount,
    currency: c,
    paidBy: paidBy,
    category: ExpenseCategory.etc,
    spentAt: DateTime(2026, 11, 6),
    shares: shares,
  );

  Map<String, int> even(int amount, List<String> ids) =>
      splitEvenly(amount, ids);

  final expenses = [
    e('항공권', 1200000, Currency.krw, s, even(1200000, all)),
    e('훠궈', 68000, Currency.cny, m, even(68000, all)),
    e('택시', 5850, Currency.cny, j, even(5850, all)),
    e('호텔', 480000, Currency.cny, h, even(480000, all)),
    e('맥주', 9600, Currency.cny, j, even(9600, [m, j, h])),
    e('밀크티', 4500, Currency.cny, s, even(4500, all)),
    e('크루즈', 48000, Currency.cny, m, even(48000, all)),
  ];
  final rate = ExchangeRate(
    currency: Currency.cny,
    krwPerUnit: Decimal.parse('192.35'),
    date: DateTime(2026, 11, 9),
  );

  test('3-5 예시: 여행 지출로 정산하면 568,010 / 325,550 / 49,060원', () {
    final balances = TripBalances(
      all,
      expenses,
      local: Currency.cny,
      expensesVersion: 'v1',
    );
    expect(balances.plan(rate), [
      (from: j, to: s, amountKrw: 568010),
      (from: m, to: h, amountKrw: 325550),
      (from: m, to: s, amountKrw: 49060),
    ]);
  });

  test('통화별 총 지출과 원화 환산 총액', () {
    final balances = TripBalances(
      all,
      expenses,
      local: Currency.cny,
      expensesVersion: 'v1',
    );
    // 현지 통화(위안)가 먼저
    expect(balances.totals.keys, [Currency.cny, Currency.krw]);
    expect(balances.totals, {Currency.cny: 615950, Currency.krw: 1200000});
    // 6,159.50위안 × 192.35 + 1,200,000원
    expect(balances.totalInKrw(rate), Decimal.parse('2384779.825'));
    expect(balances.inKrw(rate)[j], Decimal.parse('-568014.7195'));
  });

  test('총 지출 표기: 환산은 약, 원화 여행은 정확히', () {
    final balances = TripBalances(
      all,
      expenses,
      local: Currency.cny,
      expensesVersion: 'v1',
    );
    expect(balances.totalLabel(rate), '약 2,384,780원');
    final won = TripBalances(
      all,
      [e('항공권', 1200005, Currency.krw, s, even(1200005, all))],
      local: Currency.krw,
      expensesVersion: 'v1',
    );
    expect(
      won.totalLabel(ExchangeRate.won(DateTime(2026, 11, 9))),
      '1,200,005원',
    );
  });

  test('지출이 없으면 비어 있고 보낼 돈도 없다', () {
    final balances = TripBalances(
      all,
      const [],
      local: Currency.cny,
      expensesVersion: 'v1',
    );
    expect(balances.isEmpty, isTrue);
    expect(balances.plan(rate), isEmpty);
  });
}
