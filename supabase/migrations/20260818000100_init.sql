-- =============================================================================
-- G-AILAB AI Parking Companion — 초기 스키마
-- 장애인 주차 자동인증 · 복지혜택 · 시설예약 앱
-- =============================================================================

create extension if not exists postgis;
create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- enums
-- -----------------------------------------------------------------------------
create type public.permit_type as enum ('self', 'guardian');

create type public.cert_status as enum (
  'detecting',   -- 주차면 반경 진입 감지
  'matching',    -- 등록 차량 번호 대조 중
  'sending',     -- 단속 시스템(G.Eye-Parking)에 전달 중
  'verified',    -- 인증 완료 · 단속 대상 제외
  'failed',      -- 대조 실패 / 전달 실패
  'ended'        -- 주차면 이탈로 종료
);

create type public.cert_method as enum ('auto_geofence', 'manual', 'booking_linked');

create type public.booking_status as enum ('confirmed', 'waiting', 'cancelled');

create type public.report_reason as enum (
  'no_permit',        -- 표지 없이 주차
  'permit_no_rider',  -- 표지는 있지만 본인 미탑승
  'encroach',         -- 주차면 침범 · 통로 방해
  'abandoned'         -- 장기 방치 차량
);

create type public.report_status as enum ('received', 'reviewing', 'confirmed', 'dismissed');

-- -----------------------------------------------------------------------------
-- updated_at 자동 갱신
-- -----------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- profiles — 소셜 로그인 계정 + 복지카드로 확인된 자격 정보
-- 복지카드 촬영본은 저장하지 않는다. 검증 결과(자격 여부)만 여기 남는다.
-- -----------------------------------------------------------------------------
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  name              text,
  disability_type   text,                       -- 지체장애 / 시각장애 …
  disability_grade  text,                       -- 2급 / 심한 장애 …
  walking_impaired  boolean not null default false,  -- 보행상 장애 (혜택 매칭 근거)
  sido              text,                       -- 경기도
  sigungu           text,                       -- 성남시 중원구
  birth_year        int,
  household_size    int,
  income_bracket    text,                       -- 차상위계층 / 기초생활수급 / 일반
  permit_type       public.permit_type not null default 'self',
  interests         text[] not null default '{}',    -- 관심 카테고리 (혜택 매칭 근거)
  notif             jsonb  not null default
                      '{"mobility":true,"care":true,"health":false,"culture":true,"tax":true}'::jsonb,
  card_verified_at  timestamptz,
  onboarded_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

comment on column public.profiles.notif is '혜택 알림 수신 카테고리 토글 (마이페이지)';

-- 신규 가입 시 빈 프로필 생성
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name',
                           new.raw_user_meta_data ->> 'full_name'))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- vehicles — 등록 차량 (주차장 카메라가 읽은 번호와 대조할 대상)
-- -----------------------------------------------------------------------------
create table public.vehicles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  plate       text not null,
  is_primary  boolean not null default true,
  created_at  timestamptz not null default now()
);

create index vehicles_user_idx on public.vehicles (user_id);
create unique index vehicles_one_primary_idx
  on public.vehicles (user_id) where is_primary;

-- -----------------------------------------------------------------------------
-- parking_spots — 장애인주차면
-- -----------------------------------------------------------------------------
create table public.parking_spots (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  address      text,
  geog         geography(Point, 4326) not null,
  total        int  not null default 0,
  available    int  not null default 0,
  radius_m     int  not null default 90,          -- 자동 인증 지오펜스 반경
  camera_zone  boolean not null default false,    -- 카메라 단속 구역 여부
  note         text,                              -- '예약 연동' 같은 부가 표시
  updated_at   timestamptz not null default now()
);

create index parking_spots_geog_idx on public.parking_spots using gist (geog);

-- -----------------------------------------------------------------------------
-- certifications — 자동 인증 세션 (핵심 테이블)
-- 상태 전이는 Edge Function(service_role)만 수행한다.
-- -----------------------------------------------------------------------------
create table public.certifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  spot_id      uuid references public.parking_spots(id) on delete set null,
  vehicle_id   uuid references public.vehicles(id) on delete set null,
  spot_name    text,                              -- 스냅샷 (주차면이 지워져도 이력 유지)
  plate        text,                              -- 스냅샷
  status       public.cert_status not null default 'detecting',
  method       public.cert_method not null default 'auto_geofence',
  radius_m     int not null default 90,
  fee_note     text default '무료 · 장애인 감면 적용',
  receipt_no   text unique,
  fail_reason  text,
  started_at   timestamptz not null default now(),
  verified_at  timestamptz,
  ended_at     timestamptz,
  updated_at   timestamptz not null default now()
);

