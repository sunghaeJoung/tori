import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/money/settlement.dart';
import 'package:tori/core/money/split.dart';

Decimal d(String s) => Decimal.parse(s);

/// [among]에게 균등하게 나눈 지출.
ExpenseEntry even(
  String paidBy,
  int amount,
  Currency currency,
  List<String> among,
) => ExpenseEntry(
  paidBy: paidBy,
  amount: amount,
  currency: currency,
  shares: splitEvenly(amount, among),
);

/// 부담액을 직접 정한 원화 지출.
ExpenseEntry krw(String paidBy, int amount, Map<String, int> shares) =>
    ExpenseEntry(
      paidBy: paidBy,
      amount: amount,
      currency: Currency.krw,
      shares: shares,
    );

void main() {
  group('development.md 3-5 예시: 4명 중국 여행 (1위안 = 192.35원)', () {
    const all = ['민지', '수아', '지훈', '하린'];

    final balances = computeBalances(all, [
      even('수아', 1200000, Currency.krw, all), // 항공권
      even('민지', 68000, Currency.cny, all), // 훠궈 저녁
      even('지훈', 5850, Currency.cny, all), // 디디 택시
      even('하린', 480000, Currency.cny, all), // 호텔 2박
      even('지훈', 9600, Currency.cny, ['민지', '지훈', '하린']), // 맥주
      even('수아', 4500, Currency.cny, all), // 밀크티
      even('민지', 48000, Currency.cny, all), // 와이탄 크루즈
    ]);
    final krwBalances = toKrwBalances(all, balances, {
      Currency.cny: d('192.35'),
    });

    test('통화별 잔액', () {
      expect(balances[Currency.cny], {
        '민지': -38788,
        '수아': -147088,
        '지훈': -139337,
        '하린': 325213,
      });
      expect(balances[Currency.krw], {
        '민지': -300000,
        '수아': 900000,
        '지훈': -300000,
        '하린': -300000,
      });
    });

    test('원화 환산은 반올림하지 않는다', () {
      expect(krwBalances, {
        '민지': d('-374608.718'),
        '수아': d('617076.232'),
        '지훈': d('-568014.7195'),
        '하린': d('325547.2055'),
      });
      expect(krwBalances.values.reduce((a, b) => a + b), Decimal.zero);
    });

    test('송금 3건: 568,010 / 325,550 / 49,060원', () {
      expect(settle(krwBalances), [
        (from: '지훈', to: '수아', amountKrw: 568010),
        (from: '민지', to: '하린', amountKrw: 325550),
        (from: '민지', to: '수아', amountKrw: 49060),
      ]);
    });
  });

  group('computeBalances', () {
    const abc = ['a', 'b', 'c'];

    test('통화별 잔액 합계는 0', () {
      final balances = computeBalances(abc, [
        even('a', 1000, Currency.jpy, abc),
        even('c', 777, Currency.jpy, ['b', 'c']),
      ]);
      expect(balances.keys, [Currency.jpy]);
      expect(balances[Currency.jpy]!.values.reduce((a, b) => a + b), 0);
    });

    test('지출이 없는 멤버도 0으로 들어간다', () {
      final balances = computeBalances(abc, [
        krw('a', 100, {'a': 50, 'b': 50}),
      ]);
      expect(balances[Currency.krw], {'a': 50, 'b': -50, 'c': 0});
    });

    test('지출이 없으면 빈 결과', () {
      expect(computeBalances(abc, []), isEmpty);
    });

    test('부담액 합계가 지출 금액과 다르면 거부한다', () {
      expect(
        () => computeBalances(abc, [
          krw('a', 100, {'a': 50, 'b': 49}),
        ]),
        throwsArgumentError,
      );
    });

    test('멤버 목록에 없는 id는 거부한다', () {
      expect(
        () => computeBalances(abc, [
          krw('x', 100, {'a': 50, 'b': 50}),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('toKrwBalances', () {
    test('환율이 없으면 거부한다', () {
      expect(
        () => toKrwBalances(
          ['a', 'b'],
          {
            Currency.usd: {'a': 100, 'b': -100},
          },
          {},
        ),
        throwsArgumentError,
      );
    });

    test('원화만 있으면 환율 없이 그대로', () {
      expect(
        toKrwBalances(
          ['a', 'b'],
          {
            Currency.krw: {'a': 100, 'b': -100},
          },
          {},
        ),
        {'a': d('100'), 'b': d('-100')},
      );
    });

    test('소수 자리수에 맞춰 환산한다', () {
      expect(
        toKrwBalances(
          ['a', 'b'],
          {
            Currency.jpy: {'a': 1000, 'b': -1000},
            Currency.usd: {'a': -1299, 'b': 1299},
          },
          {Currency.jpy: d('9.1234'), Currency.usd: d('1380.5')},
        ),
        {'a': d('-8809.295'), 'b': d('8809.295')},
      );
    });
  });

  group('settle', () {
    test('모두 0이면 송금 없음', () {
      expect(settle({'a': Decimal.zero, 'b': Decimal.zero}), isEmpty);
    });

    test('송금 건수는 최대 (인원 - 1)', () {
      final transfers = settle({
        'a': d('-100'),
        'b': d('-200'),
        'c': d('-300'),
        'd': d('250'),
        'e': d('350'),
      });
      expect(transfers.length, lessThanOrEqualTo(4));
      expect(transfers.fold(0, (s, t) => s + t.amountKrw), 600);
    });

    test('10원 단위 반올림: 5원 이상 올림, 4원 이하 버림', () {
      expect(settle({'a': d('-1235'), 'b': d('1235')}), [
        (from: 'a', to: 'b', amountKrw: 1240),
      ]);
      expect(settle({'a': d('-1234.99'), 'b': d('1234.99')}), [
        (from: 'a', to: 'b', amountKrw: 1230),
      ]);
    });

    test('반올림해서 0원이 되는 송금은 뺀다', () {
      expect(settle({'a': d('-4.9'), 'b': d('4.9')}), isEmpty);
    });

    test('금액이 같으면 멤버 순서가 앞선 사람이 먼저', () {
      expect(settle({'a': d('-100'), 'b': d('-100'), 'c': d('200')}), [
        (from: 'a', to: 'c', amountKrw: 100),
        (from: 'b', to: 'c', amountKrw: 100),
      ]);
    });
  });
}
