-- 7단계 정산: 정산 확정 RPC · 송금 완료 체크 실시간 반영
--
-- - 정산 확정(환율·기준일·확정 시각 + 송금 목록)은 confirm_settlement RPC로만 한다.
--   송금 목록은 앱의 settle()이 계산한 결과를 받는다 (정산 알고리즘은 core/money 한 곳에만 둔다).
--   "정산 다시 하기"도 같은 RPC: 송금 목록을 지우고 새로 만든다.
-- - 정산 뒤 지출이 바뀌면(expenses_changed_at > settled_at) 앱이 "다시 정산" 상태로 본다.
--   앱이 계산하는 사이 친구가 지출을 바꿨으면, 옛 지출로 만든 송금 목록이 확정되지 않게 거절한다.
-- - 송금 완료 체크(settlements.done_at)가 바뀌면 trips.settlements_changed_at을 갱신해 실시간으로 알린다.
--   앱은 여행 행 하나만 구독한다 (20261023010000 참고).

-- ─────────────────────────────────────────────
-- 변경 시각
-- ─────────────────────────────────────────────

-- 지출 변경 시각을 트랜잭션 시작 시각(now) 대신 실제 시각(clock_timestamp)으로.
-- 정산 확정과 지출 저장이 동시에 일어나도, 정산 뒤에 커밋된 지출이 settled_at보다 늦게 찍혀
-- "다시 정산"으로 보이게 한다.
create or replace function public.touch_trip_expenses()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.trips set expenses_changed_at = clock_timestamp()
  where id = case when tg_op = 'DELETE' then old.trip_id else new.trip_id end;
  return null;
end;
$$;

alter table public.trips
  add column settlements_changed_at timestamptz not null default now();

create function public.touch_trip_settlements()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.trips set settlements_changed_at = now() where id = new.trip_id;
  return null;
end;
$$;

create trigger settlements_touch_trip
  after update of done_at on public.settlements
  for each row execute function public.touch_trip_settlements();

-- ─────────────────────────────────────────────
-- 쓰기 권한: 정산 열은 RPC로만
-- ─────────────────────────────────────────────

revoke update on public.trips from authenticated;
grant update (name, start_date, end_date) on public.trips to authenticated;

-- ─────────────────────────────────────────────
-- RPC
-- ─────────────────────────────────────────────

-- 정산 확정. 송금 i건 = p_from[i] → p_to[i] : p_amounts[i]원 (10원 단위, 앱이 계산).
-- 원화 여행은 환율 1. p_expenses_changed_at은 앱이 계산에 쓴 지출의 expenses_changed_at.
--
-- 송금 목록이 잔액과 맞는지는 검사하지 않는다 (초대 코드를 아는 친구끼리의 신뢰, development.md 2장).
-- 금액 > 0 · 10원 단위 · 같은 여행 멤버는 settlements 제약조건이 막는다.
create function public.confirm_settlement(
  p_trip_id uuid,
  p_expenses_changed_at timestamptz,
  p_rate numeric,
  p_rate_date date,
  p_from uuid[] default '{}',
  p_to uuid[] default '{}',
  p_amounts bigint[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception '여행 멤버가 아니다' using errcode = 'insufficient_privilege';
  end if;
  if p_rate is null or p_rate <= 0 or p_rate_date is null then
    raise exception '환율과 기준일이 필요하다' using errcode = 'check_violation';
  end if;
  if cardinality(p_from) <> cardinality(p_to)
     or cardinality(p_from) <> cardinality(p_amounts) then
    raise exception '송금 목록의 길이가 맞지 않다' using errcode = 'check_violation';
  end if;
  -- 여행 행을 잠가서, 확인하는 동안 지출 저장(트리거가 이 행을 고침)이 끼어들지 못하게 한다
  perform 1 from public.trips where id = p_trip_id for update;
  if not exists (
    select 1 from public.trips
    where id = p_trip_id and expenses_changed_at = p_expenses_changed_at
  ) then
    raise exception '그사이 지출이 바뀌었다' using errcode = 'serialization_failure';
  end if;
  if exists (
    select 1 from public.trips
    where id = p_trip_id and local_currency = 'KRW' and p_rate <> 1
  ) then
    raise exception '원화 여행의 환율은 1이다' using errcode = 'check_violation';
  end if;

  update public.trips set
    settle_rate = p_rate,
    settle_rate_date = p_rate_date,
    settled_at = clock_timestamp()
  where id = p_trip_id;

  delete from public.settlements where trip_id = p_trip_id;
  insert into public.settlements (trip_id, from_member, to_member, amount_krw)
  select p_trip_id, f, t, a
  from unnest(p_from, p_to, p_amounts) as x(f, t, a);
end;
$$;

revoke execute on function
  public.touch_trip_settlements(),
  public.confirm_settlement(uuid, timestamptz, numeric, date, uuid[], uuid[], bigint[])
from public, anon, authenticated;

grant execute on function
  public.confirm_settlement(uuid, timestamptz, numeric, date, uuid[], uuid[], bigint[])
to authenticated;
