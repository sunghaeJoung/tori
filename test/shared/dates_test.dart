import 'package:flutter_test/flutter_test.dart';
import 'package:tori/shared/dates.dart';

void main() {
  test('같은 해면 뒤쪽 연도를 줄인다', () {
    expect(
      formatDateRange(DateTime(2026, 11, 6), DateTime(2026, 11, 9)),
      '2026.11.06 – 11.09',
    );
  });

  test('해가 바뀌면 둘 다 연도까지', () {
    expect(
      formatDateRange(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
      '2026.12.30 – 2027.01.02',
    );
  });

  test('지출 날짜는 월·일·요일', () {
    expect(formatMonthDay(DateTime(2026, 11, 6)), '11월 6일 (금)');
    expect(formatMonthDay(DateTime(2026, 11, 8)), '11월 8일 (일)');
  });

  test('환율 기준일', () {
    expect(formatLongDate(DateTime(2026, 11, 9)), '2026년 11월 9일');
  });

  test('DB 날짜 문자열', () {
    expect(toDbDate(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('당일치기는 날짜 하나', () {
    expect(
      formatDateRange(DateTime(2026, 11, 6), DateTime(2026, 11, 6)),
      '2026.11.06',
    );
  });
}
