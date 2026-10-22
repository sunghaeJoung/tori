import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _pickedId;
  var _joining = false;

  Future<void> _join(PreviewMember member) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final tripId = await ref
          .read(inviteActionsProvider)
          .join(widget.code, member.id);
      if (mounted) context.go(Routes.trip(tripId));
    } catch (e) {
      debugPrint('입장 실패: $e');
      if (!mounted) return;
      // claim_member가 '초대 코드나 멤버가 맞지 않다'(no_data_found)로 거절한 경우
      final changed = e is PostgrestException && e.code == 'P0002';
      if (changed) {
        _pickedId = null;
        ref.invalidate(tripPreviewProvider(widget.code));
      }
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? '여행 정보가 바뀌었어요. 이름을 다시 골라주세요'
                : '들어가지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(tripPreviewProvider(widget.code));
    final trip = preview.value;
    // 고른 이름은 id로 들고 있다가 최신 미리보기에서 다시 찾는다 (누가 들어왔는지 바뀔 수 있음).
    // 아직 안 골랐으면 이 브라우저로 들어온 적 있는 이름을 골라 둔다.
    final picked = trip?.members
        .where((m) => _pickedId == null ? m.isMe : m.id == _pickedId)
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: preview,
          onRetry: () => ref.invalidate(tripPreviewProvider(widget.code)),
          errorTitle: '초대받은 여행을 불러오지 못했어요',
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
