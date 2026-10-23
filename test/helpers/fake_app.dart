import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/exchange_rate/exchange_rate.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/money/settlement.dart';
import 'package:tori/core/supabase/supabase_client.dart';
import 'package:tori/features/expenses/data/expense.dart';
import 'package:tori/features/expenses/data/expenses_repository.dart';
import 'package:tori/features/expenses/providers.dart';
import 'package:tori/features/invite/data/invite_repository.dart';
import 'package:tori/features/invite/providers.dart';
import 'package:tori/features/onboarding/providers.dart';
import 'package:tori/features/settlement/data/settlement.dart';
import 'package:tori/features/settlement/data/settlement_repository.dart';
import 'package:tori/features/settlement/providers.dart';
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

/// 여행 저장소 가짜. [emitChange]로 친구가 지출을 바꾼 것처럼 실시간 알림을 보낸다.
class FakeTripsRepository implements TripsRepository {
  FakeTripsRepository({List<TripSummary>? trips}) : trips = trips ?? [];

  final List<TripSummary> trips;
  final created = <CreatedTrip>[];

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  /// 여행방 't1'의 현지 통화와 정산 상태.
  Currency currency = Currency.cny;
  ExchangeRate? settledRate;
  bool settlementStale = false;

  final _listeners = <void Function({required bool expenses})>[];

  /// 지금 실시간 구독 중인 곳 수.
  int get watching => _listeners.length;

  /// 친구가 여행을 바꾼 것처럼 실시간 알림을 보낸다. 송금 완료 체크만이면 `expenses: false`.
  void emitChange({bool expenses = true}) {
    for (final listener in List.of(_listeners)) {
      listener(expenses: expenses);
    }
  }

  @override
  void Function() watchChanges(
    String tripId,
    void Function({required bool expenses}) onChange,
  ) {
    _listeners.add(onChange);
    return () => _listeners.remove(onChange);
  }

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
      currency: currency,
      inviteCode: 'TR7K2QAB',
      settledRate: settledRate,
      settlementStale: settlementStale,
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

/// 지출 저장소 가짜.
class FakeExpensesRepository implements ExpensesRepository {
  FakeExpensesRepository({List<Expense>? expenses}) : expenses = expenses ?? [];

  /// 저장소에 있는 지출 (화면에 보일 순서대로).
  final List<Expense> expenses;
  final saved = <SavedExpense>[];
  final deleted = <String>[];

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  /// 지출 버전 (trips.expenses_changed_at). 바꾸면 그 전 버전으로 한 정산 확정은 거절된다.
  String version = '2026-11-07T00:00:00+00:00';

  /// 지출 목록을 불러온 횟수.
  var listCalls = 0;

  @override
  Future<TripExpenses> list(String tripId) async {
    listCalls++;
    if (failWith != null) throw failWith!;
    return TripExpenses(List.of(expenses), version: version);
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
      throw const ExpenseNotFound();
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

/// 정산 저장소 가짜. 확정하면 [trips]의 여행 't1'이 정산된 상태가 된다.
/// [expenses]의 지출 버전과 다른 버전으로 확정하면 거절한다.
class FakeSettlementRepository implements SettlementRepository {
  FakeSettlementRepository(this.trips, this.expenses);

  final FakeTripsRepository trips;
  final FakeExpensesRepository expenses;

  /// 저장소에 있는 송금 목록.
  final saved = <SettlementTransfer>[];
  final confirmed = <(ExchangeRate rate, List<Transfer> transfers)>[];

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  @override
  Future<List<SettlementTransfer>> transfers(String tripId) async {
    if (failWith != null) throw failWith!;
    return List.of(saved);
  }

  @override
  Future<void> confirm(
    String tripId, {
    required String expensesVersion,
    required ExchangeRate rate,
    required List<Transfer> transfers,
  }) async {
    if (failWith != null) throw failWith!;
    if (expensesVersion != expenses.version) {
      throw const ExpensesChangedDuringSettlement();
    }
    final plan = transfers;
    confirmed.add((rate, plan));
    trips
      ..settledRate = rate
      ..settlementStale = false;
    saved
      ..clear()
      ..addAll([
        for (final (i, t) in plan.indexed)
          SettlementTransfer(
            id: 's$i',
            from: t.from,
            to: t.to,
            amountKrw: t.amountKrw,
            done: false,
          ),
      ]);
  }

  /// 송금 완료 체크를 바꾼 횟수.
  var setDoneCalls = 0;

  @override
  Future<void> setDone(String transferId, {required bool done}) async {
    setDoneCalls++;
    if (failWith != null) throw failWith!;
    final i = saved.indexWhere((t) => t.id == transferId);
    final t = saved[i];
    saved[i] = SettlementTransfer(
      id: t.id,
      from: t.from,
      to: t.to,
      amountKrw: t.amountKrw,
      done: done,
    );
  }
}

/// 테스트의 오늘 환율: 1위안 = 192.35원 (2026-11-09 기준).
final sampleRate = ExchangeRate(
  currency: Currency.cny,
  krwPerUnit: Decimal.parse('192.35'),
  date: DateTime(2026, 11, 9),
);

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
/// 오늘 환율은 [sampleRate]. [rateError]를 주면 환율을 못 불러온다.
/// 다른 가짜가 필요하면 [overrides]로 넘긴다.
Future<void> pumpApp(
  WidgetTester tester, {
  String? location,
  String? nickname = '민지',
  FakeTripsRepository? repository,
  FakeInviteRepository? invites,
  FakeExpensesRepository? expenses,
  FakeSettlementRepository? settlements,
  Object? rateError,
  List<Override> overrides = const [],
}) async {
  final repo = repository ?? FakeTripsRepository();
  final expenseRepo = expenses ?? FakeExpensesRepository();
  final container = ProviderContainer(
    // 실패한 provider를 저절로 다시 시도하지 않는다 (테스트가 끝난 뒤 타이머가 남지 않게)
    retry: (_, _) => null,
    overrides: [
      nicknameProvider.overrideWith(() => FakeNickname(nickname)),
      authUserProvider.overrideWith((ref) => fakeUser),
      tripsRepositoryProvider.overrideWithValue(repo),
      inviteRepositoryProvider.overrideWithValue(
        invites ?? FakeInviteRepository(),
      ),
      expensesRepositoryProvider.overrideWithValue(expenseRepo),
      settlementRepositoryProvider.overrideWithValue(
        settlements ?? FakeSettlementRepository(repo, expenseRepo),
      ),
      latestRateProvider.overrideWith((ref, currency) async {
        if (rateError != null) throw rateError;
        return currency == Currency.cny
            ? sampleRate
            : throw UnimplementedError('테스트 환율은 위안만');
      }),
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

/// 휴대폰 크기(390×844)로 띄운다. 테스트가 끝나면 되돌린다.
void usePhoneSize(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 가짜 여행 't1'의 여행방 화면인가 (제목이 여행 이름).
Finder get inTripRoom => appBarTitle('상하이 우정여행');

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// 글자를 눌러 한 프레임 그린다 (스크롤 안쪽이면 먼저 보이게 한다).
/// 같은 글자가 여럿이면 마지막 것.
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pump();
}

Future<void> tapButton<T extends Widget>(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.widgetWithText(T, label));
  await tester.pumpAndSettle();
}
