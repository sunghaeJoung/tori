import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/features/expenses/data/expense.dart';
import 'package:tori/features/expenses/data/expense_draft.dart';

ExpenseDraft draft({Currency currency = Currency.cny}) => ExpenseDraft(
  currency: currency,
  spentAt: DateTime(2026, 11, 7),
  paidBy: 'm1',
  splitAmong: const ['m1', 'm2', 'm3'],
);

ExpenseDraft typed(String keys, {Currency currency = Currency.cny}) {
  final d = draft(currency: currency);
  for (final key in keys.split(' ')) {
    d.press(key);
  }
  return d;
}

void main() {
  test('키패드로 누른 금액을 최소 단위 정수로', () {
    expect(typed('1 2 8 . 5').amount, 12850);
    expect(typed('1 2 8 . 5 0').amount, 12850);
    expect(typed('. 5').amountText, '0.5');
    expect(typed('1 2 3 5 0', currency: Currency.krw).amount, 12350);
    expect(draft().amount, 0);
  });

  test('받을 수 없는 키는 무시한다', () {
    expect(typed('1 . 2 3 4').amountText, '1.23', reason: '소수 자리 초과');
    expect(typed('1 . 2 .').amountText, '1.2', reason: '점은 한 번');
    expect(
      typed('1 .', currency: Currency.krw).amountText,
      '1',
      reason: '원화는 소수 없음',
    );
    expect(typed('0 0 0 5').amountText, '5', reason: '맨 앞 0');
    expect(typed('00', currency: Currency.krw).amountText, '0');
    expect(typed('1 00 00 00 00 00').amountText, '100000000', reason: '9자리까지');
    expect(typed('1 2 del').amountText, '1');
    expect(typed('del').amountText, '');
  });

  test('화면 표기는 세 자리마다 쉼표, 누른 소수는 그대로', () {
    expect(typed('1 2 8 0 . 5').amountDisplay, '1,280.5');
    expect(
      typed('1 2 0 0 0 0 0', currency: Currency.krw).amountDisplay,
      '1,200,000',
    );
    expect(draft().amountDisplay, '0');
  });

  test('원화로 바꾸면 소수 부분을 버린다', () {
    final d = typed('9 6 . 5')..setCurrency(Currency.krw);
    expect(d.amountText, '96');
    expect(d.amount, 96);
  });

  test('부담액은 멤버 순서대로, 나머지는 앞사람부터', () {
    final d = typed('1 0 0', currency: Currency.krw)
      ..splitAmong.remove('m2')
      ..splitAmong.add('m2');
    // 고른 순서와 상관없이 멤버 순서(m1, m2, m3)
    expect(d.sharesIn(['m1', 'm2', 'm3']), {'m1': 34, 'm2': 33, 'm3': 33});
    d.splitAmong.remove('m1');
    expect(d.sharesIn(['m1', 'm2', 'm3']), {'m2': 50, 'm3': 50});
  });

  test('1인당 안내 문구', () {
    expect(typed('1 2 8 . 5').perPersonText(), '3명 · 1인당 42.83위안~42.84위안');
    expect(
      typed('9 0 0', currency: Currency.krw).perPersonText(),
      '3명 · 1인당 300원',
    );
    expect(draft().perPersonText(), '금액을 입력해주세요');
    expect((typed('1')..splitAmong.clear()).perPersonText(), '나눌 사람을 골라주세요');
  });

  test('저장할 수 있는 조건과 기본 내용', () {
    final d = typed('1');
    expect(d.canSave, isTrue);
    expect(d.titleOrDefault, '식비');
    d.title = '  훠궈  ';
    expect(d.titleOrDefault, '훠궈');
    d.title = '가' * 41;
    expect(d.canSave, isFalse);
    expect(draft().canSave, isFalse, reason: '금액 0');
    expect((typed('1')..splitAmong.clear()).canSave, isFalse);
    expect((typed('1')..paidBy = null).canSave, isFalse);
  });

  test('저장된 지출로 채우기', () {
    final d = ExpenseDraft.from(
      Expense(
        id: 'e1',
        title: '훠궈',
        amount: 12850,
        currency: Currency.cny,
        paidBy: 'm2',
        category: ExpenseCategory.food,
        spentAt: DateTime(2026, 11, 6),
        shares: const {'m1': 6425, 'm2': 6425},
      ),
    );
    expect(d.amountText, '128.5');
    expect(d.amount, 12850);
    expect(d.splitAmong, {'m1', 'm2'});
    expect(ExpenseDraft.amountTextOf(9600, Currency.cny), '96');
  });
}
