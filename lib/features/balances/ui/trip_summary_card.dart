import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/exchange_rate/exchange_rate.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/tori_card.dart';
import '../../settlement/data/settlement.dart';
import '../../settlement/providers.dart';
import '../../trips/data/trip.dart';
import 'balance_label.dart';

/// 07 여행방 위쪽 카드: 총 지출과 내 잔액.
///
/// 원화로 바꿀 환율(오늘 환율·정산 환율)이 있으면 "약 ○○원"으로 합쳐서,
/// 원화 여행이면 정확한 원화로, 환율을 못 불러오면 통화별로 보여준다.
class TripSummaryCard extends ConsumerWidget {
  const TripSummaryCard({super.key, required this.trip, required this.me});

  final TripDetail trip;
  final Member? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesProvider(trip.id)).value;
    if (balances == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final rate = ref.watch(referenceRateProvider(trip.id)).value;
    // 원화로 "약" 환산해서 보여줄 환율. 원화 여행은 바꿀 게 없다
    final approxRate = rate == null || rate.isWon ? null : rate;

    final breakdown = balances.isEmpty
        ? formatMoney(0, trip.currency)
        : balances.totals.entries
              .map((t) => formatMoney(t.value, t.key))
              .join(' + ');
    final (title, headline) = approxRate == null
        ? ('총 지출', breakdown)
        : (
            trip.settled ? '총 지출 (정산 환율 기준)' : '총 지출 (오늘 환율 기준)',
            formatApproxWon(balances.totalInKrw(approxRate)),
          );

    return ToriCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(title, style: text.bodySmall),
          Text(headline, style: amountLargeStyle),
          if (approxRate != null)
            Text(
              breakdown,
              style: text.bodySmall?.copyWith(color: ToriColors.textMuted),
            ),
          if (me case final me? when !balances.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approxRate == null ? '내 잔액' : '내 잔액 (약)',
                  style: text.bodyMedium?.copyWith(color: ToriColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _MyBalance(balances: balances, me: me, rate: rate),
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

class _MyBalance extends StatelessWidget {
  const _MyBalance({
    required this.balances,
    required this.me,
    required this.rate,
  });

  final TripBalances balances;
  final Member me;
  final ExchangeRate? rate;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    // 환율이 있으면 원화 하나로, 없으면 통화별로
    final rate = this.rate;
    if (rate == null) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          for (final MapEntry(key: c, value: byMember)
              in balances.byCurrency.entries)
            MoneyText(byMember[me.id]!, c, balance: true, style: style),
        ],
      );
    }
    final won = balances.display(rate).amounts[me.id]!;
    final look = balanceLook(won);
    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        MoneyText(won, Currency.krw, balance: true, style: style),
        Text(' · ${look.label}', style: style.copyWith(color: look.color)),
      ],
    );
  }
}
