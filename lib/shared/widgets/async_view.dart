import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// 서버에서 불러오는 화면의 공통 처리: 로딩 → 내용, 실패하면 다시 시도.
///
/// 이미 받은 값이 있으면 새로고침 중이거나 새로고침이 실패해도 그 값을 계속 보여준다.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.errorTitle = '불러오지 못했어요',
  });

  final AsyncValue<T> value;

  /// 실패했을 때 제목 (예: '여행을 불러오지 못했어요')
  final String errorTitle;
  final Widget Function(T data) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return EmptyState(
      title: errorTitle,
      message: '인터넷 연결을 확인해 주세요',
      action: FilledButton.tonal(
        onPressed: onRetry,
        child: const Text('다시 시도'),
      ),
    );
  }
}
