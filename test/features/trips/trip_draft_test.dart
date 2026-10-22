import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/features/trips/ui/trip_draft.dart';

void main() {
  test('단계마다 다음으로 갈 수 있는 조건', () {
    final draft = TripDraft();
    expect(draft.canProceed(1), isFalse);
    draft.name = '   ';
    expect(draft.canProceed(1), isFalse);
    draft.name = '상하이';
    expect(draft.canProceed(1), isTrue);
    draft.name = 'a' * 41;
    expect(draft.canProceed(1), isFalse);

    expect(draft.canProceed(2), isFalse);
    draft
      ..startDate = DateTime(2026, 11, 9)
      ..endDate = DateTime(2026, 11, 6);
    expect(draft.canProceed(2), isFalse);
    draft.endDate = DateTime(2026, 11, 9);
    expect(draft.canProceed(2), isTrue, reason: '당일치기도 된다');

    expect(draft.canProceed(3), isFalse);
    draft.currency = Currency.jpy;
    expect(draft.canProceed(3), isTrue);

    expect(draft.canProceed(4), isFalse);
    draft.addFriend('수아', myName: '민지');
    expect(draft.canProceed(4), isTrue);
  });

  test('출발일을 도착일 뒤로 바꾸면 도착일도 따라간다', () {
    final draft = TripDraft()
      ..startDate = DateTime(2026, 11, 6)
      ..endDate = DateTime(2026, 11, 9);
    draft.setStartDate(DateTime(2026, 11, 12));
    expect(draft.endDate, DateTime(2026, 11, 12));
  });

  test('친구 추가 규칙', () {
    final draft = TripDraft();
    expect(draft.addFriend('  ', myName: '민지'), '이름을 입력해 주세요');
    expect(draft.addFriend(' 민지 ', myName: '민지'), '이미 있는 이름이에요');
    expect(draft.addFriend(' 수아 ', myName: '민지'), isNull);
    expect(draft.addFriend('수아', myName: '민지'), '이미 있는 이름이에요');
    expect(draft.addFriend('a' * 21, myName: '민지'), contains('20자'));
    expect(draft.friends, ['수아']);

    for (var i = draft.friends.length; i < TripDraft.maxMembers - 1; i++) {
      expect(draft.addFriend('친구$i', myName: '민지'), isNull);
    }
    expect(draft.addFriend('한명더', myName: '민지'), '멤버는 20명까지예요');
    expect(draft.friends.length, 19);
  });
}
