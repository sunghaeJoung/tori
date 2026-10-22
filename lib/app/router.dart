import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/expenses/ui/expense_form_screen.dart';
import '../features/invite/ui/invite_screen.dart';
import '../features/invite/ui/join_screen.dart';
import '../features/onboarding/providers.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/settlement/ui/rate_screen.dart';
import '../features/trips/ui/create_trip_screen.dart';
import '../features/trips/ui/home_screen.dart';
import '../features/trips/ui/trip_screen.dart';
import '../shared/widgets/empty_state.dart';

/// 앱의 경로. 화면에서 이동할 때는 문자열 대신 이걸 쓴다.
abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const newTrip = '/trips/new';
  static String trip(String tripId) => '/trips/$tripId';
  static String invite(String tripId) => '/trips/$tripId/invite';
  static String newExpense(String tripId) => '/trips/$tripId/expenses/new';
  static String expense(String tripId, String expenseId) =>
      '/trips/$tripId/expenses/$expenseId';
  static String rate(String tripId) => '/trips/$tripId/rate';
  static String join(String code) => '/join/$code';

  /// 친구에게 보내는 초대 링크(전체 주소). 지금 열린 사이트 주소를 기준으로 만든다.
  static String joinUrl(String code) => Uri.base.resolve(join(code)).toString();
}

final routerProvider = Provider<GoRouter>((ref) {
  // 닉네임이 바뀌면 redirect를 다시 판단한다.
  final nickname = ValueNotifier<String?>(ref.read(nicknameProvider));
  ref.listen(nicknameProvider, (_, next) => nickname.value = next);

  final router = GoRouter(
    refreshListenable: nickname,
    redirect: (context, state) => onboardingRedirect(state.uri, nickname.value),
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      // '/trips/:tripId'보다 먼저 둬야 'new'가 tripId로 잡히지 않는다.
      GoRoute(
        path: Routes.newTrip,
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => TripScreen(tripId: _tripId(state)),
        routes: [
          GoRoute(
            path: 'invite',
            builder: (context, state) => InviteScreen(tripId: _tripId(state)),
          ),
          GoRoute(
            path: 'expenses/new',
            builder: (context, state) =>
                ExpenseFormScreen(tripId: _tripId(state)),
          ),
          GoRoute(
            path: 'expenses/:expenseId',
            builder: (context, state) => ExpenseFormScreen(
              tripId: _tripId(state),
              expenseId: state.pathParameters['expenseId'],
            ),
          ),
          GoRoute(
            path: 'rate',
            builder: (context, state) => RateScreen(tripId: _tripId(state)),
          ),
        ],
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) =>
            JoinScreen(code: state.pathParameters['code']!),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
  ref.onDispose(() {
    router.dispose();
    nickname.dispose();
  });
  return router;
});

/// 닉네임이 없으면 첫 실행 화면으로 보내고, 저장하면 원래 가려던 곳으로 돌려보낸다.
///
/// 초대 링크(`/join/코드`)로 처음 들어온 친구도 닉네임을 정한 뒤 그 링크로 돌아간다.
String? onboardingRedirect(Uri uri, String? nickname) {
  final atOnboarding = uri.path == Routes.onboarding;
  if (nickname == null) {
    if (atOnboarding) return null;
    if (uri.path == Routes.home) return Routes.onboarding;
    return Uri(
      path: Routes.onboarding,
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (!atOnboarding) return null;
  final from = uri.queryParameters['from'];
  // 앱 안 경로만 허용한다 (`//다른사이트` 같은 외부 주소로 보내지 않게).
  final safe = from != null && from.startsWith('/') && !from.startsWith('//');
  return safe ? from : Routes.home;
}

String _tripId(GoRouterState state) => state.pathParameters['tripId']!;

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        title: '페이지를 찾을 수 없어요',
        message: '주소를 다시 확인해주세요',
        action: FilledButton(
          onPressed: () => context.go(Routes.home),
          child: const Text('홈으로'),
        ),
      ),
    );
  }
}
