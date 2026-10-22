/// 입력 길이·개수 제한. DB 제약조건(supabase/migrations)과 같게 유지한다.
abstract final class Limits {
  /// 닉네임 = 멤버 이름 (members.name)
  static const personName = 20;

  /// trips.name
  static const tripName = 40;

  /// create_trip RPC
  static const members = 20;
}

/// DB `char_length`와 같은 기준(코드포인트)으로 센 글자 수.
/// 이모지처럼 화면에선 한 글자여도 여러 개로 셀 수 있다.
int textLength(String text) => text.runes.length;
