import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/settlement.dart';
import '../../../shared/widgets/money_text.dart';
import '../../settlement/providers.dart';
import '../../trips/data/trip.dart';
import 'balance_label.dart';

/// 07 여행방 위쪽 카드: 총 지출과 내 잔액.
///
/// 환율이 있으면(오늘 환율, 정산 환율, 원화 여행) 원화로 합쳐 "약 ○○원"으로,
/// 없으면 통화별로 보여준다.
class TripSummaryCard extends ConsumerWidget {
  const TripSummaryCard({super.key, required this.trip, required this.me});

  final TripDetail trip;
  final Member? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesProvider(trip.id)).value;
    if (balances == null) return const SizedBox.shrink();
    final rate = ref.watch(referenceRateProvider(trip.id)).value;
    final text = Theme.of(context).textTheme;
    final local = trip.currency;
    final isWonTrip = local == Currency.krw;

    final breakdown = balances.isEmpty
        ? formatMoney(0, local)
        : balances.totals.entries
              .map((t) => formatMoney(t.value, t.key))
              .join(' + ');
    final String title;
    final String headline;
    if (rate == null || isWonTrip) {
      title = '총 지출';
      headline = breakdown;
    } else {
      title = trip.settled ? '총 지출 (정산 환율 기준)' : '총 지출 (오늘 환율 기준)';
      headline =
          '약 ${formatMoney(roundTo10Won(balances.totalInKrw(local, rate.krwPerUnit)), Currency.krw)}';
    }

    const amountStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    Widget? myBalance;
    if (me case final me? when !balances.isEmpty) {
      if (rate != null) {
        final won = roundTo10Won(
          balances.inKrw(local, rate.krwPerUnit)[me.id]!,
        );
        final look = balanceLook(won);
        myBalance = Wrap(
          alignment: WrapAlignment.end,
          children: [
            MoneyText(won, Currency.krw, balance: true, style: amountStyle),
            Text(
              ' · ${look.label}',
              style: amountStyle.copyWith(color: look.color),
            ),
          ],
        );
      } else {
        myBalance = Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            for (final MapEntry(key: c, value: byMember)
                in balances.byCurrency.entries)
              MoneyText(byMember[me.id]!, c, balance: true, style: amountStyle),
          ],
        );
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: ToriColors.surface,
        border: Border.all(color: ToriColors.cardBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(title, style: text.bodySmall),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (headline != breakdown)
            Text(
              breakdown,
              style: text.bodySmall?.copyWith(color: ToriColors.textMuted),
            ),
          if (myBalance != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate == null || isWonTrip ? '내 잔액' : '내 잔액 (약)',
                  style: text.bodyMedium?.copyWith(color: ToriColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: myBalance,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
