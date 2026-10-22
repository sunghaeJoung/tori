import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';

/// 친구들에게 보일 이름. 익명 계정의 user_metadata에 저장한다. 없으면 null.
final nicknameProvider = NotifierProvider<NicknameNotifier, String?>(
  NicknameNotifier.new,
);

class NicknameNotifier extends Notifier<String?> {
  static const maxLength = 20;

  @override
  String? build() {
    final client = ref.watch(supabaseProvider);
    final subscription = client.auth.onAuthStateChange.listen(
      (auth) => state = _read(auth.session?.user),
    );
    ref.onDispose(subscription.cancel);
    return _read(client.auth.currentUser);
  }

  Future<void> save(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) {
      throw ArgumentError.value(nickname, 'nickname', '1~$maxLength자');
    }
    await ref.read(authUserProvider.future);
    final response = await ref
        .read(supabaseProvider)
        .auth
        .updateUser(UserAttributes(data: {'nickname': trimmed}));
    state = _read(response.user);
  }

  static String? _read(User? user) {
    final value = user?.userMetadata?['nickname'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }
}
