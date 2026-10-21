/// 금액을 멤버들에게 균등하게 나눈다.
///
/// [amount]는 최소 단위 정수. 나누어 떨어지지 않는 나머지는 [memberIds] 순서대로
/// 앞사람부터 1단위씩 더 낸다. 결과 합계는 항상 [amount]와 같다.
///
/// 예: 5850(58.50위안) ÷ 4명 → 1463 / 1463 / 1462 / 1462
Map<String, int> splitEvenly(int amount, List<String> memberIds) {
  if (amount <= 0) {
    throw ArgumentError.value(amount, 'amount', '0보다 커야 한다');
  }
  if (memberIds.isEmpty) {
    throw ArgumentError.value(memberIds, 'memberIds', '한 명 이상이어야 한다');
  }
  if (memberIds.toSet().length != memberIds.length) {
    throw ArgumentError.value(memberIds, 'memberIds', '중복된 멤버가 있다');
  }

  final share = amount ~/ memberIds.length;
  final remainder = amount % memberIds.length;
  return {
    for (var i = 0; i < memberIds.length; i++)
      memberIds[i]: share + (i < remainder ? 1 : 0),
  };
}
