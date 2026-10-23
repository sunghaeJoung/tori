-- 6단계 지출: 지출 저장 RPC · 실시간 반영
--
-- - 지출과 분배는 save_expense RPC로만 쓴다. 한 트랜잭션에 넣고 바꿔서 반쯤 저장된 지출이 없다.
--   (지우기는 지금처럼 expenses delete. 분배는 cascade로 함께 지워진다)
-- - 지출이 바뀌면 trips.expenses_changed_at을 갱신한다. 앱은 여행 행 하나만 실시간으로 구독하면
--   추가·수정·삭제를 모두 알 수 있다 (Realtime의 delete 이벤트는 필터·RLS가 적용되지 않아서 쓰지 않는다).
--   7단계에서 정산 뒤 지출이 바뀌었는지(settled_at과 비교) 판단하는 데도 쓴다.

-- ─────────────────────────────────────────────
-- 지출이 바뀐 시각
-- ─────────────────────────────────────────────

alter table public.trips
  add column expenses_changed_at timestamptz not null default now();

create function public.touch_trip_expenses()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.trips set expenses_changed_at = now()
  where id = case when tg_op = 'DELETE' then old.trip_id else new.trip_id end;
  return null;
end;
$$;

create trigger expenses_touch_trip
  after insert or update or delete on public.expenses
  for each row execute function public.touch_trip_expenses();

-- ─────────────────────────────────────────────
-- 쓰기 권한: 지출 추가·수정, 분배 쓰기는 RPC로만
-- ─────────────────────────────────────────────

drop policy "멤버는 지출을 추가한다" on public.expenses;
drop policy "멤버는 지출을 고친다" on public.expenses;
drop policy "멤버는 분배를 읽고 쓴다" on public.expense_splits;

create policy "멤버는 분배를 읽는다" on public.expense_splits
  for select to authenticated
  using (exists (
    select 1 from public.expenses e
    where e.id = expense_id and public.is_trip_member(e.trip_id)
  ));

revoke insert, update on public.expenses from authenticated;
revoke insert, update, delete on public.expense_splits from authenticated;

-- ─────────────────────────────────────────────
-- RPC
-- ─────────────────────────────────────────────

-- 지출 저장: p_expense_id가 null이면 추가, 있으면 수정. 분배는 통째로 바꾼다.
-- 분배 합계 = 금액, 통화, 같은 여행 멤버인지는 기존 트리거·외래키가 검사한다.
create function public.save_expense(
  p_trip_id uuid,
  p_expense_id uuid,
  p_title text,
  p_amount bigint,
  p_currency text,
  p_paid_by uuid,
  p_category text,
  p_spent_at date,
  p_member_ids uuid[],
  p_shares bigint[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_expense_id;
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception '여행 멤버가 아니다' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(cardinality(p_member_ids), 0) = 0
     or cardinality(p_member_ids) is distinct from cardinality(p_shares) then
    raise exception '나눌 사람과 부담액 수가 맞지 않다' using errcode = 'check_violation';
  end if;

  if v_id is null then
    insert into public.expenses
      (trip_id, title, amount, currency, paid_by, category, spent_at, created_by)
    values
      (p_trip_id, btrim(p_title), p_amount, p_currency, p_paid_by, p_category, p_spent_at, auth.uid())
    returning id into v_id;
  else
    update public.expenses set
      title = btrim(p_title),
      amount = p_amount,
      currency = p_currency,
      paid_by = p_paid_by,
      category = p_category,
      spent_at = p_spent_at
    where id = v_id and trip_id = p_trip_id;
    if not found then
      -- 다른 친구가 먼저 지웠거나, 다른 여행의 지출
      raise exception '지출을 찾을 수 없다' using errcode = 'no_data_found';
    end if;
    delete from public.expense_splits where expense_id = v_id;
  end if;

  insert into public.expense_splits (expense_id, member_id, share_amount)
  select v_id, m, s from unnest(p_member_ids, p_shares) as t(m, s);

  return v_id;
end;
$$;

revoke execute on function
  public.touch_trip_expenses(),
  public.save_expense(uuid, uuid, text, bigint, text, uuid, text, date, uuid[], bigint[])
from public, anon, authenticated;

grant execute on function
  public.save_expense(uuid, uuid, text, bigint, text, uuid, text, date, uuid[], bigint[])
to authenticated;

-- ─────────────────────────────────────────────
-- 실시간: 여행 행이 바뀌면 멤버에게 알린다 (RLS로 멤버만 받는다)
-- ─────────────────────────────────────────────

alter publication supabase_realtime add table public.trips;
