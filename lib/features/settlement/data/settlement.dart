import 'package:decimal/decimal.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/settlement.dart';
import '../../expenses/data/expense.dart';

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

/// 여행의 지출을 멤버별로 정리한 값 (잔액 탭, 정산 화면).
class TripBalances {
  TripBalances(this.memberIds, List<Expense> expenses)
    : byCurrency = computeBalances(memberIds, expenses.map((e) => e.toEntry())),
      totals = _totals(expenses);

  /// 멤버 순서.
  final List<String> memberIds;

  /// 통화별·멤버별 잔액 (최소 단위). 양수 = 받을 돈. 지출이 있는 통화만.
  final Map<Currency, Map<String, int>> byCurrency;

  /// 통화별 총 지출 (최소 단위).
  final Map<Currency, int> totals;

  bool get isEmpty => totals.isEmpty;

  /// 멤버별 원화 잔액. [krwPerUnit]은 현지 통화([local]) 1단위의 원화 환율.
  /// 반올림하지 않는다.
  Map<String, Decimal> inKrw(Currency local, Decimal krwPerUnit) =>
      toKrwBalances(memberIds, byCurrency, {local: krwPerUnit});

  /// 총 지출을 원화로 (반올림하지 않음).
  Decimal totalInKrw(Currency local, Decimal krwPerUnit) => totals.entries.fold(
    Decimal.zero,
    (sum, t) =>
        sum +
        t.key.toMajor(t.value) *
            (t.key == Currency.krw ? Decimal.one : krwPerUnit),
  );

  /// 누가 누구에게 얼마를 보내면 되는지 (송금 건수가 적게, 10원 단위).
  List<Transfer> plan(Currency local, Decimal krwPerUnit) =>
      settle(inKrw(local, krwPerUnit));

  static Map<Currency, int> _totals(List<Expense> expenses) {
    final totals = <Currency, int>{};
    for (final e in expenses) {
      totals.update(
        e.currency,
        (sum) => sum + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    return totals;
  }
}
