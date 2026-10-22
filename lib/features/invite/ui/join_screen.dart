import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/dates.dart';
import '../../../shared/korean.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/empty_state.dart';
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
  String? _pickedId;
  var _joining = false;

  Future<void> _join(String memberId) async {
    setState(() => _joining = true);
    try {
      final tripId = await ref
          .read(inviteActionsProvider)
          .join(widget.code, memberId);
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

    return switch (preview) {
      AsyncValue(hasValue: true, value: null) => Scaffold(
        body: EmptyState(
          title: '초대 코드를 찾을 수 없어요',
          message: '링크가 맞는지 초대한 친구에게 확인해 주세요',
          action: FilledButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('홈으로'),
          ),
        ),
      ),
      AsyncValue(hasValue: true, :final value?) => _buildPreview(value),
      AsyncValue(isLoading: true) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _ => Scaffold(
        body: EmptyState(
          title: '여행을 불러오지 못했어요',
          message: '인터넷 연결을 확인해 주세요',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(tripPreviewProvider(widget.code)),
            child: const Text('다시 시도'),
          ),
        ),
      ),
    };
  }

  Widget _buildPreview(TripPreview trip) {
    final text = Theme.of(context).textTheme;
    // 이미 이 브라우저로 들어온 적 있으면 그 이름을 골라 둔다
    final pickedId =
        _pickedId ?? trip.members.where((m) => m.isMe).firstOrNull?.id;
    final picked = trip.members.where((m) => m.id == pickedId).firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                      selected: member.id == pickedId,
                      onTap: _joining
                          ? null
                          : () => setState(() => _pickedId = member.id),
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
        ),
      ),
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton(
            onPressed: picked == null || _joining
                ? null
                : () => _join(picked.id),
            child: Text(
              picked == null
                  ? '내 이름을 골라주세요'
                  : _joining
                  ? '들어가는 중…'
                  : '${withRo(picked.name)} 참여하기',
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
          Text(
            trip.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            '${formatDateRange(trip.startDate, trip.endDate)} · '
            '${trip.currency.label} · ${trip.members.length}명',
            style: text.bodySmall?.copyWith(
              fontSize: 14,
              color: ToriColors.textMuted,
            ),
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
    final status = member.isMe
        ? '나'
        : member.claimed
        ? '참여 중'
        : '';
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ToriColors.accentSoft : ToriColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? ToriColors.accent : ToriColors.cardBorder,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status.isNotEmpty)
                  Text(status, style: Theme.of(context).textTheme.bodySmall),
                if (selected) const Icon(Icons.check, color: ToriColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
