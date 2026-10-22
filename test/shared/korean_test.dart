import 'package:flutter_test/flutter_test.dart';
import 'package:tori/shared/korean.dart';

void main() {
  test('받침에 따라 로/으로', () {
    expect(withRo('수아'), '수아로');
    expect(withRo('지훈'), '지훈으로');
    expect(withRo('하늘'), '하늘로'); // ㄹ 받침은 '로'
    expect(withRo('Amy'), 'Amy로');
    expect(withRo(''), '');
  });
}
