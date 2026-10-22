import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../../shared/limits.dart';

/// 친구들에게 보일 이름. 익명 계정의 user_metadata에 저장한다. 없으면 null.
final nicknameProvider = NotifierProvider<NicknameNotifier, String?>(
  NicknameNotifier.new,
);

class NicknameNotifier extends Notifier<String?> {
  @override
  String? build() {
    final client = ref.watch(supabaseProvider);
    final subscription = client.auth.onAuthStateChange.listen(
      (auth) => state = _read(auth.session?.user),
    );
    ref.onDispose(subscription.cancel);
    return _read(client.auth.currentUser);
  }

  /// 이름으로 쓸 수 있는지. 쓸 수 없으면 이유를 돌려준다.
  static String? validate(String nickname) {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return '이름을 입력해 주세요';
    if (textLength(trimmed) > Limits.personName) {
      return '이름은 ${Limits.personName}자까지 쓸 수 있어요';
    }
    return null;
  }

  Future<void> save(String nickname) async {
    final error = validate(nickname);
    if (error != null) throw ArgumentError.value(nickname, 'nickname', error);
    final trimmed = nickname.trim();
    await ref.read(authUserProvider.future);
    final response = await ref
        .read(supabaseProvider)
        .auth
        .updateUser(UserAttributes(data: {'nickname': trimmed}));
    state = _read(response.user);
  }

  /// 저장된 값이 이름 규칙에 맞지 않으면(다른 기기·예전 버전 등) 없는 것으로 보고
  /// 첫 실행 화면에서 다시 정하게 한다.
  static String? _read(User? user) {
    final value = user?.userMetadata?['nickname'];
    if (value is! String || validate(value) != null) return null;
    return value.trim();
  }
}
