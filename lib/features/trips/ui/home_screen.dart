import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/tori_mascot.dart';
import '../../../shared/widgets/tori_wordmark.dart';
import '../../onboarding/providers.dart';
import '../data/trips_repository.dart';
import '../providers.dart';
import 'trip_card.dart';

/// 02 홈. 진행 중인 여행과 지난(정산 끝난) 여행.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(nicknameProvider) ?? '';
    final trips = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        title: const Row(
          spacing: 8,
          children: [
            ToriMascot(size: 28, face: ToriFace.none),
            ToriWordmark(),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Semantics(
              label: '내 이름 $nickname',
              child: CircleAvatar(
                radius: 22,
                backgroundColor: ToriColors.accentSoft,
                foregroundColor: ToriColors.accent,
                child: Text(
                  nickname.characters.firstOrNull ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // 이미 받은 목록이 있으면 새로고침 중이거나 새로고침이 실패해도 목록을 계속 보여준다.
      body: switch (trips) {
        AsyncValue(hasValue: true, :final value?) when value.isEmpty =>
          const EmptyState(
            title: '아직 여행이 없어요',
            message: '새 여행을 만들고 친구들을 초대해보세요',
          ),
        AsyncValue(hasValue: true, :final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(myTripsProvider.future),
          child: _TripList(trips: value),
        ),
        AsyncValue(isLoading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => EmptyState(
          title: '여행을 불러오지 못했어요',
          message: '인터넷 연결을 확인해 주세요',
          action: FilledButton.tonal(
            onPressed: () => ref.read(tripActionsProvider).reloadTrips(),
            child: const Text('다시 시도'),
          ),
        ),
      },
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton.icon(
            onPressed: () => context.push(Routes.newTrip),
            icon: const Icon(Icons.add),
            label: const Text('새 여행 만들기'),
          ),
        ],
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});

  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    final ongoing = trips.where((t) => !t.settled).toList();
    final past = trips.where((t) => t.settled).toList();

    Widget card(TripSummary trip) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TripCard(
        trip: trip,
        onTap: () => context.push(Routes.trip(trip.id)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final (title, section) in [('진행 중인 여행', ongoing), ('지난 여행', past)])
          if (section.isNotEmpty) ...[
            _SectionTitle(title),
            ...section.map(card),
          ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700, color: ToriColors.textSub),
      ),
    );
  }
}
