import 'package:flutter_test/flutter_test.dart';
import 'package:tori/features/onboarding/providers.dart';

void main() {
  test('닉네임 규칙: 앞뒤 공백 제외 1~20자 (DB와 같은 기준)', () {
    expect(NicknameNotifier.validate('  '), '이름을 입력해 주세요');
    expect(NicknameNotifier.validate(' 민지 '), isNull);
    expect(NicknameNotifier.validate('가' * 20), isNull);
    expect(NicknameNotifier.validate('가' * 21), contains('20자'));
    // 화면에선 5글자지만 코드포인트로는 25개
    expect(NicknameNotifier.validate('👨‍👩‍👧' * 5), contains('20자'));
  });
}
