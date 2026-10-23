import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import 'data/trip.dart';
import 'data/trips_repository.dart';
import 'ui/trip_draft.dart';

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(supabaseProvider)),
);

/// 오늘 날짜. 테스트에서 고정할 수 있게 provider로 둔다.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

/// 내 여행 목록. 로그인이 끝난 뒤에 불러온다.
final myTripsProvider = FutureProvider<List<TripSummary>>((ref) async {
  await ref.watch(authUserProvider.future);
  return ref.watch(tripsRepositoryProvider).myTrips();
});

/// 여행 하나(멤버·정산 상태 포함). 친구가 정산하거나 송금 완료를 체크하면 다시 불러온다.
final tripDetailProvider = FutureProvider.autoDispose
    .family<TripDetail, String>((ref, tripId) async {
      ref.watch(tripChangesProvider(tripId));
      await ref.watch(authUserProvider.future);
      return ref.watch(tripsRepositoryProvider).tripDetail(tripId);
    });

/// 친구들이 이 여행을 바꾼 횟수 (Supabase Realtime).
/// - `all`: 무엇이든 바뀌면(지출, 정산, 송금 완료) 오른다
/// - `expenses`: 지출이 바뀔 때만 오른다 (송금 완료 체크로 지출 목록까지 다시 불러오지 않게)
///
/// watch하는 provider는 바뀔 때마다 다시 불러온다. 아무도 watch하지 않으면 구독을 끝낸다.
final tripChangesProvider = NotifierProvider.autoDispose
    .family<TripChanges, ({int all, int expenses}), String>(TripChanges.new);

class TripChanges extends Notifier<({int all, int expenses})> {
  TripChanges(this.tripId);

  final String tripId;

  @override
  ({int all, int expenses}) build() {
    final stop = ref.watch(tripsRepositoryProvider).watchChanges(tripId, ({
      required expenses,
    }) {
      state = (
        all: state.all + 1,
        expenses: state.expenses + (expenses ? 1 : 0),
      );
    });
    ref.onDispose(stop);
    return (all: 0, expenses: 0);
  }
}

/// 여행 쓰기 작업. 화면이 아니라 provider의 ref를 써서, 저장 도중 화면이 닫혀도
/// 목록 새로고침까지 끝까지 한다.
final tripActionsProvider = Provider<TripActions>(TripActions.new);

class TripActions {
  TripActions(this._ref);

  final Ref _ref;

  /// 여행을 만들고 id를 돌려준다. 끝나면 홈 목록을 다시 불러온다.
  Future<String> create(TripDraft draft, {required String myName}) async {
    await _ref.read(authUserProvider.future);
    final id = await _ref
        .read(tripsRepositoryProvider)
        .createTrip(
          name: draft.name.trim(),
          startDate: draft.startDate!,
          endDate: draft.endDate!,
          currency: draft.currency!,
          myName: myName,
          friendNames: List.of(draft.friends),
        );
    _ref.invalidate(myTripsProvider);
    return id;
  }

  /// 목록을 다시 불러온다. 로그인이 실패해 있었다면 로그인부터 다시 한다.
  void reloadTrips() {
    if (_ref.read(authUserProvider).hasError) _ref.invalidate(authUserProvider);
    _ref.invalidate(myTripsProvider);
  }
}
