import 'package:decimal/decimal.dart';

import '../../../core/exchange_rate/exchange_rate.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/settlement.dart';
import '../../expenses/data/expense.dart';

/// 정산을 계산하는 사이 친구가 지출을 바꿨다. 다시 확인하고 정산해야 한다.
class ExpensesChangedDuringSettlement implements Exception {
  const ExpensesChangedDuringSettlement();
}

/// 저장된 송금 한 건 (settlements 행).
class SettlementTransfer {
  const SettlementTransfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amountKrw,
    required this.done,
  });

  factory SettlementTransfer.fromJson(Map<String, dynamic> json) =>
      SettlementTransfer(
        id: json['id'] as String,
        from: json['from_member'] as String,
        to: json['to_member'] as String,
        amountKrw: json['amount_krw'] as int,
        done: json['done_at'] != null,
      );

  final String id;

  /// 보내는 멤버 id
  final String from;

  /// 받는 멤버 id
  final String to;

  /// 10원 단위로 반올림한 원화 송금액.
  final int amountKrw;

  /// 송금 완료를 체크했는가.
  final bool done;
}

/// 여행의 지출을 멤버별로 정리한 값 (요약 카드, 잔액 탭, 정산).
class TripBalances {
  TripBalances(this.memberIds, List<Expense> expenses, {required this.local})
    : byCurrency = computeBalances(memberIds, expenses.map((e) => e.toEntry())),
      totals = _totals(expenses, local);

  /// 멤버 순서.
  final List<String> memberIds;

  /// 여행 현지 통화.
  final Currency local;

  /// 통화별·멤버별 잔액 (최소 단위). 양수 = 받을 돈. 지출이 있는 통화만.
  final Map<Currency, Map<String, int>> byCurrency;

  /// 통화별 총 지출 (최소 단위). 현지 통화 먼저, 지출이 있는 통화만.
  final Map<Currency, int> totals;

  bool get isEmpty => totals.isEmpty;

  /// 멤버별 원화 잔액. 반올림하지 않는다.
  Map<String, Decimal> inKrw(ExchangeRate rate) =>
      toKrwBalances(memberIds, byCurrency, {rate.currency: rate.krwPerUnit});

  /// 화면에 보여줄 멤버별 잔액: 환율이 있으면 원화 10원 단위로 환산,
  /// 없거나 원화 여행이면 현지 통화 그대로.
  ({Map<String, int> amounts, Currency currency}) display(ExchangeRate? rate) =>
      rate == null || rate.isWon
      ? (
          amounts: byCurrency[local] ?? {for (final id in memberIds) id: 0},
          currency: local,
        )
      : (
          amounts: inKrw(rate)
              .map((id, won) => MapEntry(id, roundTo10Won(won))),
          currency: Currency.krw,
        );

  /// 총 지출을 원화로 (반올림하지 않음).
  Decimal totalInKrw(ExchangeRate rate) => totals.entries.fold(
    Decimal.zero,
    (sum, t) =>
        sum +
        (t.key == Currency.krw
            ? Decimal.fromInt(t.value)
            : rate.toKrw(t.value)),
  );

  /// 누가 누구에게 얼마를 보내면 되는지 (송금 건수가 적게, 10원 단위).
  List<Transfer> plan(ExchangeRate rate) => settle(inKrw(rate));

  static Map<Currency, int> _totals(List<Expense> expenses, Currency local) {
    int sumOf(Currency c) => expenses
        .where((e) => e.currency == c)
        .fold(0, (sum, e) => sum + e.amount);
    return {
      for (final c in {local, ...expenses.map((e) => e.currency)})
        if (sumOf(c) case final total when total > 0) c: total,
    };
  }
}
