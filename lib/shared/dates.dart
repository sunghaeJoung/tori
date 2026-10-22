import 'package:intl/intl.dart';

final _full = DateFormat('yyyy.MM.dd');
final _monthDay = DateFormat('MM.dd');
final _db = DateFormat('yyyy-MM-dd');

/// 화면 표기: `2026.11.06`
String formatDate(DateTime date) => _full.format(date);

/// 여행 기간 표기. 같은 해면 뒤쪽 연도를 줄인다.
///
/// `2026.11.06 – 11.09` · `2026.12.30 – 2027.01.02` · 하루면 `2026.11.06`
String formatDateRange(DateTime start, DateTime end) {
  final startText = formatDate(start);
  if (formatDate(end) == startText) return startText;
  final endText = start.year == end.year
      ? _monthDay.format(end)
      : formatDate(end);
  return '$startText – $endText';
}

/// DB `date` 열에 넣는 문자열: `2026-11-06`
String toDbDate(DateTime date) => _db.format(date);
