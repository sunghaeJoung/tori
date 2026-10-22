/// 이름 뒤에 '로/으로'를 붙인다. 받침이 없거나 ㄹ 받침이면 '로'.
///
/// 수아 → 수아로 · 지훈 → 지훈으로 · 하늘 → 하늘로 · Amy → Amy로
String withRo(String word) {
  if (word.isEmpty) return word;
  final last = word.runes.last;
  const hangulStart = 0xAC00, hangulEnd = 0xD7A3;
  if (last < hangulStart || last > hangulEnd) return '$word로';
  final jongseong = (last - hangulStart) % 28;
  const rieul = 8;
  return jongseong == 0 || jongseong == rieul ? '$word로' : '$word으로';
}
