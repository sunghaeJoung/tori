import '../../../core/money/currency.dart';
import '../../../shared/limits.dart';

/// 여행 만들기 화면에서 입력 중인 값과 단계별 검사.
class TripDraft {
  String name = '';
  DateTime? startDate;
  DateTime? endDate;
  Currency? currency;

  /// 나를 뺀 함께 가는 친구들. 입력한 순서가 멤버 순서가 된다.
  final List<String> friends = [];

  /// 1 이름 · 2 날짜 · 3 통화 · 4 멤버(나 말고 한 명 이상)
  bool canProceed(int step) => switch (step) {
    1 => name.trim().isNotEmpty && name.trim().length <= Limits.tripName,
    2 => startDate != null && endDate != null && !endDate!.isBefore(startDate!),
    3 => currency != null,
    4 => friends.isNotEmpty,
    _ => false,
  };

  /// 출발일을 바꿀 때 도착일이 더 앞이면 도착일을 출발일로 맞춘다.
  void setStartDate(DateTime date) {
    startDate = date;
    if (endDate != null && endDate!.isBefore(date)) endDate = date;
  }

  /// 친구를 추가한다. 추가하지 못하면 이유를 돌려준다.
  String? addFriend(String rawName, {required String myName}) {
    final name = rawName.trim();
    if (name.isEmpty) return '이름을 입력해 주세요';
    if (name.length > Limits.personName) {
      return '이름은 ${Limits.personName}자까지 쓸 수 있어요';
    }
    if (name == myName.trim() || friends.contains(name)) {
      return '이미 있는 이름이에요';
    }
    if (friends.length + 1 >= Limits.members) {
      return '멤버는 ${Limits.members}명까지예요';
    }
    friends.add(name);
    return null;
  }
}
