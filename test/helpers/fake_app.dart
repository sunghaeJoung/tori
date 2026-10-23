import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/supabase/supabase_client.dart';
import 'package:tori/features/expenses/data/expense.dart';
import 'package:tori/features/expenses/data/expenses_repository.dart';
import 'package:tori/features/expenses/providers.dart';
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

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  /// 값이 있으면 입장(claim)만 이 에러로 실패한다.
  Object? claimFailWith;

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
    if ((failWith ?? claimFailWith) case final error?) throw error;
    joined.add((inviteCode, memberId));
    return 't1';
  }
}

typedef SavedExpense = ({
  String? expenseId,
  String title,
  int amount,
  Currency currency,
  String paidBy,
  ExpenseCategory category,
  DateTime spentAt,
  Map<String, int> shares,
});

/// 지출 저장소 가짜. [emitChange]로 친구가 바꾼 것처럼 실시간 알림을 보낸다.
class FakeExpensesRepository implements ExpensesRepository {
  FakeExpensesRepository({List<Expense>? expenses}) : expenses = expenses ?? [];

  /// 저장소에 있는 지출 (화면에 보일 순서대로).
  final List<Expense> expenses;
  final saved = <SavedExpense>[];
  final deleted = <String>[];

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  final _listeners = <void Function()>[];

  /// 지금 실시간 구독 중인 화면 수.
  int get watching => _listeners.length;

  void emitChange() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  @override
  Future<List<Expense>> list(String tripId) async {
    if (failWith != null) throw failWith!;
    return List.of(expenses);
  }

  @override
  Future<String> save({
    required String tripId,
    String? expenseId,
    required String title,
    required int amount,
    required Currency currency,
    required String paidBy,
    required ExpenseCategory category,
    required DateTime spentAt,
    required Map<String, int> shares,
  }) async {
    if (failWith != null) throw failWith!;
    final index = expenses.indexWhere((e) => e.id == expenseId);
    if (expenseId != null && index < 0) {
      throw const PostgrestException(message: '지출을 찾을 수 없다', code: 'P0002');
    }
    saved.add((
      expenseId: expenseId,
      title: title,
      amount: amount,
      currency: currency,
      paidBy: paidBy,
      category: category,
      spentAt: spentAt,
      shares: Map.of(shares),
    ));
    final expense = Expense(
      id: expenseId ?? 'new-${saved.length}',
      title: title,
      amount: amount,
      currency: currency,
      paidBy: paidBy,
      category: category,
      spentAt: spentAt,
      shares: Map.of(shares),
    );
    if (index < 0) {
      expenses.insert(0, expense);
    } else {
      expenses[index] = expense;
    }
    return expense.id;
  }

  @override
  Future<void> delete(String expenseId) async {
    if (failWith != null) throw failWith!;
    deleted.add(expenseId);
    expenses.removeWhere((e) => e.id == expenseId);
  }

  @override
  void Function() watchTrip(String tripId, void Function() onChange) {
    _listeners.add(onChange);
    return () => _listeners.remove(onChange);
  }
}

/// 여행 't1'의 지출 (최근 날짜 순). 나 = 민지(m1).
/// - 11/7 맥주 96.00위안, 지훈 결제, 민지·지훈
/// - 11/6 훠궈 저녁 680.00위안, 민지 결제, 3명
/// - 11/6 항공권 900,000원, 수아 결제, 3명
List<Expense> sampleExpenses() => [
  Expense(
    id: 'e3',
    title: '맥주',
    amount: 9600,
    currency: Currency.cny,
    paidBy: 'm3',
    category: ExpenseCategory.drink,
    spentAt: DateTime(2026, 11, 7),
    shares: const {'m1': 4800, 'm3': 4800},
  ),
  Expense(
    id: 'e1',
    title: '훠궈 저녁',
    amount: 68000,
    currency: Currency.cny,
    paidBy: 'm1',
    category: ExpenseCategory.food,
    spentAt: DateTime(2026, 11, 6),
    shares: const {'m1': 22667, 'm2': 22667, 'm3': 22666},
  ),
  Expense(
    id: 'e2',
    title: '항공권',
    amount: 900000,
    currency: Currency.krw,
    paidBy: 'm2',
    category: ExpenseCategory.transport,
    spentAt: DateTime(2026, 11, 6),
    shares: const {'m1': 300000, 'm2': 300000, 'm3': 300000},
  ),
];

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
  FakeExpensesRepository? expenses,
  List<Override> overrides = const [],
}) async {
  // 한 테스트에서 앱을 다시 띄울 때, 앞 앱의 화면을 먼저 내리고
  // 화면이 쓰던 provider 정리(0초 타이머)까지 끝낸다.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  final repo = repository ?? FakeTripsRepository();
  final container = ProviderContainer(
    overrides: [
      nicknameProvider.overrideWith(() => FakeNickname(nickname)),
      authUserProvider.overrideWith((ref) => fakeUser),
      tripsRepositoryProvider.overrideWithValue(repo),
      inviteRepositoryProvider.overrideWithValue(
        invites ?? FakeInviteRepository(),
      ),
      expensesRepositoryProvider.overrideWithValue(
        expenses ?? FakeExpensesRepository(),
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

/// 가짜 여행 't1'의 여행방 화면인가 (제목이 여행 이름).
Finder get inTripRoom => appBarTitle('상하이 우정여행');

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> tapButton<T extends Widget>(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.widgetWithText(T, label));
  await tester.pumpAndSettle();
}
