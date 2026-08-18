-- 자동 인증을 Edge Function 없이 DB 안에서 끝낸다.
--
-- 왜: 인증 세션이 'detecting'에서 멈춰 있었다. 다음 단계로 넘기는 주체가
-- certify-parking Edge Function 인데, 배포하려면 Management API 토큰이 필요하다.
--
-- 그런데 지금 단계에서 그 함수가 실제로 하는 일은 두 가지뿐이다:
--   1) 등록 차량 대조  → 순수 DB 조회
--   2) G.Eye-Parking 전달 → 아직 엔드포인트가 없어 건너뛴다
-- 즉 외부 호출이 없으므로 DB 트리거로 충분하다. 함수 배포도, 웹훅 설정도 필요 없다.
--
-- Edge Function 이 있던 3.9초는 화면 연출을 위한 sleep 이었다. 트리거는 즉시
-- 끝내므로 사용자는 도착하자마자 "인증됐어요"를 본다. 실제로 즉시 끝나는 게 맞다.
--
-- ⚠️ G.Eye-Parking 연동이 확정되면: 이 트리거를 지우고
--    certify-parking Edge Function + Database Webhook 으로 돌아간다.
--    (외부 HTTP 호출은 트리거 안에서 하면 안 된다 — INSERT 를 붙잡고 있게 된다)
--    되돌리는 법: drop trigger certifications_certify on public.certifications;

create or replace function public.certify_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plate text;
begin
  -- 등록 차량 대조. 주차장 카메라가 읽은 번호와 맞출 대상이다.
  select plate into v_plate
  from public.vehicles
  where user_id = new.user_id
  order by is_primary desc, created_at
  limit 1;

  if v_plate is null then
    new.status      := 'failed';
    new.fail_reason := '등록된 차량이 없습니다';
    new.ended_at    := now();
    return new;
  end if;

  new.plate       := coalesce(new.plate, v_plate);
  new.status      := 'verified';
  new.verified_at := now();
  new.receipt_no  := public.next_receipt_no('certification', 'C');
  new.fee_note    := '무료 · 장애인 감면 적용 (단속 시스템 연동 대기)';

  return new;
end;
$$;

-- BEFORE INSERT 인 이유: start_certification 의 RETURNING 이 최종 상태를 그대로
-- 돌려주게 하려면 행이 쓰이기 전에 값을 확정해야 한다. AFTER 트리거로 하면
-- 앱은 'detecting' 을 받고 Realtime 을 한 번 더 기다려야 한다.
drop trigger if exists certifications_certify on public.certifications;

create trigger certifications_certify
  before insert on public.certifications
  for each row execute function public.certify_on_insert();
