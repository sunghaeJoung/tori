import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/supabase/supabase_client.dart';
import 'package:tori/features/invite/data/invite_repository.dart';
import 'package:tori/features/invite/providers.dart';
import 'package:tori/features/onboarding/providers.dart';
import 'package:tori/features/trips/data/trip.dart';
import 'package:tori/features/trips/data/trips_repository.dart';
import 'package:tori/features/trips/providers.dart';
import 'package:tori/main.dart';

/// Supabase 없이 앱을 띄우기 위한 가짜들.

class FakeNickname extends NicknameNotifier {
  FakeNickname(this.initial);

  final String? initial;

  @override
  String? build() => initial;

  @override
  Future<void> save(String nickname) async => state = nickname.trim();
}

typedef CreatedTrip = ({
  String name,
  DateTime startDate,
  DateTime endDate,
  Currency currency,
  String myName,
  List<String> friendNames,
});

class FakeTripsRepository implements TripsRepository {
  FakeTripsRepository({List<TripSummary>? trips}) : trips = trips ?? [];

  final List<TripSummary> trips;
  final created = <CreatedTrip>[];

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  @override
  Future<List<TripSummary>> myTrips() async {
    if (failWith != null) throw failWith!;
    return trips;
  }

  @override
  Future<String> createTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required Currency currency,
    required String myName,
    required List<String> friendNames,
  }) async {
    if (failWith != null) throw failWith!;
    created.add((
      name: name,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      myName: myName,
      friendNames: List.of(friendNames),
    ));
    return 'new-trip';
  }

  @override
  Future<TripDetail> tripDetail(String id) async {
    if (failWith != null) throw failWith!;
    return TripDetail(
      id: id,
      name: created.isEmpty ? '상하이 우정여행' : created.last.name,
      startDate: DateTime(2026, 11, 6),
      endDate: DateTime(2026, 11, 9),
      currency: Currency.cny,
      inviteCode: 'TR7K2QAB',
      settled: false,
      members: [
        for (final (id, name) in sampleMembers)
          Member(id: id, name: name, userId: id == 'm1' ? fakeUser.id : null),
      ],
    );
  }
}

/// 가짜 여행 't1'의 멤버 (id, 이름). 여행방(나 = 민지)과 초대 미리보기가 함께 쓴다.
const sampleMembers = [('m1', '민지'), ('m2', '수아'), ('m3', '지훈')];

/// 초대 코드 'ABCD2345'(여행 't1')만 있는 가짜. 다른 사용자의 시점이라 민지는 이미 들어와 있다.
class FakeInviteRepository implements InviteRepository {
  final joined = <(String code, String memberId)>[];
  Object? failWith;

  static final samplePreview = TripPreview(
    name: '상하이 우정여행',
    startDate: DateTime(2026, 11, 6),
    endDate: DateTime(2026, 11, 9),
    currency: Currency.cny,
    members: [
      for (final (id, name) in sampleMembers)
        PreviewMember(id: id, name: name, claimed: id == 'm1', isMe: false),
    ],
  );

  @override
  Future<TripPreview?> preview(String inviteCode) async {
    if (failWith != null) throw failWith!;
    return inviteCode == 'ABCD2345' ? samplePreview : null;
  }

  @override
  Future<String> claim(String inviteCode, String memberId) async {
    if (failWith != null) throw failWith!;
    joined.add((inviteCode, memberId));
    return 't1';
  }
}

final fakeUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-22T00:00:00Z',
  isAnonymous: true,
);

/// 테스트의 "오늘". sampleTrip(11/6~11/9)이 진행 중인 날.
final testToday = DateTime(2026, 11, 7, 15, 30);

TripSummary sampleTrip({
  String id = 't1',
  String name = '상하이 우정여행',
  DateTime? start,
  DateTime? end,
  bool settled = false,
}) => TripSummary(
  id: id,
  name: name,
  startDate: start ?? DateTime(2026, 11, 6),
  endDate: end ?? DateTime(2026, 11, 9),
  currency: Currency.cny,
  memberCount: 4,
  settled: settled,
);

/// 앱을 띄우고, [location]이 있으면 그 주소로 이동한다.
/// 다른 가짜가 필요하면 [overrides]로 넘긴다.
Future<void> pumpApp(
  WidgetTester tester, {
  String? location,
  String? nickname = '민지',
  FakeTripsRepository? repository,
  FakeInviteRepository? invites,
  List<Override> overrides = const [],
}) async {
  final repo = repository ?? FakeTripsRepository();
  final container = ProviderContainer(
    overrides: [
      nicknameProvider.overrideWith(() => FakeNickname(nickname)),
      authUserProvider.overrideWith((ref) => fakeUser),
      tripsRepositoryProvider.overrideWithValue(repo),
      inviteRepositoryProvider.overrideWithValue(
        invites ?? FakeInviteRepository(),
      ),
      todayProvider.overrideWithValue(testToday),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ToriApp()),
  );
  if (location != null) container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> tapButton<T extends Widget>(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.widgetWithText(T, label));
  await tester.pumpAndSettle();
}
