import 'package:decimal/decimal.dart';

import 'currency.dart';

/// 잔액 계산에 필요한 지출 한 건.
class ExpenseEntry {
  const ExpenseEntry({
    required this.paidBy,
    required this.amount,
    required this.currency,
    required this.shares,
  });

  /// 낸 사람 멤버 id.
  final String paidBy;

  /// 지출 금액 (최소 단위 정수).
  final int amount;

  final Currency currency;

  /// 멤버 id → 부담액 (최소 단위 정수). 합계는 [amount]와 같아야 한다.
  final Map<String, int> shares;
}

/// 송금 한 건. [amountKrw]는 10원 단위로 반올림한 원화 금액.
typedef Transfer = ({String from, String to, int amountKrw});

/// 통화별·멤버별 잔액을 계산한다. 양수 = 받을 돈, 음수 = 줄 돈.
///
/// 잔액 = (낸 지출 합) − (부담액 합). 통화별 잔액 합계는 항상 0이다.
/// 결과의 멤버 순서는 [memberIds] 순서를 따르고, 지출이 있는 통화만 들어간다.
Map<Currency, Map<String, int>> computeBalances(
  List<String> memberIds,
  Iterable<ExpenseEntry> expenses,
) {
  final known = memberIds.toSet();
  if (known.length != memberIds.length) {
    throw ArgumentError.value(memberIds, 'memberIds', '중복된 멤버가 있다');
  }
  final balances = <Currency, Map<String, int>>{};

  for (final e in expenses) {
    if (e.amount <= 0 || e.shares.values.any((s) => s < 0)) {
      throw ArgumentError('지출 금액은 0보다 크고 부담액은 0 이상이어야 한다');
    }
    final shareTotal = e.shares.values.fold(0, (a, b) => a + b);
    if (shareTotal != e.amount) {
      throw ArgumentError('부담액 합계($shareTotal)가 지출 금액(${e.amount})과 다르다');
    }
    final unknown = {e.paidBy, ...e.shares.keys}.difference(known);
    if (unknown.isNotEmpty) {
      throw ArgumentError('멤버 목록에 없는 id: $unknown');
    }

    final byMember = balances.putIfAbsent(
      e.currency,
      () => {for (final id in memberIds) id: 0},
    );
    byMember.update(e.paidBy, (v) => v + e.amount);
    for (final MapEntry(key: id, value: share) in e.shares.entries) {
      byMember.update(id, (v) => v - share);
    }
  }
  return balances;
}

/// 통화별 잔액을 원화 잔액 하나로 합친다. 중간에 반올림하지 않는다.
///
/// [krwRates]는 통화 1단위(예: 1위안)당 원화 환율. KRW는 넣지 않아도 된다.
Map<String, Decimal> toKrwBalances(
  List<String> memberIds,
  Map<Currency, Map<String, int>> balances,
  Map<Currency, Decimal> krwRates,
) {
  final result = {for (final id in memberIds) id: Decimal.zero};
  for (final MapEntry(key: currency, value: byMember) in balances.entries) {
    final rate = currency == Currency.krw ? Decimal.one : krwRates[currency];
    if (rate == null || rate <= Decimal.zero) {
      throw ArgumentError('${currency.code} 환율이 없거나 0 이하다: $rate');
    }
    for (final MapEntry(key: id, value: amount) in byMember.entries) {
      result.update(id, (v) => v + currency.toMajor(amount) * rate);
    }
  }
  return result;
}

/// 송금 건수가 적도록 줄 사람 → 받을 사람 송금 목록을 만든다.
///
/// 매번 가장 많이 받을 사람과 가장 많이 줄 사람을 짝지어 둘 중 작은 금액만큼 보낸다.
/// 금액이 같으면 [krwBalances]의 순서(멤버 순서)가 앞선 사람이 먼저다.
/// 각 송금액만 마지막에 10원 단위로 반올림하고(5원 이상 올림), 0원이 되면 뺀다.
/// [krwBalances]의 합계는 0이어야 한다 (반올림하지 않은 값을 넣는다).
List<Transfer> settle(Map<String, Decimal> krwBalances) {
  final total = krwBalances.values.fold(Decimal.zero, (a, b) => a + b);
  if (total != Decimal.zero) {
    throw ArgumentError('잔액 합계가 0이 아니다: $total');
  }
  final creditors = [
    for (final e in krwBalances.entries)
      if (e.value > Decimal.zero) _Party(e.key, e.value),
  ];
  final debtors = [
    for (final e in krwBalances.entries)
      if (e.value < Decimal.zero) _Party(e.key, -e.value),
  ];

  final transfers = <Transfer>[];
  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    final c = _largest(creditors);
    final d = _largest(debtors);
    final x = c.amount < d.amount ? c.amount : d.amount;

    final rounded = x.round(scale: -1).toBigInt().toInt();
    if (rounded > 0) {
      transfers.add((from: d.id, to: c.id, amountKrw: rounded));
    }

    c.amount -= x;
    d.amount -= x;
    if (c.amount == Decimal.zero) creditors.remove(c);
    if (d.amount == Decimal.zero) debtors.remove(d);
  }
  return transfers;
}

class _Party {
  _Party(this.id, this.amount);

  final String id;
  Decimal amount;
}

_Party _largest(List<_Party> parties) =>
    parties.reduce((best, p) => p.amount > best.amount ? p : best);
