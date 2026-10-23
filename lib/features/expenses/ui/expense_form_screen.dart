import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/dates.dart';
import '../../../shared/limits.dart';
import '../../../shared/messages.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/selectable_card.dart';
import '../../../shared/widgets/toggle_chip.dart';
import '../../trips/data/trip.dart';
import '../../trips/providers.dart';
import '../data/expense.dart';
import '../data/expense_draft.dart';
import '../providers.dart';
import 'category_icon.dart';

/// 08 지출 추가 · 수정. [expenseId]가 있으면 수정.
///
/// 여행(과 고칠 지출)을 불러오면 [_ExpenseEditor]가 입력을 맡는다.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.tripId, this.expenseId});

  final String tripId;
  final String? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  /// 한 번 찾은 고칠 지출. 그 뒤로 목록에서 빠져도(내가 지워서 닫히는 중이거나 친구가 지움)
  /// 입력 화면을 그대로 둔다. 친구가 지웠으면 저장할 때 알려준다.
  Expense? _loaded;

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
    final expenseId = widget.expenseId;
    final trip = ref.watch(tripDetailProvider(tripId));
    final expense = expenseId == null || _loaded != null
        ? AsyncData<Expense?>(_loaded)
        : ref.watch(
            expensesProvider(tripId).select(
              (list) => list.whenData(
                (list) =>
                    list.items.where((e) => e.id == expenseId).firstOrNull,
              ),
            ),
          );
    _loaded = expense.value;

    if ((trip.value, expense.value) case (final trip?, final found)
        when expenseId == null || found != null) {
      return _ExpenseEditor(trip: trip, expense: found);
    }
    void close() => context.popOrGo(Routes.trip(tripId));
    return Scaffold(
      appBar: _appBar(isEdit: expenseId != null, onClose: close),
      body: !trip.hasValue
          ? AsyncView(
              value: trip,
              onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
              errorTitle: '여행을 불러오지 못했어요',
              data: (_) => const SizedBox.shrink(),
            )
          : AsyncView(
              value: expense,
              onRetry: () => ref.invalidate(expensesProvider(tripId)),
              errorTitle: '지출을 불러오지 못했어요',
              data: (_) => EmptyState(
                title: '지출을 찾을 수 없어요',
                message: '다른 친구가 지웠을 수 있어요',
                action: FilledButton(
                  onPressed: close,
                  child: const Text('여행방으로'),
                ),
              ),
            ),
    );
  }
}

AppBar _appBar({
  required bool isEdit,
  required VoidCallback? onClose,
  List<Widget> actions = const [],
}) => AppBar(
  leading: IconButton(
    tooltip: '닫기',
    icon: const Icon(Icons.close),
    onPressed: onClose,
  ),
  title: Text(isEdit ? '지출 수정' : '지출 추가'),
  actions: [...actions, const SizedBox(width: 8)],
);

/// 입력 중인 지출을 들고 저장·삭제한다. [expense]가 있으면 수정.
class _ExpenseEditor extends ConsumerStatefulWidget {
  const _ExpenseEditor({required this.trip, required this.expense});

  final TripDetail trip;
  final Expense? expense;

  @override
  ConsumerState<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<_ExpenseEditor> {
  /// 처음 한 번만 만든다. 그 뒤로 친구가 같은 지출을 고쳐도 입력 중인 값은 그대로 둔다.
  late final ExpenseDraft _draft;
  var _saving = false;
  var _confirmDelete = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _draft = switch (widget.expense) {
      final expense? => ExpenseDraft.from(expense),
      null => ExpenseDraft(
        currency: trip.currency,
        spentAt: DateUtils.dateOnly(ref.read(todayProvider)),
        paidBy: trip.memberOf(ref.read(authUserProvider).value?.id)?.id,
        splitAmong: trip.memberIds,
      ),
    };
  }

  void _close() => context.popOrGo(Routes.trip(widget.trip.id));

  /// 입력을 고쳤다. 삭제를 한 번 눌러 둔 상태였으면 풀어서, 나중에 실수로 눌러도 바로 지워지지 않게 한다.
  void _edited([VoidCallback? change]) => setState(() {
    change?.call();
    _confirmDelete = false;
  });

  Future<void> _run(Future<void> Function() action, String failMessage) async {
    if (_saving) return; // 빠르게 두 번 눌러도 한 번만
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
      ScaffoldMessenger.of(
        context,
      ).showMessage(e is ExpenseNotFound ? '다른 친구가 이 지출을 지웠어요' : failMessage);
    }
  }

  void _save() => _run(
    () => ref
        .read(expenseActionsProvider)
        .save(widget.trip, _draft, expenseId: widget.expense?.id),
    '저장하지 못했어요. $retryHint',
  );

  void _delete() {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    _run(
      () => ref
          .read(expenseActionsProvider)
          .delete(widget.trip.id, widget.expense!.id),
      '지우지 못했어요. $retryHint',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(
        isEdit: widget.expense != null,
        onClose: _saving ? null : _close,
        actions: [
          if (widget.expense != null)
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
        ],
      ),
      body: _Form(
        trip: widget.trip,
        draft: _draft,
        enabled: !_saving,
        onChanged: _edited,
      ),
      bottomNavigationBar: _KeypadArea(
        draft: _draft,
        saving: _saving,
        onPress: (key) => _edited(() => _draft.press(key)),
        onSave: _save,
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
    final date = draft.spentAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: date.year < 2020 ? date : DateTime(2020),
      lastDate: date.year > 2100 ? date : DateTime(2100),
    );
    if (picked != null) _update(() => draft.spentAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final memberIds = trip.memberIds;
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
                  draft.currency.withUnit(draft.amountDisplay),
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
      color: ToriColors.keypad,
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
