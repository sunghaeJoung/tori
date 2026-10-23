import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
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

  Map<String, int> even(int amount, List<String> ids) {
    final share = amount ~/ ids.length, rest = amount % ids.length;
    return {for (final (i, id) in ids.indexed) id: share + (i < rest ? 1 : 0)};
  }

  final expenses = [
    e('항공권', 1200000, Currency.krw, s, even(1200000, all)),
    e('훠궈', 68000, Currency.cny, m, even(68000, all)),
    e('택시', 5850, Currency.cny, j, even(5850, all)),
    e('호텔', 480000, Currency.cny, h, even(480000, all)),
    e('맥주', 9600, Currency.cny, j, even(9600, [m, j, h])),
    e('밀크티', 4500, Currency.cny, s, even(4500, all)),
    e('크루즈', 48000, Currency.cny, m, even(48000, all)),
  ];
  final rate = Decimal.parse('192.35');

  test('3-5 예시: 여행 지출로 정산하면 568,010 / 325,550 / 49,060원', () {
    final balances = TripBalances(all, expenses);
    expect(balances.plan(Currency.cny, rate), [
      (from: j, to: s, amountKrw: 568010),
      (from: m, to: h, amountKrw: 325550),
      (from: m, to: s, amountKrw: 49060),
    ]);
  });

  test('통화별 총 지출과 원화 환산 총액', () {
    final balances = TripBalances(all, expenses);
    expect(balances.totals, {Currency.krw: 1200000, Currency.cny: 615950});
    // 6,159.50위안 × 192.35 + 1,200,000원
    expect(
      balances.totalInKrw(Currency.cny, rate),
      Decimal.parse('2384779.825'),
    );
    expect(
      balances.inKrw(Currency.cny, rate)[j],
      Decimal.parse('-568014.7195'),
    );
  });

  test('지출이 없으면 비어 있고 보낼 돈도 없다', () {
    final balances = TripBalances(all, const []);
    expect(balances.isEmpty, isTrue);
    expect(balances.plan(Currency.cny, rate), isEmpty);
  });
}
