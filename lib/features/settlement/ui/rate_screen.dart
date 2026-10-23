import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/tori_card.dart';
import '../../trips/data/trip.dart';
import '../../trips/providers.dart';
import '../../trips/ui/trip_tab.dart';
import '../data/settlement.dart';
import '../providers.dart';

/// 10 정산 환율 확인. 오늘 환율(또는 직접 입력한 환율)을 확인하고 정산을 확정한다.
///
/// 원화 여행은 환율 없이 총액만 확인한다.
class RateScreen extends ConsumerWidget {
  const RateScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDetailProvider(tripId));
    final balances = ref.watch(balancesProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('정산 환율 확인')),
      body: switch ((trip.value, balances.value)) {
        (final trip?, final balances?) => _RateForm(
          trip: trip,
          balances: balances,
        ),
        _ => AsyncView(
          value: trip.hasError ? trip : balances,
          onRetry: () => ref
            ..invalidate(tripDetailProvider(tripId))
            ..invalidate(balancesProvider(tripId)),
          errorTitle: '정산할 지출을 불러오지 못했어요',
          data: (_) => const SizedBox.shrink(),
        ),
      },
    );
  }
}

/// 환율 고르기(오늘 환율 · 직접 입력), 총액, 확정 버튼.
class _RateForm extends ConsumerStatefulWidget {
  const _RateForm({required this.trip, required this.balances});

  final TripDetail trip;
  final TripBalances balances;

  @override
  ConsumerState<_RateForm> createState() => _RateFormState();
}

class _RateFormState extends ConsumerState<_RateForm> {
  final _manualInput = TextEditingController();

  /// 환율 직접 입력칸을 열었는가.
  var _manual = false;
  var _saving = false;

  @override
  void dispose() {
    _manualInput.dispose();
    super.dispose();
  }

  void _close() => context.popOrGo(Routes.trip(widget.trip.id));

  /// 직접 입력한 환율 (엔화는 100엔 기준). 올바르지 않으면 null.
  ExchangeRate? _manualRate() {
    final won = Decimal.tryParse(_manualInput.text.replaceAll(',', ''));
    if (won == null || won <= Decimal.zero) return null;
    return ExchangeRate.quoted(
      widget.trip.currency,
      won,
      ref.read(todayProvider),
    );
  }

  Future<void> _confirm(ExchangeRate rate) async {
    if (_saving) return;
    setState(() => _saving = true);
    final trip = widget.trip;
    try {
      await ref
          .read(settlementActionsProvider)
          .confirm(trip, widget.balances, rate);
      if (mounted) context.go(Routes.trip(trip.id, tab: TripTab.settle));
    } catch (e) {
      debugPrint('정산 확정 실패: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showMessage(
        e is ExpensesChangedDuringSettlement
            ? '그사이 지출이 바뀌었어요. 총액을 다시 확인하고 정산해 주세요'
            : '정산하지 못했어요. $retryHint',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.trip.currency;
    final AsyncValue<ExchangeRate> latest = local == Currency.krw
        ? AsyncData(ExchangeRate.won(ref.watch(todayProvider)))
        : ref.watch(latestRateProvider(local));
    final rate = _manual ? _manualRate() : latest.value;
    final isWonTrip = local == Currency.krw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            children: [
              if (isWonTrip)
                const _RateCard(title: '원화 여행', headline: '환율 없이 바로 정산해요')
              else ...[
                _manual ? _manualCard(local) : _latestCard(latest, local),
                const SizedBox(height: 8),
                _Hint(
                  _manual
                      ? '실제로 환전한 환율 등 원하는 환율로 정산할 수 있어요.'
                      : '주말·공휴일에는 직전 영업일 환율이 적용돼요.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _manual = !_manual),
                    child: Text(_manual ? '오늘 환율로 정산하기' : '환율 직접 입력하기'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _Totals(balances: widget.balances, rate: rate),
              const SizedBox(height: 16),
              const _Hint(
                '확정하면 친구들 모두 이 환율로 정산 결과를 보게 돼요. '
                '이후 지출을 고치면 다시 정산할 수 있어요.',
              ),
            ],
          ),
        ),
        BottomActions(
          children: [
            FilledButton(
              onPressed: rate == null || _saving ? null : () => _confirm(rate),
              child: Text(
                _saving ? '정산하는 중…' : (isWonTrip ? '정산하기' : '이 환율로 정산하기'),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _close,
              child: const Text('취소'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _latestCard(AsyncValue<ExchangeRate> latest, Currency currency) {
    return switch (latest) {
      AsyncValue(:final value?) => _RateCard(
        title: '오늘 환율',
        headline: value.label,
        caption: '${formatLongDate(value.date)} 기준 · 유럽중앙은행 고시',
      ),
      AsyncValue(hasError: true) => _RateCard(
        title: '오늘 환율',
        headline: '환율을 불러오지 못했어요',
        caption: '다시 시도하거나 환율을 직접 입력해 주세요',
        action: FilledButton.tonal(
          onPressed: () => ref.invalidate(latestRateProvider(currency)),
          child: const Text('다시 시도'),
        ),
      ),
      _ => const _RateCard(title: '오늘 환율', headline: '불러오는 중…'),
    };
  }

  Widget _manualCard(Currency currency) {
    return _RateCard(
      title: '직접 입력한 환율',
      headline: null,
      action: TextField(
        controller: _manualInput,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          prefixText: '${currency.withUnit('${currency.rateQuoteUnit}')} = ',
          suffixText: '원',
          hintText: '예: 192.35',
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.title,
    required this.headline,
    this.caption,
    this.action,
  });

  final String title;
  final String? headline;
  final String? caption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: ToriColors.accentSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ToriColors.accent,
            ),
          ),
          if (headline != null)
            Text(
              headline!,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          if (caption != null)
            Text(
              caption!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: ToriColors.textMuted),
            ),
          ?action,
        ],
      ),
    );
  }
}

/// 통화별 지출과 원화로 합친 정산 총액.
class _Totals extends StatelessWidget {
  const _Totals({required this.balances, required this.rate});

  final TripBalances balances;
  final ExchangeRate? rate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rate = this.rate;
    final isWonTrip = balances.local == Currency.krw;

    Widget row(String label, String? sub, String value, {bool total = false}) =>
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: total ? 64 : 60),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      label,
                      style: total
                          ? text.titleMedium
                          : text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                    if (sub != null) Text(sub, style: text.bodySmall),
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: total ? 20 : 16,
                  fontWeight: total ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    return ToriCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        children: [
          for (final MapEntry(key: c, value: total)
              in balances.totals.entries) ...[
            if (c == Currency.krw)
              row(
                '원화 지출',
                isWonTrip ? null : '환율 적용 안 함',
                formatMoney(total, c),
              )
            else
              row(
                '${c.unit} 지출',
                formatMoney(total, c),
                rate == null ? '-' : formatApproxWon(rate.toKrw(total)),
              ),
            const Divider(height: 1),
          ],
          row('정산할 총액', null, switch (rate) {
            null => '-',
            _ when isWonTrip => formatMoney(
              balances.totals[Currency.krw] ?? 0,
              Currency.krw,
            ),
            final rate => formatApproxWon(balances.totalInKrw(rate)),
          }, total: true),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.55),
      ),
    );
  }
}
