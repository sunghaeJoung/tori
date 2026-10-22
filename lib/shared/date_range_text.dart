import 'package:intl/intl.dart';

final _full = DateFormat('yyyy.MM.dd');
final _monthDay = DateFormat('MM.dd');

/// 여행 기간 표기. 같은 해면 뒤쪽 연도를 줄인다.
///
/// `2026.11.06 – 11.09` · `2026.12.30 – 2027.01.02` · 하루면 `2026.11.06`
String formatDateRange(DateTime start, DateTime end) {
  final startText = _full.format(start);
  if (_full.format(end) == startText) return startText;
  final endText = start.year == end.year
      ? _monthDay.format(end)
      : _full.format(end);
  return '$startText – $endText';
}
