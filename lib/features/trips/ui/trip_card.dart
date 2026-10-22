import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/date_range_text.dart';
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
                  _Pill(
                    '${trip.currency.code} ${trip.currency.label}',
                    background: ToriColors.accentSoft,
                    foreground: ToriColors.accent,
                  ),
                  const Spacer(),
                  if (trip.settled)
                    const _Pill(
                      '정산 완료',
                      background: Color(0xFFEFEBE5),
                      foreground: ToriColors.textMuted,
                    )
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

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
