-- 분배 행은 부담액(share_amount)만 고칠 수 있다.
-- expense_id·member_id를 바꾸면 분배가 빠져나간 원래 지출의 합계 검사를 건너뛸 수 있기 때문.
revoke update on public.expense_splits from authenticated;
grant update (share_amount) on public.expense_splits to authenticated;
