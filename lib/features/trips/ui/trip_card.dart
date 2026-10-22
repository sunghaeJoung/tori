import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/dates.dart';
import '../../../shared/widgets/pill.dart';
import '../data/trips_repository.dart';

/// 홈의 여행 카드.
///
/// 오른쪽 위 표시: 여행 중 · D-9 · 정산 전 · 정산 완료
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.today,
    required this.onTap,
  });

  final TripSummary trip;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: ToriColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: ToriColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Row(
                children: [
                  Pill('${trip.currency.code} ${trip.currency.label}'),
                  const Spacer(),
                  _status(text),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    trip.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${formatDateRange(trip.startDate, trip.endDate)} · ${trip.memberCount}명',
                    style: text.bodySmall?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(TextTheme text) {
    final label = text.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    return switch (trip.phaseOn(today)) {
      TripPhase.ongoing => Text('여행 중', style: label),
      TripPhase.upcoming => Text(
        'D-${trip.daysUntilStart(today)}',
        style: label,
      ),
      TripPhase.past when trip.settled => const Pill.muted('정산 완료'),
      TripPhase.past => const Pill('정산 전'),
    };
  }
}
