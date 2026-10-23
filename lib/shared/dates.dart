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

/// 환율 기준일 표기: `2026년 11월 9일`
String formatLongDate(DateTime date) =>
    '${date.year}년 ${date.month}월 ${date.day}일';

/// 지출 날짜 표기: `11월 6일 (금)`
String formatMonthDay(DateTime date) =>
    '${date.month}월 ${date.day}일 (${_weekdays[date.weekday - 1]})';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// DB `date` 열에 넣는 문자열: `2026-11-06`
String toDbDate(DateTime date) => _db.format(date);
