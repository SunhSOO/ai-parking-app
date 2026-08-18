-- book_facility_slot 의 status 값이 enum으로 들어가지 않던 문제 수정.
--
-- `case when ... then 'waiting' else 'confirmed' end` 는 양쪽 branch가 모두
-- unknown 리터럴이라 Postgres가 text로 확정해 버린다. 그래서 booking_status
-- 컬럼에 넣을 때 42804(column "status" is of type booking_status but expression
-- is of type text)로 실패했다. 명시적 캐스트를 붙인다.
--
-- 단일 리터럴('detecting' 등)은 unknown 그대로라 enum으로 잘 들어간다.
-- 문제가 되는 건 CASE처럼 타입이 확정되는 식뿐이다.

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
          (case when v_hold_id is null then 'waiting' else 'confirmed' end)
            ::public.booking_status)
  returning * into v_booking;

  return v_booking;
end;
$$;

grant execute on function public.book_facility_slot(uuid) to authenticated;
