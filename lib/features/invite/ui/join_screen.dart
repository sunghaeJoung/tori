import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/dates.dart';
import '../../../shared/korean.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/selectable_card.dart';
import '../data/invite_repository.dart';
import '../providers.dart';

/// 06 나는 누구? 초대 링크 `/join/:code`로 들어와 내 이름을 고르면 여행방에 들어간다.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  PreviewMember? _picked;
  var _joining = false;

  Future<void> _join(PreviewMember member) async {
    setState(() => _joining = true);
    try {
      final tripId = await ref
          .read(inviteActionsProvider)
          .join(widget.code, member.id);
      if (mounted) context.go(Routes.trip(tripId));
    } catch (e) {
      debugPrint('입장 실패: $e');
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('들어가지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(tripPreviewProvider(widget.code));
    final trip = preview.value;
    // 이미 이 브라우저로 들어온 적 있으면 그 이름을 골라 둔다
    final picked = _picked ?? trip?.members.where((m) => m.isMe).firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: preview,
          onRetry: () => ref.invalidate(tripPreviewProvider(widget.code)),
          data: (trip) => trip == null
              ? EmptyState(
                  title: '초대 코드를 찾을 수 없어요',
                  message: '링크가 맞는지 초대한 친구에게 확인해 주세요',
                  action: FilledButton(
                    onPressed: () => context.go(Routes.home),
                    child: const Text('홈으로'),
                  ),
                )
              : _body(trip, picked),
        ),
      ),
      bottomNavigationBar: trip == null
          ? null
          : BottomActions(
              children: [
                FilledButton(
                  onPressed: picked == null || _joining
                      ? null
                      : () => _join(picked),
                  child: Text(switch ((picked, _joining)) {
                    (null, _) => '내 이름을 골라주세요',
                    (_, true) => '들어가는 중…',
                    (final member?, _) => '${withRo(member.name)} 참여하기',
                  }),
                ),
              ],
            ),
    );
  }

  Widget _body(TripPreview trip, PreviewMember? picked) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          _TripCard(trip: trip),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text('나는 누구인가요?', style: text.headlineMedium),
              Text(
                '내 이름을 고르면 바로 여행방에 들어가요',
                style: text.bodyMedium?.copyWith(color: ToriColors.textSub),
              ),
            ],
          ),
          Column(
            spacing: 10,
            children: [
              for (final member in trip.members)
                _MemberOption(
                  member: member,
                  selected: member.id == picked?.id,
                  onTap: _joining
                      ? null
                      : () => setState(() => _picked = member),
                ),
            ],
          ),
          if (picked != null && picked.claimed && !picked.isMe)
            Text(
              '다른 기기에서 이미 들어온 이름이에요. 본인일 때만 골라주세요.\n'
              '이 기기로 들어오면 원래 기기는 이 이름에서 빠져요.',
              style: text.bodySmall?.copyWith(
                color: ToriColors.danger,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripPreview trip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ToriColors.accentSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            '${trip.inviterName}님이 초대했어요',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: ToriColors.accent,
            ),
          ),
          Text(trip.name, style: text.titleLarge?.copyWith(fontSize: 22)),
          Text(
            '${formatDateRange(trip.startDate, trip.endDate)} · '
            '${trip.currency.label} · ${trip.members.length}명',
            style: text.bodyMedium?.copyWith(color: ToriColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MemberOption extends StatelessWidget {
  const _MemberOption({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final PreviewMember member;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = member.isMe
        ? '나'
        : member.claimed
        ? '참여 중'
        : null;
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        spacing: 14,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ToriColors.tile,
            foregroundColor: ToriColors.acornCap,
            child: Text(
              member.name.characters.first,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(member.name, style: text.titleMedium)),
          if (status != null) Text(status, style: text.bodySmall),
          if (selected) const Icon(Icons.check, color: ToriColors.accent),
        ],
      ),
    );
  }
}
