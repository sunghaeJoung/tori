-- 토리 초기 스키마: 테이블 · 제약조건 · RLS · RPC
-- 기준 문서: docs/development.md 2장(DB 설계), CLAUDE.md 보안 규칙
--
-- 원칙
-- - 금액은 통화의 최소 단위 정수(bigint), 환율만 numeric
-- - 모든 테이블 RLS, 기본 거부. 여행 멤버(is_trip_member)만 읽기·쓰기
-- - RLS를 넘어야 하는 일(여행 만들기, 초대 코드로 미리보기·입장)만 security definer RPC로

-- ─────────────────────────────────────────────
-- 테이블
-- ─────────────────────────────────────────────

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  name text not null
    check (name = btrim(name) and char_length(name) between 1 and 40),
  start_date date not null,
  end_date date not null,
  local_currency text not null
    check (local_currency in ('KRW', 'JPY', 'CNY', 'USD')),
  settle_currency text not null default 'KRW'
    check (settle_currency = 'KRW'),
  -- 현지 통화 1단위 → 원. 정산 확정 전엔 null
  settle_rate numeric check (settle_rate > 0),
  settle_rate_date date,
  settled_at timestamptz,
  -- 헷갈리는 글자(0 O 1 I)를 뺀 32자 중 8자리
  invite_code text not null unique
    check (invite_code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  -- 익명 계정이 지워져도 여행·지출은 남도록 set null
  created_by uuid default auth.uid() references auth.users on delete set null,
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.members (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips on delete cascade,
  name text not null
    check (name = btrim(name) and char_length(name) between 1 and 20),
  -- 멤버 순서. 지출 나누기의 나머지를 앞사람부터 주는 기준
  sort_order int not null check (sort_order >= 0),
  -- "나는 누구?"에서 고르면 연결된다
  user_id uuid references auth.users on delete set null,
  bank_account text check (char_length(bank_account) <= 100), -- v2
  created_at timestamptz not null default now(),
  unique (trip_id, user_id),
  unique (trip_id, name),
  unique (trip_id, sort_order),
  -- 다른 테이블이 (멤버, 여행)을 함께 참조해서 다른 여행의 멤버를 못 쓰게 한다
  unique (id, trip_id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips on delete cascade,
  title text not null
    check (title = btrim(title) and char_length(title) between 1 and 40),
  amount bigint not null check (amount > 0),
  currency text not null check (currency in ('KRW', 'JPY', 'CNY', 'USD')),
  paid_by uuid not null,
  category text not null
    check (category in ('lodging', 'food', 'transport', 'cafe', 'drink', 'activity', 'shopping', 'etc')),
  spent_at date not null,
  created_by uuid default auth.uid() references auth.users on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (paid_by, trip_id) references public.members (id, trip_id)
);

create table public.expense_splits (
  expense_id uuid not null references public.expenses on delete cascade,
  member_id uuid not null references public.members on delete cascade,
  -- 금액이 인원보다 작으면 0인 사람이 생긴다 (예: 2원 ÷ 4명)
  share_amount bigint not null check (share_amount >= 0),
  primary key (expense_id, member_id)
);

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips on delete cascade,
  from_member uuid not null,
  to_member uuid not null,
  -- 10원 단위로 반올림한 송금액
  amount_krw bigint not null check (amount_krw > 0 and amount_krw % 10 = 0),
  done_at timestamptz,
  check (from_member <> to_member),
  foreign key (from_member, trip_id) references public.members (id, trip_id),
  foreign key (to_member, trip_id) references public.members (id, trip_id)
);

create index on public.members (user_id);
create index on public.expenses (trip_id, spent_at);
create index on public.expense_splits (member_id);
create index on public.settlements (trip_id);

-- ─────────────────────────────────────────────
-- 지출 무결성 트리거
-- ─────────────────────────────────────────────

-- 지출 통화는 여행의 현지 통화 또는 원화만
create function public.check_expense_currency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.currency <> 'KRW' and new.currency <> (
    select local_currency from public.trips where id = new.trip_id
  ) then
    raise exception '지출 통화(%)는 여행 현지 통화나 KRW여야 한다', new.currency
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger expenses_currency
  before insert or update of currency, trip_id on public.expenses
  for each row execute function public.check_expense_currency();

-- 분배 합계 = 지출 금액, 분배받는 멤버는 같은 여행 사람.
-- 지출과 분배를 한 트랜잭션에서 넣을 수 있도록 커밋 직전에 검사한다 (deferred).
create function public.check_expense_splits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expense_id uuid;
  v_amount bigint;
  v_trip_id uuid;
  v_total bigint;
begin
  if tg_table_name = 'expenses' then
    v_expense_id := new.id;
  elsif tg_op = 'DELETE' then
    v_expense_id := old.expense_id;
  else
    v_expense_id := new.expense_id;
  end if;

  select amount, trip_id into v_amount, v_trip_id
  from public.expenses where id = v_expense_id;
  if not found then
    return null; -- 지출이 지워져 분배도 함께 지워진 경우
  end if;

  select coalesce(sum(share_amount), 0) into v_total
  from public.expense_splits where expense_id = v_expense_id;
  if v_total <> v_amount then
    raise exception '분배 합계(%)가 지출 금액(%)과 다르다', v_total, v_amount
      using errcode = 'check_violation';
  end if;

  if exists (
    select 1
    from public.expense_splits s
    join public.members m on m.id = s.member_id
    where s.expense_id = v_expense_id and m.trip_id <> v_trip_id
  ) then
    raise exception '다른 여행의 멤버에게 분배할 수 없다'
      using errcode = 'check_violation';
  end if;

  return null;
end;
$$;

create constraint trigger expenses_splits_total
  after insert or update of amount on public.expenses
  deferrable initially deferred
  for each row execute function public.check_expense_splits();

create constraint trigger expense_splits_total
  after insert or update or delete on public.expense_splits
  deferrable initially deferred
  for each row execute function public.check_expense_splits();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger expenses_updated_at
  before update on public.expenses
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────

-- 지금 로그인한 사용자가 이 여행의 멤버인가.
-- members 정책 안에서 members를 다시 읽으므로 RLS를 거치지 않게 security definer로 둔다.
create function public.is_trip_member(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.members
    where trip_id = p_trip_id and user_id = (select auth.uid())
  );
$$;

alter table public.trips enable row level security;
alter table public.members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;

-- 여행: 멤버만 읽고 고친다. 만들기는 create_trip RPC로만.
create policy "멤버는 여행을 읽는다" on public.trips
  for select to authenticated
  using (public.is_trip_member(id));

create policy "멤버는 여행을 고친다" on public.trips
  for update to authenticated
  using (public.is_trip_member(id))
  with check (public.is_trip_member(id));

-- 멤버: 같은 여행 멤버만 읽는다. 추가는 create_trip, 연결은 claim_member RPC로만.
create policy "멤버는 같은 여행 멤버를 읽는다" on public.members
  for select to authenticated
  using (public.is_trip_member(trip_id));

-- 지출: 멤버는 읽기·쓰기 모두 가능
create policy "멤버는 지출을 읽는다" on public.expenses
  for select to authenticated
  using (public.is_trip_member(trip_id));

create policy "멤버는 지출을 추가한다" on public.expenses
  for insert to authenticated
  with check (
    public.is_trip_member(trip_id) and created_by = (select auth.uid())
  );

create policy "멤버는 지출을 고친다" on public.expenses
  for update to authenticated
  using (public.is_trip_member(trip_id))
  with check (public.is_trip_member(trip_id));

create policy "멤버는 지출을 지운다" on public.expenses
  for delete to authenticated
  using (public.is_trip_member(trip_id));

create policy "멤버는 분배를 읽고 쓴다" on public.expense_splits
  for all to authenticated
  using (exists (
    select 1 from public.expenses e
    where e.id = expense_id and public.is_trip_member(e.trip_id)
  ))
  with check (exists (
    select 1 from public.expenses e
    where e.id = expense_id and public.is_trip_member(e.trip_id)
  ));

-- 송금: 읽기와 완료 체크(done_at)만. 만들기·지우기는 7단계 정산 확정 RPC에서.
create policy "멤버는 송금을 읽는다" on public.settlements
  for select to authenticated
  using (public.is_trip_member(trip_id));

create policy "멤버는 송금 완료를 체크한다" on public.settlements
  for update to authenticated
  using (public.is_trip_member(trip_id))
  with check (public.is_trip_member(trip_id));

-- 고칠 수 있는 열만 열어둔다 (초대 코드·만든 사람·소속 여행은 못 바꾼다)
revoke update on public.trips from anon, authenticated;
grant update (name, start_date, end_date, settle_rate, settle_rate_date, settled_at)
  on public.trips to authenticated;

revoke update on public.expenses from anon, authenticated;
grant update (title, amount, currency, paid_by, category, spent_at)
  on public.expenses to authenticated;

revoke update on public.settlements from anon, authenticated;
grant update (done_at) on public.settlements to authenticated;

-- ─────────────────────────────────────────────
-- RPC
-- ─────────────────────────────────────────────

-- 초대 코드: 32자 알파벳에서 8자리. 256 = 32 × 8이라 나머지 연산에 치우침이 없다.
create function public.gen_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea := extensions.gen_random_bytes(8);
  code text := '';
begin
  for i in 0..7 loop
    code := code || substr(alphabet, get_byte(bytes, i) % 32 + 1, 1);
  end loop;
  return code;
end;
$$;

-- 여행 만들기: 여행 + 멤버(나 먼저, 그다음 친구들 순서)를 한 번에 만들고 나를 첫 멤버에 연결한다.
create function public.create_trip(
  p_name text,
  p_start_date date,
  p_end_date date,
  p_local_currency text,
  p_my_name text,
  p_friend_names text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_trip_id uuid;
  v_names text[];
begin
  if v_uid is null then
    raise exception '로그인이 필요하다' using errcode = 'insufficient_privilege';
  end if;

  v_names := array_prepend(
    btrim(p_my_name),
    array(select btrim(n) from unnest(coalesce(p_friend_names, '{}')) with ordinality as f(n, i) order by i)
  );
  if cardinality(v_names) > 20 then
    raise exception '멤버는 20명까지' using errcode = 'check_violation';
  end if;

  -- 초대 코드가 겹치면 다시 뽑는다
  for attempt in 1..5 loop
    begin
      insert into public.trips (name, start_date, end_date, local_currency, invite_code, created_by)
      values (btrim(p_name), p_start_date, p_end_date, p_local_currency, public.gen_invite_code(), v_uid)
      returning id into v_trip_id;
      exit;
    exception when unique_violation then
      if attempt = 5 then raise; end if;
    end;
  end loop;

  insert into public.members (trip_id, name, sort_order, user_id)
  select v_trip_id, n, (i - 1)::int, case when i = 1 then v_uid end
  from unnest(v_names) with ordinality as t(n, i);

  return v_trip_id;
end;
$$;

-- 초대 코드로 여행 미리보기: "나는 누구?" 화면에 필요한 것만 돌려준다 (여행 id·사용자 id는 숨김).
-- 코드가 틀리면 null.
create function public.preview_trip(p_invite_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception '로그인이 필요하다' using errcode = 'insufficient_privilege';
  end if;

  return (
    select jsonb_build_object(
      'name', t.name,
      'start_date', t.start_date,
      'end_date', t.end_date,
      'local_currency', t.local_currency,
      'members', (
        select jsonb_agg(
          jsonb_build_object(
            'id', m.id,
            'name', m.name,
            'claimed', m.user_id is not null,
            'is_me', m.user_id is not distinct from v_uid
          )
          order by m.sort_order
        )
        from public.members m
        where m.trip_id = t.id
      )
    )
    from public.trips t
    where t.invite_code = upper(btrim(p_invite_code))
  );
end;
$$;

-- 초대 코드 + 고른 멤버로 입장: 그 멤버에 내 계정을 연결하고 여행 id를 돌려준다.
-- 브라우저를 바꿔 다시 들어온 친구가 자기 이름을 다시 고를 수 있도록, 이미 연결된 멤버도 다시 연결한다
-- (초대 코드를 아는 친구끼리의 신뢰를 전제로 한 선택, development.md 2장).
create function public.claim_member(p_invite_code text, p_member_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_trip_id uuid;
begin
  if v_uid is null then
    raise exception '로그인이 필요하다' using errcode = 'insufficient_privilege';
  end if;

  select t.id into v_trip_id
  from public.trips t
  join public.members m on m.trip_id = t.id
  where t.invite_code = upper(btrim(p_invite_code)) and m.id = p_member_id;
  if v_trip_id is null then
    raise exception '초대 코드나 멤버가 맞지 않다' using errcode = 'no_data_found';
  end if;

  -- 같은 여행에서 이미 다른 멤버를 차지하고 있었다면 풀어준다
  update public.members set user_id = null
  where trip_id = v_trip_id and user_id = v_uid and id <> p_member_id;

  update public.members set user_id = v_uid where id = p_member_id;

  return v_trip_id;
end;
$$;

-- 함수 실행 권한: 기본(public)에서 빼고, 로그인한 사용자에게 필요한 것만 준다
revoke execute on function
  public.check_expense_currency(),
  public.check_expense_splits(),
  public.touch_updated_at(),
  public.is_trip_member(uuid),
  public.gen_invite_code(),
  public.create_trip(text, date, date, text, text, text[]),
  public.preview_trip(text),
  public.claim_member(text, uuid)
from public, anon, authenticated;

grant execute on function
  public.is_trip_member(uuid),
  public.create_trip(text, date, date, text, text, text[]),
  public.preview_trip(text),
  public.claim_member(text, uuid)
to authenticated;
