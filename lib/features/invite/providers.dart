import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import '../trips/providers.dart';
import 'data/invite_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(ref.watch(supabaseProvider)),
);

/// 초대 코드로 본 여행. 코드가 틀리면 null.
/// 화면을 떠나면 버려서, 다시 열 때 누가 들어왔는지 새로 불러온다.
final tripPreviewProvider = FutureProvider.autoDispose
    .family<TripPreview?, String>((ref, inviteCode) async {
      await ref.watch(authUserProvider.future);
      return ref.watch(inviteRepositoryProvider).preview(inviteCode);
    });

final inviteActionsProvider = Provider<InviteActions>(InviteActions.new);

class InviteActions {
  InviteActions(this._ref);

  final Ref _ref;

  /// 고른 멤버로 여행에 들어가고 여행 id를 돌려준다. 홈 목록과 여행 정보를 다시 불러온다.
  Future<String> join(String inviteCode, String memberId) async {
    await _ref.read(authUserProvider.future);
    final tripId = await _ref
        .read(inviteRepositoryProvider)
        .claim(inviteCode, memberId);
    _ref
      ..invalidate(myTripsProvider)
      ..invalidate(tripDetailProvider(tripId));
    return tripId;
  }
}
