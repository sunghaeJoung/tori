import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/dates.dart';
import '../../../shared/limits.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/selectable_card.dart';
import '../../../shared/widgets/toggle_chip.dart';
import '../../trips/data/trip.dart';
import '../../trips/providers.dart';
import '../data/expense.dart';
import '../providers.dart';
import 'category_icon.dart';
import 'expense_draft.dart';

/// 08 지출 추가 · 수정. [expenseId]가 있으면 수정.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.tripId, this.expenseId});

  final String tripId;
  final String? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  /// 여행(과 고칠 지출)을 불러온 뒤 한 번만 만든다.
  /// 그 뒤로 친구가 같은 지출을 고쳐도 입력 중인 값은 그대로 둔다.
  ExpenseDraft? _draft;
  var _saving = false;
  var _confirmDelete = false;

  bool get _isEdit => widget.expenseId != null;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      // 주소로 바로 들어와 돌아갈 화면이 없을 때
      context.go(Routes.trip(widget.tripId));
    }
  }

  Future<void> _run(Future<void> Function() action, String failMessage) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) _close();
    } catch (e) {
      debugPrint('지출 저장 실패: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmDelete = false;
      });
      final gone = e is PostgrestException && e.code == 'P0002';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(gone ? '다른 친구가 이 지출을 지웠어요' : failMessage)),
        );
    }
  }

  void _save(TripDetail trip) => _run(
    () => ref
        .read(expenseActionsProvider)
        .save(
          widget.tripId,
          _draft!,
          expenseId: widget.expenseId,
          memberIds: [for (final m in trip.members) m.id],
        ),
    '저장하지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요',
  );

  void _delete() {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    _run(
      () => ref
          .read(expenseActionsProvider)
          .delete(widget.tripId, widget.expenseId!),
      '지우지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요',
    );
  }

  ExpenseDraft _newDraft(TripDetail trip) {
    final userId = ref.read(authUserProvider).value?.id;
    return ExpenseDraft(
      currency: trip.currency,
      spentAt: DateUtils.dateOnly(ref.read(todayProvider)),
      paidBy: (userId == null ? null : trip.memberOf(userId))?.id,
      splitAmong: [for (final m in trip.members) m.id],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripDetailProvider(widget.tripId));
    // 고칠 지출은 처음 한 번만 찾는다
    final expenses = _isEdit && _draft == null
        ? ref.watch(expensesProvider(widget.tripId))
        : null;
    if (_draft == null && trip.hasValue) {
      if (expenses == null) {
        _draft = _newDraft(trip.requireValue);
      } else {
        final expense = expenses.value
            ?.where((e) => e.id == widget.expenseId)
            .firstOrNull;
        if (expense != null) _draft = ExpenseDraft.from(expense);
      }
    }
    final draft = _draft;

    Widget body(TripDetail trip) {
      if (draft != null) {
        return _Form(
          trip: trip,
          draft: draft,
          enabled: !_saving,
          onChanged: () => setState(() {}),
        );
      }
      return AsyncView(
        value: expenses!,
        onRetry: () => ref.invalidate(expensesProvider(widget.tripId)),
        errorTitle: '지출을 불러오지 못했어요',
        data: (_) => EmptyState(
          title: '지출을 찾을 수 없어요',
          message: '다른 친구가 지웠을 수 있어요',
          action: FilledButton(onPressed: _close, child: const Text('여행방으로')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '닫기',
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : _close,
        ),
        title: Text(_isEdit ? '지출 수정' : '지출 추가'),
        actions: [
          if (_isEdit && draft != null)
            TextButton(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: ToriColors.danger,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(_confirmDelete ? '한 번 더 누르면 삭제' : '삭제'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView(
        value: trip,
        onRetry: () => ref.invalidate(tripDetailProvider(widget.tripId)),
        errorTitle: '여행을 불러오지 못했어요',
        data: body,
      ),
      bottomNavigationBar: draft == null || !trip.hasValue
          ? null
          : _KeypadArea(
              draft: draft,
              saving: _saving,
              onPress: (key) => setState(() => draft.press(key)),
              onSave: () => _save(trip.requireValue),
            ),
    );
  }
}

/// 금액 표시와 입력칸들 (키패드 위).
class _Form extends StatelessWidget {
  const _Form({
    required this.trip,
    required this.draft,
    required this.enabled,
    required this.onChanged,
  });

  final TripDetail trip;
  final ExpenseDraft draft;
  final bool enabled;

  /// draft를 고친 뒤 화면을 다시 그리게 부른다.
  final VoidCallback onChanged;

  void _update(void Function() change) {
    if (!enabled) return;
    change();
    onChanged();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.spentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _update(() => draft.spentAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final memberIds = [for (final m in trip.members) m.id];
    final allSelected = draft.splitAmong.length == memberIds.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Column(
            spacing: 8,
            children: [
              // 현지 통화가 원화면(국내 여행) 고를 필요가 없다
              if (trip.currency != Currency.krw)
                SizedBox(
                  width: 180,
                  child: SegmentedTabs(
                    height: 44,
                    options: [
                      (trip.currency, trip.currency.unit),
                      (Currency.krw, Currency.krw.unit),
                    ],
                    selected: draft.currency,
                    onSelect: (c) => _update(() => draft.setCurrency(c)),
                  ),
                ),
              Semantics(
                liveRegion: true,
                label: '금액',
                child: Text(
                  withUnit(draft.amountDisplay, draft.currency),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: draft.amount == 0
                        ? ToriColors.textSub
                        : ToriColors.text,
                  ),
                ),
              ),
              Text(
                draft.perPersonText(),
                style: text.bodyMedium?.copyWith(color: ToriColors.textMuted),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: '내용',
                  child: TextFormField(
                    initialValue: draft.title,
                    enabled: enabled,
                    maxLength: Limits.expenseTitle,
                    onChanged: (value) => _update(() => draft.title = value),
                    decoration: InputDecoration(
                      hintText: '비워두면 "${draft.category.label}"',
                      counterText: '',
                      errorText: draft.titleTooLong
                          ? '내용은 ${Limits.expenseTitle}자까지 쓸 수 있어요'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: '카테고리',
                  child: GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final c in ExpenseCategory.values)
                        SelectableCard(
                          selected: draft.category == c,
                          onTap: () => _update(() => draft.category = c),
                          padding: EdgeInsets.zero,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 4,
                            children: [
                              Icon(
                                c.icon,
                                size: 22,
                                color: draft.category == c
                                    ? ToriColors.accent
                                    : ToriColors.textMuted,
                              ),
                              Text(
                                c.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: '날짜',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      label: Text(formatMonthDay(draft.spentAt)),
                      onPressed: enabled ? () => _pickDate(context) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: '낸 사람',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in trip.members)
                        ToggleChip(
                          label: m.name,
                          selected: draft.paidBy == m.id,
                          onTap: () => _update(() => draft.paidBy = m.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('나눌 사람', style: text.labelLarge),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _update(() {
                        if (allSelected) {
                          draft.splitAmong.clear();
                        } else {
                          draft.splitAmong.addAll(memberIds);
                        }
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: ToriColors.accent,
                        minimumSize: const Size(44, 44),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(allSelected ? '모두 해제' : '모두 선택'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in trip.members)
                      ToggleChip(
                        label: m.name,
                        showCheck: true,
                        selected: draft.splitAmong.contains(m.id),
                        onTap: () => _update(() {
                          if (!draft.splitAmong.remove(m.id)) {
                            draft.splitAmong.add(m.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 화면 아래 숫자 키패드와 저장 버튼.
class _KeypadArea extends StatelessWidget {
  const _KeypadArea({
    required this.draft,
    required this.saving,
    required this.onPress,
    required this.onSave,
  });

  final ExpenseDraft draft;
  final bool saving;
  final ValueChanged<String> onPress;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final keys = [
      ...'123456789'.split(''),
      draft.currency.decimals > 0 ? '.' : '00',
      '0',
      'del',
    ];
    return ColoredBox(
      color: const Color(0xFFF6F1EA),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                mainAxisExtent: 48,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final key in keys)
                    _Key(keyValue: key, onPress: saving ? null : onPress),
                ],
              ),
              FilledButton(
                onPressed: draft.canSave && !saving ? onSave : null,
                child: Text(saving ? '저장하는 중…' : '저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.keyValue, required this.onPress});

  final String keyValue;
  final ValueChanged<String>? onPress;

  @override
  Widget build(BuildContext context) {
    final isDelete = keyValue == 'del';
    return Semantics(
      button: true,
      label: isDelete ? '지우기' : keyValue,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPress == null ? null : () => onPress!(keyValue),
        child: Center(
          child: isDelete
              ? const Icon(Icons.backspace_outlined, size: 24)
              : Text(
                  keyValue,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
