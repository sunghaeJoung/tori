import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/features/expenses/data/expense.dart';

void main() {
  test('DB 행을 지출로', () {
    final e = Expense.fromJson({
      'id': 'e1',
      'title': '훠궈',
      'amount': 68000,
      'currency': 'CNY',
      'paid_by': 'm1',
      'category': 'food',
      'spent_at': '2026-11-06',
      'expense_splits': [
        {'member_id': 'm1', 'share_amount': 34000},
        {'member_id': 'm2', 'share_amount': 34000},
      ],
    });
    expect(e.currency, Currency.cny);
    expect(e.category, ExpenseCategory.food);
    expect(e.spentAt, DateTime(2026, 11, 6));
    expect(e.shares, {'m1': 34000, 'm2': 34000});
    expect(e.toEntry().shares, e.shares);
  });

  test('모르는 카테고리는 기타', () {
    expect(ExpenseCategory.fromCode('spa'), ExpenseCategory.etc);
    expect(ExpenseCategory.fromCode('drink'), ExpenseCategory.drink);
  });
}
