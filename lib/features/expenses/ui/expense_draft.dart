import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/split.dart';
import '../../../shared/limits.dart';
import '../data/expense.dart';

/// 지출 추가·수정 화면에서 입력 중인 값.
///
/// 금액은 키패드로 누른 글자 그대로([amountText], 예: `128.5`) 들고 있다가
/// [amount]에서 최소 단위 정수로 바꾼다.
class ExpenseDraft {
  ExpenseDraft({
    required this.currency,
    required this.spentAt,
    required this.paidBy,
    required Iterable<String> splitAmong,
    this.title = '',
    this.category = ExpenseCategory.food,
    this.amountText = '',
  }) : splitAmong = splitAmong.toSet();

  /// 고칠 지출의 값으로 채운다.
  factory ExpenseDraft.from(Expense expense) => ExpenseDraft(
    currency: expense.currency,
    spentAt: expense.spentAt,
    paidBy: expense.paidBy,
    splitAmong: expense.shares.keys,
    title: expense.title,
    category: expense.category,
    amountText: amountTextOf(expense.amount, expense.currency),
  );

  /// 숫자(점 빼고)는 9자리까지. 원화 9억 9천만 원, 위안 999만 위안 정도.
  static const maxDigits = 9;

  String title;
  ExpenseCategory category;
  Currency currency;
  DateTime spentAt;
  String? paidBy;

  /// 나눌 사람 멤버 id. 저장할 때 멤버 순서대로 정렬한다.
  final Set<String> splitAmong;
  String amountText;

  /// 최소 단위 정수 금액 (`128.5`위안 → 12850).
  int get amount {
    if (amountText.isEmpty) return 0;
    final [whole, ...rest] = amountText.split('.');
    final fraction = (rest.firstOrNull ?? '').padRight(currency.decimals, '0');
    return int.parse(
      '${whole.isEmpty ? '0' : whole}${fraction.substring(0, currency.decimals)}',
    );
  }

  /// 키패드 한 번 누르기. [key]는 `0`~`9`, `00`, `.`, `del`.
  /// 받을 수 없는 키(소수 자리 초과, 9자리 초과, 맨 앞 0 등)는 무시한다.
  void press(String key) {
    final text = amountText;
    final dot = text.indexOf('.');
    amountText = switch (key) {
      'del' => text.isEmpty ? text : text.substring(0, text.length - 1),
      '.' when currency.decimals == 0 || dot >= 0 => text,
      '.' => '${text.isEmpty ? '0' : text}.',
      _
          when dot >= 0 &&
              text.length - dot - 1 + key.length > currency.decimals =>
        text,
      _ when text.replaceAll('.', '').length + key.length > maxDigits => text,
      // 맨 앞에는 0을 여러 개 쓰지 않는다 (0 다음 숫자는 0을 바꾼다)
      '0' || '00' when text.isEmpty || text == '0' => '0',
      _ when text == '0' => key,
      _ => text + key,
    };
  }

  /// 통화를 바꾼다. 소수가 없는 통화로 바꾸면 소수 부분을 버린다.
  void setCurrency(Currency next) {
    currency = next;
    if (next.decimals == 0) amountText = amountText.split('.').first;
  }

  /// 키패드로 누른 금액을 화면 표기로: `1,280.5`
  String get amountDisplay {
    final [whole, ...rest] = amountText.split('.');
    final grouped = _thousands.format(int.tryParse(whole) ?? 0);
    return rest.isEmpty ? grouped : '$grouped.${rest.first}';
  }

  /// 저장할 이름. 비워 두면 카테고리 이름.
  String get titleOrDefault =>
      title.trim().isEmpty ? category.label : title.trim();

  bool get titleTooLong => textLength(title.trim()) > Limits.expenseTitle;

  bool get canSave =>
      amount > 0 && splitAmong.isNotEmpty && paidBy != null && !titleTooLong;

  /// [memberIds](멤버 순서) 기준으로 나눈 부담액. 나머지는 앞사람부터.
  Map<String, int> sharesIn(List<String> memberIds) =>
      splitEvenly(amount, memberIds.where(splitAmong.contains).toList());

  /// 금액 아래 안내: `4명 · 1인당 1,462.50위안` (나누어 떨어지지 않으면 `1,462~1,463원`)
  String perPersonText() {
    final count = splitAmong.length;
    if (count == 0) return '나눌 사람을 골라주세요';
    if (amount == 0) return '금액을 입력해주세요';
    final low = amount ~/ count;
    final each = amount % count == 0
        ? formatMoney(low, currency)
        : '${formatMoney(low, currency)}~${formatMoney(low + 1, currency)}';
    return '$count명 · 1인당 $each';
  }

  /// 저장된 금액을 키패드 글자로: 12850위안 → `128.5`, 12800 → `128`
  static String amountTextOf(int amount, Currency currency) =>
      currency.toMajor(amount).toString();
}

final _thousands = NumberFormat.decimalPattern('en_US');
