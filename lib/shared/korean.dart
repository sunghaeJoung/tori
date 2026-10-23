/// 이름 뒤에 '로/으로'를 붙인다. 받침이 없거나 ㄹ 받침이면 '로'.
///
/// 수아 → 수아로 · 지훈 → 지훈으로 · 하늘 → 하늘로 · 민지3 → 민지3으로 · Amy → Amy(으)로
String withRo(String word) {
  if (word.isEmpty) return word;
  final last = word.runes.last;

  const hangulStart = 0xAC00, hangulEnd = 0xD7A3;
  if (last >= hangulStart && last <= hangulEnd) {
    final jongseong = (last - hangulStart) % 28;
    const rieul = 8;
    return jongseong == 0 || jongseong == rieul ? '$word로' : '$word으로';
  }

  // 숫자는 읽는 소리로: 영·삼·육은 받침(ㄹ 아님)이 있다
  const digitsWithBatchim = {'0', '3', '6'};
  final lastChar = String.fromCharCode(last);
  if (RegExp(r'[0-9]').hasMatch(lastChar)) {
    return digitsWithBatchim.contains(lastChar) ? '$word으로' : '$word로';
  }

  // 영어 등은 읽는 소리를 알 수 없다
  return '$word(으)로';
}
