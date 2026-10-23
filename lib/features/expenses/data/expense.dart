import '../../../core/money/currency.dart';
import '../../../core/money/settlement.dart';

/// 지출 카테고리. [code]는 DB `expenses.category` 값.
enum ExpenseCategory {
  lodging('lodging', '숙소'),
  food('food', '식비'),
  transport('transport', '교통'),
  cafe('cafe', '카페'),
  drink('drink', '술'),
  activity('activity', '놀거리'),
  shopping('shopping', '쇼핑'),
  etc('etc', '기타');

  const ExpenseCategory(this.code, this.label);

  final String code;
  final String label;

  /// 모르는 값(나중에 추가된 카테고리 등)은 기타로 본다.
  static ExpenseCategory fromCode(String code) =>
      values.firstWhere((c) => c.code == code, orElse: () => etc);
}

/// 고치려던 지출을 다른 친구가 이미 지웠다.
class ExpenseNotFound implements Exception {
  const ExpenseNotFound();
}

/// 여행의 지출 목록과 그 버전(trips.expenses_changed_at).
/// 한 번에 조회해서 둘이 항상 맞는다. 정산을 확정할 때 이 버전으로 계산했다고 알린다.
class TripExpenses {
  const TripExpenses(this.items, {required this.version});

  /// 최근 날짜 순.
  final List<Expense> items;
  final String version;
}

/// 지출 한 건과 멤버별 부담액.
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.paidBy,
    required this.category,
    required this.spentAt,
    required this.shares,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: json['amount'] as int,
    currency: Currency.fromCode(json['currency'] as String),
    paidBy: json['paid_by'] as String,
    category: ExpenseCategory.fromCode(json['category'] as String),
    spentAt: DateTime.parse(json['spent_at'] as String),
    shares: {
      for (final s in json['expense_splits'] as List)
        s['member_id'] as String: s['share_amount'] as int,
    },
  );

  final String id;
  final String title;

  /// 최소 단위 정수.
  final int amount;
  final Currency currency;

  /// 낸 사람 멤버 id.
  final String paidBy;
  final ExpenseCategory category;
  final DateTime spentAt;

  /// 나눈 사람 멤버 id → 부담액 (최소 단위 정수). 합계는 [amount].
  final Map<String, int> shares;

  ExpenseEntry toEntry() => ExpenseEntry(
    paidBy: paidBy,
    amount: amount,
    currency: currency,
    shares: shares,
  );
}