create index certifications_user_started_idx
  on public.certifications (user_id, started_at desc);

-- 사용자당 진행 중인 인증은 하나만
create unique index certifications_one_active_idx
  on public.certifications (user_id)
  where status in ('detecting', 'matching', 'sending', 'verified')
    and ended_at is null;

create trigger certifications_touch before update on public.certifications
  for each row execute function public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- benefits — 복지혜택 카탈로그 + 매칭 규칙
-- -----------------------------------------------------------------------------
create table public.benefits (
  id           text primary key,                 -- 'b1' … (시드 데이터 가독성)
  cat          text not null,                    -- mobility|care|health|culture|tax
  cat_label    text not null,
  title        text not null,
  summary      text not null,
  org          text,
  detail_rows  jsonb not null default '[]'::jsonb,   -- [["지원 내용","…"], …]
  foot         text,
  due_date     date,
  due_label    text,                             -- '상시 신청' 처럼 날짜가 없는 경우
  eligibility  jsonb not null default '{}'::jsonb,   -- 아래 match_benefits() 참조
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

create index benefits_cat_idx on public.benefits (cat) where active;

create table public.benefit_applications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  benefit_id  text not null references public.benefits(id) on delete cascade,
  status      text not null default 'received',  -- received|reviewing|approved|rejected
  applied_at  timestamptz not null default now(),
  unique (user_id, benefit_id)
);

-- -----------------------------------------------------------------------------
-- facilities / slots — 체육 · 생활시설과 예약 슬롯
-- -----------------------------------------------------------------------------
create table public.facilities (
  id            text primary key,                -- 'f1' …
  cat           text not null,                   -- sports|rehab|culture|life|move
  name          text not null,
  tag           text,                            -- '장애인 전용'
  description   text,
  icon          text,                            -- 이모지 (M8에서 Lucide로 교체)
  geog          geography(Point, 4326),
  parking_spot_id uuid references public.parking_spots(id) on delete set null,
  active        boolean not null default true
);

create index facilities_cat_idx on public.facilities (cat) where active;
create index facilities_geog_idx on public.facilities using gist (geog);

create table public.facility_slots (
  id           uuid primary key default gen_random_uuid(),
  facility_id  text not null references public.facilities(id) on delete cascade,
  slot_at      timestamptz not null,
  capacity     int not null default 0,
  remaining    int not null default 0,
  unique (facility_id, slot_at),
  check (remaining >= 0 and remaining <= capacity)
);

create index facility_slots_lookup_idx on public.facility_slots (facility_id, slot_at);

-- -----------------------------------------------------------------------------
-- bookings + parking_holds — 예약과 목적지 주차면 확보
-- -----------------------------------------------------------------------------
create table public.parking_holds (
  id         uuid primary key default gen_random_uuid(),
  spot_id    uuid not null references public.parking_spots(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  hold_from  timestamptz not null,
  hold_to    timestamptz not null,
  released   boolean not null default false,
  created_at timestamptz not null default now()
);

create index parking_holds_spot_idx on public.parking_holds (spot_id, hold_from);

create table public.bookings (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  facility_id text not null references public.facilities(id) on delete cascade,
  slot_id     uuid not null references public.facility_slots(id) on delete cascade,
  hold_id     uuid references public.parking_holds(id) on delete set null,
  status      public.booking_status not null default 'confirmed',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index bookings_user_idx on public.bookings (user_id, created_at desc);
create unique index bookings_one_per_slot_idx
  on public.bookings (user_id, slot_id) where status <> 'cancelled';

create trigger bookings_touch before update on public.bookings
  for each row execute function public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- reports / warnings — 부정주차 신고와 내가 받은 경고
-- -----------------------------------------------------------------------------
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  reason      public.report_reason not null,
  photo_path  text,                              -- storage: reports/{user_id}/{uuid}.jpg
  spot_id     uuid references public.parking_spots(id) on delete set null,
  memo        text,
  status      public.report_status not null default 'received',
  receipt_no  text unique,
  created_at  timestamptz not null default now()
);

create index reports_user_idx on public.reports (user_id, created_at desc);

create table public.warnings (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null,                     -- 'uncertified_parking'
  label       text not null,                     -- '인증 없이 주차 1회'
  spot_name   text,
  detail      text,
  occurred_at timestamptz not null default now()
);

create index warnings_user_idx on public.warnings (user_id, occurred_at desc);

-- -----------------------------------------------------------------------------
-- devices — 푸시 토큰 (FCM/APNs)
-- -----------------------------------------------------------------------------
create table public.devices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  fcm_token  text not null unique,
  platform   text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

create index devices_user_idx on public.devices (user_id);

create trigger devices_touch before update on public.devices
  for each row execute function public.touch_updated_at();
