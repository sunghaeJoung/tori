import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/notice_box.dart';
import '../../../shared/widgets/tori_card.dart';
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
        final (:amounts, :currency) = balances.display(rate.value);
        final largest = amounts.values.fold(
          0,
          (m, v) => v.abs() > m ? v.abs() : m,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          children: [
            if (local != Currency.krw)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: switch (rate) {
                  // 다시 불러오는 중에도 앞 환율로 환산해 보여주고 있다
                  AsyncValue(:final value?) =>
                    trip.settled
                        ? NoticeBox('정산 환율(${value.label})로 계산한 금액이에요.')
                        : NoticeBox(
                            '오늘 환율(${value.label})로 계산한 참고 금액이에요. '
                            '정확한 금액은 정산할 때 확정돼요.',
                          ),
                  AsyncError() => NoticeBox(
                    '환율을 불러오지 못해 ${local.label} 기준으로 보여줘요',
                    action: TextButton(
                      onPressed: () =>
                          ref.invalidate(latestRateProvider(local)),
                      child: const Text('다시 시도'),
                    ),
                  ),
                  _ => const NoticeBox('환율을 불러오는 중이에요'),
                },
              ),
            for (final member in trip.members)
              _BalanceRow(
                name: member.id == me?.id ? '${member.name} (나)' : member.name,
                isMe: member.id == me?.id,
                amount: amounts[member.id] ?? 0,
                currency: currency,
                ratio: largest == 0 ? 0 : (amounts[member.id] ?? 0) / largest,
                detail: [
                  for (final MapEntry(key: c, value: byMember)
                      in balances.byCurrency.entries)
                    formatSignedMoney(byMember[member.id]!, c),
                ].join(' · '),
              ),
          ],
        );
      },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ToriCard(
        padding: const EdgeInsets.all(16),
        radius: 18,
        color: isMe ? ToriColors.accentSoft : ToriColors.surface,
        borderColor: isMe ? ToriColors.accentSoft : ToriColors.cardBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: text.titleMedium)),
                MoneyText(
                  amount,
                  currency,
                  balance: true,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ToriColors.textMuted, // 0원일 때
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
