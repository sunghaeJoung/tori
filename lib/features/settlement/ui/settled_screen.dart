import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/settlement.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/tori_mascot.dart';
import '../../trips/providers.dart';
import '../providers.dart';

/// 12 정산 끝. 송금을 모두 마치면 보여주는 축하 화면.
class SettledScreen extends ConsumerWidget {
  const SettledScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDetailProvider(tripId)).value;
    final balances = ref.watch(balancesProvider(tripId)).value;
    final rate = trip?.settledRate;
    final text = Theme.of(context).textTheme;
    final total = trip == null || balances == null || rate == null
        ? null
        : formatMoney(
            roundTo10Won(balances.totalInKrw(trip.currency, rate.krwPerUnit)),
            Currency.krw,
          );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: ToriColors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const ToriMascot(size: 120, face: ToriFace.smile),
                ),
                Text(
                  '정산 끝!',
                  style: text.headlineMedium?.copyWith(fontSize: 32),
                ),
                if (trip != null && total != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${trip.name}에서 ${trip.members.length}명이 함께 쓴\n',
                        ),
                        TextSpan(
                          text: trip.currency == Currency.krw
                              ? total
                              : '약 $total',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ToriColors.text,
                          ),
                        ),
                        const TextSpan(text: '을 모두 나눴어요.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      height: 1.65,
                      color: ToriColors.textMuted,
                    ),
                  ),
                Text(
                  '다음 여행에서 또 만나요',
                  style: text.bodySmall?.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('홈으로'),
          ),
        ],
      ),
    );
  }
}
