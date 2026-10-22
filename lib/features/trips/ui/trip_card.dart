import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/dates.dart';
import '../../../shared/widgets/pill.dart';
import '../data/trips_repository.dart';

/// 홈의 여행 카드.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onTap});

  final TripSummary trip;
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
                  if (trip.settled)
                    const Pill.muted('정산 완료')
                  else
                    Text(
                      '여행 중',
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
}
