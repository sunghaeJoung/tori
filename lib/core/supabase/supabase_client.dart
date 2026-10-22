import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `--dart-define-from-file=env/dev.json`으로 주입하는 Supabase 설정.
///
/// 웹 번들에 들어가므로 공개용(publishable/anon) 키만 넣는다.
abstract final class SupabaseEnv {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
}

Future<void> initSupabase() async {
  if (SupabaseEnv.url.isEmpty || SupabaseEnv.publishableKey.isEmpty) {
    throw StateError(
      'Supabase 설정이 없다. '
      'flutter run -d chrome --dart-define-from-file=env/dev.json 으로 실행할 것',
    );
  }
  await Supabase.initialize(
    url: SupabaseEnv.url,
    publishableKey: SupabaseEnv.publishableKey,
  );
}

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// 로그인한 사용자. 세션이 없으면 익명으로 로그인한다.
///
/// 실패하면(네트워크 등) 에러 상태가 되고, `ref.invalidate(authUserProvider)`로 다시 시도한다.
/// 로그아웃되면(세션 만료·삭제) 스스로 다시 로그인한다.
final authUserProvider = FutureProvider<User>((ref) {
  final client = ref.watch(supabaseProvider);
  final subscription = client.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedOut) ref.invalidateSelf();
  });
  ref.onDispose(subscription.cancel);
  return ensureSignedIn(client).timeout(const Duration(seconds: 10));
});

Future<User>? _pendingSignIn;

/// 익명 세션은 브라우저에 저장되므로 같은 브라우저에서는 계속 같은 사용자다.
/// 네트워크는 처음 한 번만 쓴다.
///
/// 이미 로그인 중이면 그 요청을 같이 기다린다. 시간 초과 뒤 다시 시도해도
/// 익명 사용자가 둘 생기지 않게 하기 위해서다.
Future<User> ensureSignedIn(SupabaseClient client) {
  final user = client.auth.currentUser;
  if (user != null) return Future.value(user);
  return _pendingSignIn ??= client.auth
      .signInAnonymously()
      .then((response) => response.user!)
      .whenComplete(() => _pendingSignIn = null);
}
