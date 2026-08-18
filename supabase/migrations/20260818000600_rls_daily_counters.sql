-- RLS가 빠져 있던 테이블 두 개를 막는다.
--
-- 왜 문제였나: public 스키마의 테이블은 PostgREST로 그대로 노출되고
-- anon/authenticated 롤에 기본 권한이 있다. RLS가 없으면 **익명 키만으로
-- 누구나 읽고 쓸 수 있다.** (실제로 익명 키로 daily_counters에 행이 써졌다)

-- 1) daily_counters — 접수번호 카운터. 클라이언트가 만질 일이 전혀 없다.
--
-- 정책을 하나도 만들지 않는 것이 의도다. RLS만 켜면 anon/authenticated는
-- 완전히 차단되고, next_receipt_no()는 SECURITY DEFINER라 소유자(postgres)
-- 권한으로 실행돼 RLS를 우회하므로 접수번호 발급은 그대로 동작한다.
alter table public.daily_counters enable row level security;

-- 2) spatial_ref_sys — PostGIS가 만든 좌표계 참조표.
--
-- 확장이 소유한 테이블이라 RLS를 켤 권한이 없을 수 있다. 대신 권한을 회수한다.
-- 공개 표준 데이터라 유출 위험은 낮지만, 쓰기가 열려 있는 것은 막아야 한다.
-- 앱은 이 테이블을 직접 읽지 않는다 (PostGIS 함수가 내부적으로만 쓴다).
do $$
begin
  revoke all on public.spatial_ref_sys from anon, authenticated;
exception
  when insufficient_privilege then
    raise notice 'spatial_ref_sys 권한 회수 실패 — 대시보드에서 직접 실행하세요';
end $$;
