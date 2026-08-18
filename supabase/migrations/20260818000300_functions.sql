-- =============================================================================
-- RPC — 앱이 호출하는 서버 함수
-- 동시성이 걸리거나(잔여 슬롯·주차면) 접수번호가 필요한 작업은 전부 여기로 모은다.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 일자별 접수번호 카운터  →  R-2026-0811-042
-- -----------------------------------------------------------------------------
create table public.daily_counters (
  day   date not null,
  kind  text not null,
  n     int  not null default 0,
  primary key (day, kind)
);

create or replace function public.next_receipt_no(p_kind text, p_prefix text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day date := (now() at time zone 'Asia/Seoul')::date;
  v_n   int;
begin
  insert into public.daily_counters (day, kind, n)
  values (v_day, p_kind, 1)
  on conflict (day, kind) do update set n = public.daily_counters.n + 1
  returning n into v_n;

  return format('%s-%s-%s-%s',
                p_prefix,
                to_char(v_day, 'YYYY'),
                to_char(v_day, 'MMDD'),
                lpad(v_n::text, 3, '0'));
end;
$$;

-- -----------------------------------------------------------------------------
-- 주변 장애인주차면 — 지도 화면과 지오펜스 등록에 함께 쓴다.
-- iOS 지오펜스 상한이 20개이므로 기본 limit도 20.
-- -----------------------------------------------------------------------------
create or replace function public.nearby_spots(
  p_lat        double precision,
  p_lng        double precision,
  p_radius_m   int default 3000,
  p_limit      int default 20
)
returns table (
  id          uuid,
  name        text,
  address     text,
  lat         double precision,
  lng         double precision,
  total       int,
  available   int,
  radius_m    int,
  camera_zone boolean,
  note        text,
  distance_m  double precision,
  updated_at  timestamptz
)
language sql
stable
as $$
  select s.id, s.name, s.address,
         st_y(s.geog::geometry), st_x(s.geog::geometry),
         s.total, s.available, s.radius_m, s.camera_zone, s.note,
         st_distance(s.geog, st_point(p_lng, p_lat)::geography),
         s.updated_at
  from public.parking_spots s
  where st_dwithin(s.geog, st_point(p_lng, p_lat)::geography, p_radius_m)
  order by 12
  limit p_limit;
$$;

-- -----------------------------------------------------------------------------
-- 자동 인증 시작
-- 지오펜스 진입 콜백이 호출한다. 이미 진행 중인 세션이 있으면 그걸 그대로 돌려준다
-- (OS가 진입 이벤트를 중복 발화하는 경우가 있다).
-- -----------------------------------------------------------------------------
create or replace function public.start_certification(
  p_spot_id uuid,
  p_method  public.cert_method default 'auto_geofence'
)
returns public.certifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_spot    public.parking_spots;
  v_vehicle public.vehicles;
  v_cert    public.certifications;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_cert
  from public.certifications
  where user_id = v_user
    and ended_at is null
    and status in ('detecting', 'matching', 'sending', 'verified')
  limit 1;

  if found then
    return v_cert;
  end if;

  select * into v_spot from public.parking_spots where id = p_spot_id;
  if not found then
    raise exception 'parking spot % not found', p_spot_id using errcode = 'P0002';
  end if;

  select * into v_vehicle
  from public.vehicles
  where user_id = v_user
  order by is_primary desc, created_at
  limit 1;

  insert into public.certifications
    (user_id, spot_id, vehicle_id, spot_name, plate, status, method, radius_m)
  values
    (v_user, v_spot.id, v_vehicle.id, v_spot.name, v_vehicle.plate,
     'detecting', p_method, v_spot.radius_m)
  returning * into v_cert;

  return v_cert;
end;
$$;

-- -----------------------------------------------------------------------------
-- 인증 종료 (주차면 이탈)
-- -----------------------------------------------------------------------------
create or replace function public.end_certification(p_cert_id uuid)
returns public.certifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cert public.certifications;
begin
  update public.certifications
     set ended_at = now(),
         status   = case when status = 'verified' then 'ended' else status end
   where id = p_cert_id
     and user_id = auth.uid()
     and ended_at is null
  returning * into v_cert;

  return v_cert;
end;
$$;

-- =============================================================================
-- 복지혜택 적합도 매칭
--
-- benefits.eligibility 형식:
--   {
--     "base": 40,
--     "rules": [
--       {"key":"disability_type","op":"eq","value":"지체장애","weight":20,"reason":"지체장애 2급"},
--       {"key":"walking_impaired","op":"true","weight":25,"reason":"보행상 장애"},
--       {"key":"interests","op":"contains","value":"culture","weight":10,"reason":"관심: 문화·체육"}
--     ]
--   }
--
-- op: eq | in | true | gte | lte | contains | exists
-- score = min(100, base + 일치한 rule 들의 weight 합)
-- reasons = 일치한 rule 들의 reason  → 카드의 '매칭 근거 태그'가 된다
-- =============================================================================
create or replace function public.user_facts(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'disability_type',  p.disability_type,
    'disability_grade', p.disability_grade,
    'walking_impaired', p.walking_impaired,
    'sido',             p.sido,
    'sigungu',          p.sigungu,
    'age',              case when p.birth_year is null then null
                             else extract(year from now())::int - p.birth_year end,
    'household_size',   p.household_size,
    'income_bracket',   p.income_bracket,
    'permit_type',      p.permit_type,
    'interests',        to_jsonb(p.interests),
    'has_vehicle',      exists (select 1 from public.vehicles v where v.user_id = p.id),
    'cert_count',       (select count(*) from public.certifications c
                          where c.user_id = p.id and c.status in ('verified','ended'))
  )
  from public.profiles p
  where p.id = p_user;
$$;

create or replace function public.match_benefits(p_user uuid)
returns table (benefit_id text, score int, reasons text[])
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_facts jsonb := public.user_facts(p_user);
  b       record;
  r       jsonb;
  v_score int;
  v_reasons text[];
  v_hit   boolean;
  v_fact  jsonb;
begin
  if v_facts is null then
    return;
  end if;

  for b in select id, eligibility from public.benefits where active loop
    v_score   := coalesce((b.eligibility ->> 'base')::int, 40);
    v_reasons := '{}';

    for r in select * from jsonb_array_elements(coalesce(b.eligibility -> 'rules', '[]'::jsonb)) loop
      v_fact := v_facts -> (r ->> 'key');
      v_hit  := false;

      if v_fact is not null and jsonb_typeof(v_fact) <> 'null' then
        case r ->> 'op'
          when 'eq'       then v_hit := (v_fact #>> '{}') = (r ->> 'value');
          when 'in'       then v_hit := (v_fact #>> '{}') in
                                        (select jsonb_array_elements_text(r -> 'value'));
          when 'true'     then v_hit := (v_fact #>> '{}')::boolean;
          when 'gte'      then v_hit := (v_fact #>> '{}')::numeric >= (r ->> 'value')::numeric;
          when 'lte'      then v_hit := (v_fact #>> '{}')::numeric <= (r ->> 'value')::numeric;
          when 'contains' then v_hit := v_fact ? (r ->> 'value');
          when 'exists'   then v_hit := true;
          else                 v_hit := false;
        end case;
      end if;

      if v_hit then
        v_score := v_score + coalesce((r ->> 'weight')::int, 0);
        if r ? 'reason' then
          v_reasons := v_reasons || (r ->> 'reason');
        end if;
      end if;
    end loop;

    benefit_id := b.id;
    score      := least(100, v_score);
    reasons    := v_reasons;
    return next;
  end loop;
end;
$$;

-- 피드 화면이 그대로 쓰는 뷰 함수 (적합도 내림차순)
create or replace function public.benefits_for_me(p_cat text default null)
returns table (
  id           text,
  cat          text,
  cat_label    text,
  title        text,
  summary      text,
  org          text,
  detail_rows  jsonb,
  foot         text,
  due_date     date,
  due_label    text,
  score        int,
  reasons      text[],
  applied      boolean
)
language sql
stable
as $$
  select b.id, b.cat, b.cat_label, b.title, b.summary, b.org, b.detail_rows,
         b.foot, b.due_date, b.due_label,
         m.score, m.reasons,
         exists (select 1 from public.benefit_applications a
                  where a.benefit_id = b.id and a.user_id = auth.uid())
  from public.benefits b
  join public.match_benefits(auth.uid()) m on m.benefit_id = b.id
  where b.active
    and (p_cat is null or p_cat = 'all' or b.cat = p_cat)
  order by m.score desc, b.due_date nulls last;
$$;

-- =============================================================================
-- 시설 예약 — 잔여 슬롯과 목적지 주차면 확보를 한 트랜잭션으로
-- =============================================================================
create or replace function public.book_facility_slot(p_slot_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_slot    public.facility_slots;
  v_fac     public.facilities;
  v_hold_id uuid;
  v_booking public.bookings;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_slot from public.facility_slots where id = p_slot_id for update;
  if not found then
    raise exception 'slot not found' using errcode = 'P0002';
  end if;
  if v_slot.remaining <= 0 then
    raise exception '이미 마감된 시간입니다' using errcode = 'P0001';
  end if;

  select * into v_fac from public.facilities where id = v_slot.facility_id;

  update public.facility_slots
     set remaining = remaining - 1
   where id = p_slot_id;

  -- 목적지 주차면 1면 확보. 남은 면이 없으면 hold 없이 '대기' 예약이 된다.
  if v_fac.parking_spot_id is not null then
    update public.parking_spots
       set available = available - 1, updated_at = now()
     where id = v_fac.parking_spot_id and available > 0;

    if found then
      insert into public.parking_holds (spot_id, user_id, hold_from, hold_to)
      values (v_fac.parking_spot_id, v_user,
              v_slot.slot_at - interval '30 minutes',
              v_slot.slot_at + interval '2 hours')
      returning id into v_hold_id;
    end if;
  end if;

  insert into public.bookings (user_id, facility_id, slot_id, hold_id, status)
  values (v_user, v_fac.id, p_slot_id, v_hold_id,
          case when v_hold_id is null then 'waiting' else 'confirmed' end)
  returning * into v_booking;

  return v_booking;
end;
$$;

create or replace function public.cancel_booking(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_hold    public.parking_holds;
begin
  select * into v_booking
  from public.bookings
  where id = p_booking_id and user_id = auth.uid() and status <> 'cancelled'
  for update;

  if not found then
    raise exception 'booking not found' using errcode = 'P0002';
  end if;

  update public.facility_slots
     set remaining = least(capacity, remaining + 1)
   where id = v_booking.slot_id;

  if v_booking.hold_id is not null then
    update public.parking_holds set released = true
     where id = v_booking.hold_id and not released
    returning * into v_hold;

    if found then
      update public.parking_spots
         set available = least(total, available + 1), updated_at = now()
       where id = v_hold.spot_id;
    end if;
  end if;

  update public.bookings set status = 'cancelled'
   where id = p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

-- =============================================================================
-- 부정주차 신고 접수 (접수번호 발급 포함)
-- =============================================================================
create or replace function public.submit_report(
  p_reason     public.report_reason,
  p_photo_path text default null,
  p_spot_id    uuid default null,
  p_memo       text default null
)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  insert into public.reports (user_id, reason, photo_path, spot_id, memo, receipt_no)
  values (auth.uid(), p_reason, p_photo_path, p_spot_id, p_memo,
          public.next_receipt_no('report', 'R'))
  returning * into v_report;

  return v_report;
end;
$$;

-- =============================================================================
-- 뷰 — 앱이 그대로 읽는 형태
-- geography 컬럼은 클라이언트에서 못 읽으므로 lat/lng으로 펼쳐 준다.
-- security_invoker = on 이라 base 테이블의 RLS가 그대로 적용된다.
-- =============================================================================
create or replace view public.parking_spots_geo
with (security_invoker = on) as
  select s.id, s.name, s.address,
         st_y(s.geog::geometry) as lat,
         st_x(s.geog::geometry) as lng,
         s.total, s.available, s.radius_m, s.camera_zone, s.note, s.updated_at
  from public.parking_spots s;

create or replace view public.facilities_geo
with (security_invoker = on) as
  select f.id, f.cat, f.name, f.tag, f.description, f.icon,
         st_y(f.geog::geometry) as lat,
         st_x(f.geog::geometry) as lng,
         f.parking_spot_id,
         p.available as parking_available,
         p.total     as parking_total
  from public.facilities f
  left join public.parking_spots p on p.id = f.parking_spot_id
  where f.active;

create or replace view public.bookings_view
with (security_invoker = on) as
  select b.id, b.user_id, b.facility_id, f.name as facility_name,
         s.slot_at, b.status, b.hold_id, b.created_at
  from public.bookings b
  join public.facilities f     on f.id = b.facility_id
  join public.facility_slots s on s.id = b.slot_id;

grant select on public.parking_spots_geo, public.facilities_geo, public.bookings_view
  to authenticated;

-- -----------------------------------------------------------------------------
-- 실행 권한
-- -----------------------------------------------------------------------------
grant execute on function public.nearby_spots(double precision, double precision, int, int) to authenticated;
grant execute on function public.start_certification(uuid, public.cert_method)             to authenticated;
grant execute on function public.end_certification(uuid)                                   to authenticated;
grant execute on function public.match_benefits(uuid)                                      to authenticated;
grant execute on function public.benefits_for_me(text)                                     to authenticated;
grant execute on function public.book_facility_slot(uuid)                                  to authenticated;
grant execute on function public.cancel_booking(uuid)                                      to authenticated;
grant execute on function public.submit_report(public.report_reason, text, uuid, text)     to authenticated;

revoke execute on function public.next_receipt_no(text, text) from authenticated, anon;
revoke execute on function public.user_facts(uuid)            from anon;
