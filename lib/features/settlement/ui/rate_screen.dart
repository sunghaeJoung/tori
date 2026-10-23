import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/exchange_rate/frankfurter_api.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/settlement.dart';
import '../../../shared/dates.dart';
import '../../../shared/messages.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../trips/data/trip.dart';
import '../../trips/providers.dart';
import '../data/settlement.dart';
import '../providers.dart';

/// 10 정산 환율 확인. 오늘 환율(또는 직접 입력한 환율)을 확인하고 정산을 확정한다.
///
/// 원화 여행은 환율 없이 총액만 확인한다.
class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  final _manualInput = TextEditingController();

  /// 환율 직접 입력칸을 열었는가.
  var _manual = false;
  var _saving = false;

  @override
  void dispose() {
    _manualInput.dispose();
    super.dispose();
  }

  void _close() => context.popOrGo(Routes.trip(widget.tripId));

  /// 직접 입력한 환율. 엔화는 100엔 기준으로 입력받는다. 올바르지 않으면 null.
  ExchangeRate? _manualRate(Currency currency) {
    final value = Decimal.tryParse(_manualInput.text.replaceAll(',', ''));
    if (value == null || value <= Decimal.zero) return null;
    final perUnit =
        (value / Decimal.fromInt(ExchangeRate.inputUnitOf(currency))).toDecimal(
          scaleOnInfinitePrecision: 10,
        );
    return ExchangeRate(
      currency: currency,
      krwPerUnit: perUnit,
      date: DateUtils.dateOnly(ref.read(todayProvider)),
    );
  }

  Future<void> _confirm(
    TripDetail trip,
    TripBalances balances,
    ExchangeRate rate,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(settlementActionsProvider).confirm(trip, balances, rate);
      if (mounted) context.go(Routes.trip(trip.id, tab: TripTab.settle));
    } catch (e) {
      debugPrint('정산 확정 실패: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showMessage('정산하지 못했어요. $retryHint');
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripDetailProvider(widget.tripId));
    final balances = ref.watch(balancesProvider(widget.tripId));
    final local = trip.value?.currency;
    final isWonTrip = local == Currency.krw;
    final latest = local == null || isWonTrip
        ? null
        : ref.watch(latestRateProvider(local));
    final ExchangeRate? rate = switch (local) {
      null => null,
      Currency.krw => wonRate(DateUtils.dateOnly(ref.watch(todayProvider))),
      _ when _manual => _manualRate(local),
      _ => latest?.value,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _saving ? null : _close,
        ),
        title: const Text('정산 환율 확인'),
      ),
      body: AsyncView(
        value: trip,
        onRetry: () => ref.invalidate(tripDetailProvider(widget.tripId)),
        errorTitle: '여행을 불러오지 못했어요',
        data: (trip) => AsyncView(
          value: balances,
          onRetry: () => ref.invalidate(balancesProvider(widget.tripId)),
          errorTitle: '지출을 불러오지 못했어요',
          data: (balances) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            children: [
              if (isWonTrip)
                const _RateCard(title: '원화 여행', headline: '환율 없이 바로 정산해요')
              else ...[
                _manual
                    ? _manualCard(trip.currency)
                    : _latestCard(latest!, trip.currency),
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
              _Totals(balances: balances, local: trip.currency, rate: rate),
              const SizedBox(height: 16),
              const _Hint(
                '확정하면 친구들 모두 이 환율로 정산 결과를 보게 돼요. '
                '이후 지출을 고치면 다시 정산할 수 있어요.',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton(
            onPressed:
                rate == null || _saving || !trip.hasValue || !balances.hasValue
                ? null
                : () =>
                      _confirm(trip.requireValue, balances.requireValue, rate),
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
    final unit = ExchangeRate.inputUnitOf(currency);
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
          prefixText: '${currency.withUnit('$unit')} = ',
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
  const _Totals({
    required this.balances,
    required this.local,
    required this.rate,
  });

  final TripBalances balances;
  final Currency local;
  final ExchangeRate? rate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rate = this.rate;
    String approxWon(Decimal won) =>
        '약 ${formatMoney(roundTo10Won(won), Currency.krw)}';

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: ToriColors.surface,
        border: Border.all(color: ToriColors.cardBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (final MapEntry(key: c, value: total)
              in balances.totals.entries) ...[
            if (c == Currency.krw)
              row(
                '원화 지출',
                local == Currency.krw ? null : '환율 적용 안 함',
                formatMoney(total, c),
              )
            else
              row(
                '${c.unit} 지출',
                formatMoney(total, c),
                rate == null
                    ? '-'
                    : approxWon(c.toMajor(total) * rate.krwPerUnit),
              ),
            const Divider(height: 1),
          ],
          row(
            '정산할 총액',
            null,
            rate == null
                ? '-'
                : local == Currency.krw
                ? formatMoney(balances.totals[Currency.krw] ?? 0, Currency.krw)
                : approxWon(balances.totalInKrw(local, rate.krwPerUnit)),
            total: true,
          ),
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
