import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/settlement.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../settlement/providers.dart';
import '../../trips/data/trip.dart';
import 'balance_label.dart';

/// 09 잔액 탭: 멤버별 받을 돈(파랑) · 줄 돈(빨강).
///
/// 환율이 있으면 원화로 합쳐 10원 단위로 보여주고, 없으면 현지 통화로 보여준다.
class BalancesTab extends ConsumerWidget {
  const BalancesTab({super.key, required this.trip, required this.me});

  final TripDetail trip;
  final Member? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesProvider(trip.id));
    final rate = ref.watch(referenceRateProvider(trip.id));
    return AsyncView(
      value: balances,
      onRetry: () => ref.invalidate(balancesProvider(trip.id)),
      errorTitle: '잔액을 불러오지 못했어요',
      data: (balances) {
        if (balances.isEmpty) {
          return const EmptyState(
            title: '아직 지출이 없어요',
            message: '지출을 추가하면 누가 얼마를 받고 낼지 보여줘요',
          );
        }
        final local = trip.currency;
        final krwRate = rate.value;
        // 행마다 보여줄 큰 금액: 원화 환산(10원 단위) 또는 현지 통화 잔액
        final (main, mainCurrency) = krwRate == null
            ? (balances.byCurrency[local] ?? {}, local)
            : (
                balances
                    .inKrw(local, krwRate.krwPerUnit)
                    .map((id, won) => MapEntry(id, roundTo10Won(won))),
                Currency.krw,
              );
        final largest = main.values.fold(
          0,
          (m, v) => v.abs() > m ? v.abs() : m,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            if (local != Currency.krw)
              _Note(switch (krwRate) {
                null when rate.isLoading => '환율을 불러오는 중이에요',
                null => '환율을 불러오지 못해 ${local.label} 기준으로 보여줘요',
                final r when trip.settled => '정산 환율(${r.label})로 계산한 금액이에요.',
                final r =>
                  '오늘 환율(${r.label})로 계산한 참고 금액이에요. 정확한 금액은 정산할 때 확정돼요.',
              }),
            for (final member in trip.members)
              _BalanceRow(
                name: member.id == me?.id ? '${member.name} (나)' : member.name,
                isMe: member.id == me?.id,
                amount: main[member.id] ?? 0,
                currency: mainCurrency,
                ratio: largest == 0 ? 0 : (main[member.id] ?? 0) / largest,
                detail: [
                  for (final MapEntry(key: c, value: byMember)
                      in balances.byCurrency.entries)
                    _signed(byMember[member.id]!, c),
                ].join(' · '),
              ),
          ],
        );
      },
    );
  }

  static String _signed(int amount, Currency currency) =>
      '${amount > 0 ? '+' : ''}${formatMoney(amount, currency)}';
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ToriColors.tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: ToriColors.textMuted, height: 1.55),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.name,
    required this.isMe,
    required this.amount,
    required this.currency,
    required this.ratio,
    required this.detail,
  });

  final String name;
  final bool isMe;
  final int amount;
  final Currency currency;

  /// 가장 큰 잔액 대비 크기 (-1 ~ 1). 음수면 왼쪽(빨강), 양수면 오른쪽(파랑) 막대.
  final double ratio;

  /// 통화별 잔액: `-387.88위안 · -300,000원`
  final String detail;

  @override
  Widget build(BuildContext context) {
    final look = balanceLook(amount);
    final text = Theme.of(context).textTheme;
    final main = formatMoney(amount, currency);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? ToriColors.accentSoft : ToriColors.surface,
        border: Border.all(
          color: isMe ? ToriColors.accentSoft : ToriColors.cardBorder,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: text.titleMedium)),
              Text(
                amount > 0 ? '+$main' : main,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: look.color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          // 가운데를 기준으로 줄 돈은 왼쪽, 받을 돈은 오른쪽으로 뻗는 막대
          SizedBox(
            height: 8,
            child: Row(
              spacing: 2,
              children: [
                Expanded(
                  child: _bar(
                    ratio < 0 ? -ratio : 0,
                    ToriColors.pay,
                    Alignment.centerRight,
                  ),
                ),
                Expanded(
                  child: _bar(
                    ratio > 0 ? ratio : 0,
                    ToriColors.receive,
                    Alignment.centerLeft,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: text.bodySmall?.copyWith(fontSize: 12),
                ),
              ),
              Text(
                look.label,
                style: text.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: look.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double fill, Color color, Alignment from) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: ColoredBox(
      color: ToriColors.divider,
      child: Align(
        alignment: from,
        child: FractionallySizedBox(
          widthFactor: fill,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    ),
  );
}
