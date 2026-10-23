import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/exchange_rate/exchange_rate.dart';
import '../../core/exchange_rate/frankfurter_api.dart';
import '../../core/money/currency.dart';
import '../../core/supabase/supabase_client.dart';
import '../expenses/providers.dart';
import '../trips/data/trip.dart';
import '../trips/providers.dart';
import 'data/settlement.dart';
import 'data/settlement_repository.dart';

final frankfurterApiProvider = Provider<FrankfurterApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return FrankfurterApi(client);
});

/// 오늘(최근 영업일) 환율. 화면을 떠나면 버려서 다시 열면 새로 불러온다.
final latestRateProvider = FutureProvider.autoDispose
    .family<ExchangeRate, Currency>(
      (ref, currency) => ref.watch(frankfurterApiProvider).latest(currency),
    );

/// "약 ○○원" 표시에 쓰는 환율.
/// 정산을 확정했으면 그 환율, 원화 여행이면 1, 아니면 오늘 환율.
/// 오늘 환율을 못 불러오면 에러 상태 (화면은 통화별로 보여주고 다시 시도할 수 있다).
final referenceRateProvider = Provider.autoDispose
    .family<AsyncValue<ExchangeRate>, String>((ref, tripId) {
      final trip = ref.watch(tripDetailProvider(tripId)).value;
      if (trip == null) return const AsyncLoading();
      if (trip.settled) return AsyncData(trip.settledRate!);
      if (trip.currency == Currency.krw) {
        return AsyncData(ExchangeRate.won(ref.watch(todayProvider)));
      }
      return ref.watch(latestRateProvider(trip.currency));
    });

/// 멤버별 잔액과 총 지출.
final balancesProvider = FutureProvider.autoDispose
    .family<TripBalances, String>((ref, tripId) async {
      final (trip, expenses) = await (
        ref.watch(tripDetailProvider(tripId).future),
        ref.watch(expensesProvider(tripId).future),
      ).wait;
      return TripBalances(trip.memberIds, expenses, local: trip.currency);
    });

final settlementRepositoryProvider = Provider<SettlementRepository>(
  (ref) => SettlementRepository(ref.watch(supabaseProvider)),
);

/// 확정한 송금 목록. 친구가 완료를 체크하면 다시 불러온다.
final transfersProvider = FutureProvider.autoDispose
    .family<List<SettlementTransfer>, String>((ref, tripId) async {
      ref.watch(tripChangesProvider(tripId));
      await ref.watch(authUserProvider.future);
      return ref.watch(settlementRepositoryProvider).transfers(tripId);
    });

final settlementActionsProvider = Provider<SettlementActions>(
  SettlementActions.new,
);

class SettlementActions {
  SettlementActions(this._ref);

  final Ref _ref;

  /// [rate]로 정산을 확정한다. 송금 목록은 지금 잔액으로 계산한다.
  /// 그사이 친구가 지출을 바꿨으면 [ExpensesChangedDuringSettlement] (지출을 다시 불러온다).
  Future<void> confirm(
    TripDetail trip,
    TripBalances balances,
    ExchangeRate rate,
  ) async {
    try {
      await _ref
          .read(settlementRepositoryProvider)
          .confirm(
            trip.id,
            expensesVersion: trip.expensesVersion,
            rate: rate,
            transfers: balances.plan(rate),
          );
    } on ExpensesChangedDuringSettlement {
      // 새 지출로 다시 계산할 수 있게 불러온다
      _ref
        ..invalidate(tripDetailProvider(trip.id))
        ..invalidate(expensesProvider(trip.id));
      rethrow;
    }
    _ref
      ..invalidate(tripDetailProvider(trip.id))
      ..invalidate(transfersProvider(trip.id));
  }

  Future<void> setDone(
    String tripId,
    String transferId, {
    required bool done,
  }) async {
    await _ref
        .read(settlementRepositoryProvider)
        .setDone(transferId, done: done);
    _ref.invalidate(transfersProvider(tripId));
  }
}
