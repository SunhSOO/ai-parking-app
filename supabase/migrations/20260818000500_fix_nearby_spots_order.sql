-- nearby_spots 가 거리순으로 정렬되지 않던 문제 수정.
--
-- `order by 12` 는 12번째 출력 컬럼인 updated_at 을 가리켰다 (거리는 11번째).
-- 시드 데이터에서는 updated_at 순서가 우연히 거리 순서와 비슷해 눈에 띄지 않았지만,
-- 실제로는 "가장 가까운 빈 자리"가 엉뚱한 주차면으로 나오고, 지오펜스 등록도
-- iOS 상한(20개)에 걸릴 때 먼 곳부터 잘려 나갈 수 있었다.
--
-- 위치 번호 대신 컬럼 이름으로 정렬해 같은 실수가 반복되지 않게 한다.

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
         st_y(s.geog::geometry) as lat,
         st_x(s.geog::geometry) as lng,
         s.total, s.available, s.radius_m, s.camera_zone, s.note,
         st_distance(s.geog, st_point(p_lng, p_lat)::geography) as distance_m,
         s.updated_at
  from public.parking_spots s
  where st_dwithin(s.geog, st_point(p_lng, p_lat)::geography, p_radius_m)
  order by distance_m
  limit p_limit;
$$;

grant execute on function public.nearby_spots(double precision, double precision, int, int)
  to authenticated;
