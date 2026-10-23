import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/exchange_rate/exchange_rate.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../shared/dates.dart';
import '../../../shared/messages.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/notice_box.dart';
import '../../../shared/widgets/pill.dart';
import '../../../shared/widgets/tori_card.dart';
import '../../../shared/widgets/tori_mascot.dart';
import '../../trips/data/trip.dart';
import '../data/settlement.dart';
import '../providers.dart';

/// 11 정산 탭. 정산 전이면 시작 안내, 확정했으면 송금 목록과 완료 체크.
class SettleTab extends ConsumerWidget {
  const SettleTab({super.key, required this.trip, required this.me});

  final TripDetail trip;
  final Member? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = trip.settledRate;
    if (rate == null || trip.settlementStale) return _NotSettled(trip: trip);
    final transfers = ref.watch(transfersProvider(trip.id));
    return AsyncView(
      value: transfers,
      onRetry: () => ref.invalidate(transfersProvider(trip.id)),
      errorTitle: '송금 목록을 불러오지 못했어요',
      data: (transfers) =>
          _Transfers(trip: trip, me: me, rate: rate, transfers: transfers),
    );
  }
}

class _NotSettled extends ConsumerWidget {
  const _NotSettled({required this.trip});

  final TripDetail trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final hasExpenses =
        !(ref.watch(balancesProvider(trip.id)).value?.isEmpty ?? true);
    final local = trip.currency;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (trip.settlementStale)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: NoticeBox.warning('지출이 바뀌었어요. 정산을 다시 해주세요.'),
          ),
        ToriCard(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          child: Column(
            spacing: 10,
            children: [
              const ToriMascot(),
              Text('여행이 끝났나요?', style: text.titleLarge?.copyWith(fontSize: 19)),
              Text(
                local == Currency.krw
                    ? '모든 지출을 모아서\n누가 누구에게 얼마를 보낼지 정리해요.'
                    : '정산하는 날의 환율 하나로\n모든 ${local.unit} 지출을 원화로 바꿔서 나눠요.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.6,
                  color: ToriColors.textSub,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: hasExpenses
                      ? () => context.push(Routes.rate(trip.id))
                      : null,
                  child: Text(hasExpenses ? '정산 시작하기' : '지출을 먼저 추가해주세요'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transfers extends ConsumerWidget {
  const _Transfers({
    required this.trip,
    required this.me,
    required this.rate,
    required this.transfers,
  });

  final TripDetail trip;
  final Member? me;
  final ExchangeRate rate;
  final List<SettlementTransfer> transfers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final doneCount = transfers.where((t) => t.done).length;
    final allDone = transfers.isNotEmpty && doneCount == transfers.length;
    String name(String id) => trip.memberById(id)?.name ?? '알 수 없음';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (transfers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              spacing: 10,
              children: [
                const ToriMascot(face: ToriFace.smile),
                Text('보낼 돈이 없어요', style: text.titleMedium),
                Text(
                  '모두 똑같이 냈어요',
                  style: text.bodySmall?.copyWith(fontSize: 14),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '송금 ${transfers.length}건이면 끝나요',
                  style: text.titleMedium,
                ),
              ),
              Text(
                '$doneCount / ${transfers.length} 완료',
                style: text.labelLarge?.copyWith(color: ToriColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: doneCount / transfers.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: ToriColors.cardBorder,
          ),
          const SizedBox(height: 14),
          for (final t in transfers)
            _TransferCard(
              transfer: t,
              from: name(t.from),
              to: name(t.to),
              role: switch (me?.id) {
                final id? when id == t.from => '내가 보낼 돈',
                final id? when id == t.to => '내가 받을 돈',
                _ => null,
              },
              approx: rate.isWon ? null : _approxLocal(t.amountKrw, rate),
              onToggle: () => _toggle(context, ref, t),
            ),
        ],
        if (allDone || transfers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton(
              onPressed: () => context.push(Routes.settled(trip.id)),
              child: const Text('정산 끝내기'),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          [
            if (!rate.isWon) '${rate.label} (${formatLongDate(rate.date)} 기준)',
            '송금 금액은 10원 단위로 반올림했어요',
          ].join('\n'),
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(fontSize: 12, height: 1.6),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.push(Routes.rate(trip.id)),
            child: const Text(
              '정산 다시 하기',
              style: TextStyle(
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    SettlementTransfer t,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(settlementActionsProvider)
          .setDone(trip.id, t.id, done: !t.done);
    } catch (e) {
      debugPrint('송금 완료 체크 실패: $e');
      messenger.showMessage('저장하지 못했어요. $retryHint');
    }
  }

  /// 원화 송금액을 현지 통화로 대강 바꾼다: `≈ 2,953.03위안`
  static String _approxLocal(int krw, ExchangeRate rate) {
    final major = (Decimal.fromInt(krw) / rate.krwPerUnit).toDecimal(
      scaleOnInfinitePrecision: 4,
    );
    return '≈ ${formatMoney(rate.currency.toMinor(major), rate.currency)}';
  }
}

class _TransferCard extends StatefulWidget {
  const _TransferCard({
    required this.transfer,
    required this.from,
    required this.to,
    required this.role,
    required this.approx,
    required this.onToggle,
  });

  final SettlementTransfer transfer;
  final String from;
  final String to;

  /// 내가 보내거나 받는 송금이면 '내가 보낼 돈' · '내가 받을 돈'
  final String? role;

  /// 현지 통화 환산 (원화 여행이면 null)
  final String? approx;

  /// 송금 완료 체크를 바꾼다. 끝날 때까지 버튼을 끈다.
  final Future<void> Function() onToggle;

  @override
  State<_TransferCard> createState() => _TransferCardState();
}

class _TransferCardState extends State<_TransferCard> {
  var _busy = false;

  /// 빠르게 두 번 눌러 체크·해제가 엇갈려 저장되지 않게 하나씩만 보낸다.
  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onToggle();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _TransferCard(:transfer, :from, :to, :role, :approx) = widget;
    final done = transfer.done;
    final onToggle = _busy ? null : _toggle;
    final name = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontWeight: FontWeight.w700);
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ToriCard(
          padding: const EdgeInsets.all(18),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 8,
                children: [
                  // 이름은 왼쪽, 남는 폭은 모두 여기로 (배지는 오른쪽 끝)
                  Expanded(
                    child: Row(
                      spacing: 6,
                      children: [
                        Flexible(child: Text(from, style: name)),
                        const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: ToriColors.textSub,
                        ),
                        Flexible(child: Text(to, style: name)),
                      ],
                    ),
                  ),
                  if (role != null) Pill(role),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    formatMoney(transfer.amountKrw, Currency.krw),
                    style: amountLargeStyle,
                  ),
                  if (approx != null) Text(approx, style: text.bodySmall),
                ],
              ),
              done
                  ? OutlinedButton(
                      onPressed: onToggle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: ToriColors.accent,
                        side: const BorderSide(color: ToriColors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('송금 완료됨'),
                    )
                  : FilledButton(
                      onPressed: onToggle,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('송금 완료'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
