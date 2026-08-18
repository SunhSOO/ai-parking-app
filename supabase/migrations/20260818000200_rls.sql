-- =============================================================================
-- Row Level Security
-- 원칙: 개인 데이터는 본인 행만. 카탈로그(주차면·시설·혜택)는 로그인 사용자 읽기 전용.
--       인증 세션의 상태 전이는 service_role(Edge Function)만 수행한다.
-- =============================================================================

alter table public.profiles              enable row level security;
alter table public.vehicles              enable row level security;
alter table public.parking_spots         enable row level security;
alter table public.certifications        enable row level security;
alter table public.benefits              enable row level security;
alter table public.benefit_applications  enable row level security;
alter table public.facilities            enable row level security;
alter table public.facility_slots        enable row level security;
alter table public.parking_holds         enable row level security;
alter table public.bookings              enable row level security;
alter table public.reports               enable row level security;
alter table public.warnings              enable row level security;
alter table public.devices               enable row level security;

-- -----------------------------------------------------------------------------
-- 본인 소유 데이터
-- -----------------------------------------------------------------------------
create policy profiles_self_select on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_self_update on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- insert는 handle_new_user() 트리거(security definer)가 담당한다.

create policy vehicles_self_all on public.vehicles
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy benefit_apps_self_select on public.benefit_applications
  for select to authenticated using (user_id = auth.uid());
create policy benefit_apps_self_insert on public.benefit_applications
  for insert to authenticated with check (user_id = auth.uid());

create policy bookings_self_select on public.bookings
  for select to authenticated using (user_id = auth.uid());
-- 예약 생성/취소는 book_facility_slot() / cancel_booking() RPC로만 (잔여 슬롯 동시성 때문).

create policy holds_self_select on public.parking_holds
  for select to authenticated using (user_id = auth.uid());

create policy reports_self_select on public.reports
  for select to authenticated using (user_id = auth.uid());
create policy reports_self_insert on public.reports
  for insert to authenticated with check (user_id = auth.uid());

create policy warnings_self_select on public.warnings
  for select to authenticated using (user_id = auth.uid());

create policy devices_self_all on public.devices
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 인증 세션 — 읽기만 본인. 쓰기는 전부 service_role.
-- 앱은 start_certification() RPC로 시작하고 이후는 Realtime으로 구독만 한다.
-- -----------------------------------------------------------------------------
create policy certifications_self_select on public.certifications
  for select to authenticated using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 공개 카탈로그 (로그인 사용자 읽기 전용)
-- -----------------------------------------------------------------------------
create policy parking_spots_read on public.parking_spots
  for select to authenticated using (true);

create policy benefits_read on public.benefits
  for select to authenticated using (active);

create policy facilities_read on public.facilities
  for select to authenticated using (active);

create policy facility_slots_read on public.facility_slots
  for select to authenticated using (true);

-- -----------------------------------------------------------------------------
-- Realtime — 앱이 자기 인증 세션의 단계 진행을 구독한다
-- -----------------------------------------------------------------------------
alter publication supabase_realtime add table public.certifications;

-- -----------------------------------------------------------------------------
-- Storage — 신고 사진. 본인 폴더에만 올리고 본인만 읽는다.
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('reports', 'reports', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy report_photo_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'reports' and (storage.foldername(name))[1] = auth.uid()::text);

create policy report_photo_select on storage.objects
  for select to authenticated
  using (bucket_id = 'reports' and (storage.foldername(name))[1] = auth.uid()::text);
