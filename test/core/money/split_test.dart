import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/split.dart';

void main() {
  const four = ['민지', '수아', '지훈', '하린'];

  test('나누어 떨어지면 모두 같은 금액', () {
    expect(splitEvenly(68000, four), {
      '민지': 17000,
      '수아': 17000,
      '지훈': 17000,
      '하린': 17000,
    });
  });

  test('나머지는 멤버 순서대로 앞사람부터 1단위씩 더 낸다', () {
    expect(splitEvenly(5850, four), {
      '민지': 1463,
      '수아': 1463,
      '지훈': 1462,
      '하린': 1462,
    });
    expect(splitEvenly(10, ['a', 'b', 'c']), {'a': 4, 'b': 3, 'c': 3});
  });

  test('금액이 인원보다 작으면 앞사람만 1단위씩', () {
    expect(splitEvenly(2, four), {'민지': 1, '수아': 1, '지훈': 0, '하린': 0});
  });

  test('합계는 항상 원래 금액과 같다', () {
    for (var amount = 1; amount <= 1000; amount++) {
      for (var n = 1; n <= 7; n++) {
        final ids = [for (var i = 0; i < n; i++) 'm$i'];
        final total = splitEvenly(amount, ids).values.reduce((a, b) => a + b);
        expect(total, amount, reason: '$amount ÷ $n');
      }
    }
  });

  test('잘못된 입력은 거부한다', () {
    expect(() => splitEvenly(0, four), throwsArgumentError);
    expect(() => splitEvenly(-100, four), throwsArgumentError);
    expect(() => splitEvenly(100, []), throwsArgumentError);
    expect(() => splitEvenly(100, ['a', 'a']), throwsArgumentError);
  });
}
