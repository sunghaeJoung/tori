-- confirm_settlement의 "그사이 지출이 바뀌었다" 오류 코드를 바꾼다.
--
-- serialization_failure(40001)는 PostgREST가 "다시 시도하면 될 오류"로 보고 같은 요청을
-- 끝없이 다시 실행한다. 이 오류는 다시 해도 똑같이 실패하므로 앱 전용 코드(TR409)로 바꾼다.
-- (권한 설정은 20261023020000 그대로. create or replace는 권한을 유지한다)

create or replace function public.confirm_settlement(
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
    raise exception '그사이 지출이 바뀌었다' using errcode = 'TR409';
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
