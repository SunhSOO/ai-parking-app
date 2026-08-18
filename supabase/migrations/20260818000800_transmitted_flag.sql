-- 단속 시스템에 실제로 전달했는지를 기록한다.
--
-- 왜: 지금은 G.Eye-Parking 엔드포인트가 없어 전달 단계를 건너뛰는데,
-- 앱은 "단속 시스템에 인증 전달 — 전달됨"이라고 표시하고 있었다.
-- 아무 데도 보내지 않고 보냈다고 말하는 것은, 이 앱에서 가장 하면 안 되는 거짓말이다.
-- (사용자는 그 표시를 믿고 차를 두고 간다)
--
-- 이 플래그는 certify-parking Edge Function 이 G.Eye-Parking 으로부터 2xx 응답을
-- 받았을 때만 true 가 된다. DB 트리거는 건드리지 않는다.

alter table public.certifications
  add column if not exists transmitted boolean not null default false;

comment on column public.certifications.transmitted is
  '단속 시스템(G.Eye-Parking)에 인증을 실제로 전달했는지. 연동 전에는 항상 false.';
