/// 입력 길이·개수 제한. DB 제약조건(supabase/migrations)과 같게 유지한다.
abstract final class Limits {
  /// 닉네임 = 멤버 이름 (members.name)
  static const personName = 20;

  /// trips.name
  static const tripName = 40;

  /// create_trip RPC
  static const members = 20;
}
