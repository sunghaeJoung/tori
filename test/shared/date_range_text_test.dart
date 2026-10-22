import 'package:flutter_test/flutter_test.dart';
import 'package:tori/shared/date_range_text.dart';

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

  test('당일치기는 날짜 하나', () {
    expect(
      formatDateRange(DateTime(2026, 11, 6), DateTime(2026, 11, 6)),
      '2026.11.06',
    );
  });
}
