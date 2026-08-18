# G-AILAB AI Parking Companion

장애인 주차 **자동 인증** · 맞춤 복지혜택 · 체육/생활시설 예약 앱.
`Desktop/장애인 앱/장애인 동승인증 앱.dc.html` 프로토타입(12화면)을 Flutter + Supabase로 재구현한 것.

핵심 가치는 **버튼 0개 인증**이다. 장애인주차면 반경에 들어오면 앱이 스스로 인증을 시작하고
GPS 반경 확인 → 등록 차량 대조 → 단속 시스템(G.Eye-Parking) 전달까지 끝낸다.

```
ai-parking-app/
├─ app/                     Flutter 앱 (Android · iOS)
├─ supabase/
│  ├─ migrations/           스키마 · RLS · RPC · 뷰
│  ├─ functions/            Edge Functions (naver-auth, certify-parking)
│  └─ seed.sql              프로토타입 데이터 시드
└─ config.example.json      빌드 시 주입할 키 목록
```

> **남은 설정은 [docs/SETUP.md](docs/SETUP.md) 에 순서대로 정리돼 있다.**
> RLS 구멍 막기 → Edge Function 배포 → 소셜 로그인·지도 키 발급.

## 지금 바로 실행하기 (키 없이)

키가 하나도 없어도 **12개 화면이 전부 동작한다.** 목업 리포지토리가 프로토타입과 같은
데이터를 메모리로 제공하고, 자동 인증도 같은 타이밍(1.1s → 2.5s → 3.9s)으로 진행된다.

```bash
cd app
flutter run           # Android 기기/에뮬레이터 또는 iOS
flutter test          # 위젯 테스트 10개
flutter analyze
```

목업 모드에서 확인할 수 있는 것:

- 홈 히어로의 **지금 인증 실행** → 바텀시트가 3단계를 거쳐 "인증됐어요 🎉"까지
- **숨기기**를 눌러도 인증이 백그라운드에서 계속 진행 → 홈 히어로가 완료 모드로 전환
- 혜택 피드 적합도(98/95/92/88/84/79)와 카테고리 필터, 신청 → "접수됨"
- 시설 검색·예약(날짜/시간 슬롯) → 내 예약에 추가, 취소
- 부정주차 신고 → 접수번호 발급, 마이페이지 알림 토글

## 실제 백엔드로 붙이기

### 1. 키 발급

| 항목 | 어디서 | 쓰이는 곳 |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | Supabase 대시보드 | 전부 |
| `NAVER_MAP_CLIENT_ID` | NCP → Maps → Application 등록(Dynamic Map 체크) | 주차면 지도 |
| `KAKAO_NATIVE_APP_KEY`, `KAKAO_JS_KEY` | 카카오 개발자 | 카카오 로그인 |
| `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_SERVER_CLIENT_ID` | Google Cloud OAuth | 구글 로그인 |
| 네이버 로그인 Client ID/Secret | 네이버 개발자센터 | `naver-auth` 함수 |

`config.example.json`을 `app/config.json`으로 복사해 값을 채운 뒤:

```bash
cd app
flutter run --dart-define-from-file=config.json
```

키가 비어 있는 항목은 자동으로 목업으로 떨어진다 (예: 네이버 지도 키만 없으면 지도만 격자 목업).

### 연결 상태 (2026-08-18)

클라우드 프로젝트(Tokyo 리전)에 스키마·시드가 적용돼 있고 앱이 붙어 있다.
프로젝트 ref·키는 `app/config.json`에만 두고 저장소에는 올리지 않는다.
Docker 없이 `--db-url`로 직접 push했다 — 이 방식은 `supabase login`이 필요 없다.

```powershell
# 직접 연결(db.<ref>.supabase.co)은 IPv6 전용이라 이 PC에서 DNS가 안 잡힌다.
# Session pooler(aws-0-ap-northeast-1)를 쓴다.
$u = 'postgresql://postgres.<ref>:<password>@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres'
npx supabase db push --db-url $u --include-seed
npx supabase db query --db-url $u "select count(*) from parking_spots"
```

검증된 것: 카탈로그 읽기(로그인 필요), `benefits_for_me` 적합도 98/95/92/88/84/79,
`nearby_spots` 거리순, `book_facility_slot`/`cancel_booking` 트랜잭션(슬롯·주차면 동시 증감),
RLS(익명은 0건, 본인 행만), `start_certification`으로 인증 세션 생성.

**아직 안 된 것**: `certify-parking` Edge Function 미배포 → 인증이 `detecting`에서 멈춘다.
배포하려면 `npx supabase login` 이 필요하다 (Management API 토큰).

### 2. 데이터베이스

```bash
supabase link --project-ref <ref>
supabase db push          # migrations/ 적용
psql "$DATABASE_URL" -f supabase/seed.sql   # 또는 supabase db reset (로컬)
```

스키마 요약:

- `profiles` — 복지카드로 확인된 자격 정보. **촬영본은 저장하지 않는다.**
- `vehicles` / `parking_spots` / `certifications` — 자동 인증
- `benefits` + `match_benefits()` — 적합도와 근거 태그를 서버가 계산
- `facilities` / `facility_slots` / `bookings` / `parking_holds` — 예약과 주차면 확보
- `reports` / `warnings` — 신고와 경고

RLS는 개인 데이터를 본인 행으로 제한하고, `certifications`의 상태 전이는 service_role만
할 수 있게 막아 뒀다. 잔여 슬롯·주차면 확보처럼 동시성이 걸리는 작업은 전부 RPC로 모았다.

### 3. Edge Functions

```bash
supabase functions deploy naver-auth --no-verify-jwt
supabase functions deploy certify-parking
supabase secrets set GEYE_ENDPOINT=... GEYE_API_KEY=...
```

`certify-parking`은 **Database Webhook**(`certifications` INSERT)으로 걸어 두는 것을 권장한다.
지오펜스 백그라운드 isolate가 인증을 시작해도 항상 돌아야 하기 때문이다.

## 자동 인증이 실제로 도는 방식

```
앱 시작 → nearby_spots() 로 가까운 주차면 조회
      → native_geofence 로 최대 20개 등록 (iOS region monitoring 상한)
      → [OS] 반경 진입 → 백그라운드 isolate에서 콜백
             ├ 로컬 알림 "장애인주차면에 도착했어요"
             └ start_certification() → certify-parking 이 단계 진행
      → 앱이 앞으로 나오면 진행 중인 세션을 다시 읽어 시트를 띄운다
      → 반경 이탈 → end_certification()
```

설계상 지켜야 할 것:

- **시트를 닫아도 인증은 계속된다.** 시트 표시 여부(`hidden`)와 인증 상태는 완전히 분리돼 있다.
- 진행률은 서버가 알려 준 단계에서만 나온다. 실제보다 앞서 나가지 않는다.
- iOS `Always` 위치 권한이 없으면 백그라운드 인증이 불가능하다. 앱은 이 경우
  수동 실행(홈 히어로 CTA)을 주 경로로 안내해야 한다.

## 자동 인증을 에뮬레이터에서 검증하기

실기기 없이 진입 감지를 확인하는 방법. **목업 모드에서도 된다.**

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"

# 1. 에뮬레이터 (Google APIs 이미지 필요)
& "$sdk\emulator\emulator.exe" -avd pixel_geo -no-boot-anim

# 2. 앱 설치 후 권한 부여 (목업 모드는 온보딩을 건너뛰므로 직접 준다)
cd app; flutter install
foreach ($p in 'ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION','ACCESS_BACKGROUND_LOCATION','POST_NOTIFICATIONS') {
  & $adb shell pm grant kr.gailab.ai_parking "android.permission.$p"
}

# 3. 주차면에서 먼 곳 → 성남시청 주차장 B2 반경 안으로 이동
#    주의: geo fix 는 경도가 먼저다
& $adb emu geo fix 126.9780 37.5665   # 서울시청 — 아무 일도 없어야 정상
& $adb emu geo fix 127.1265 37.4200   # 성남시청 B2 — 인증 시트가 저절로 떠야 한다
```

시드에 있는 주차면 좌표:

| 주차면 | 위도, 경도 |
|---|---|
| 성남시청 주차장 B2 | 37.4200, 127.1265 |
| 중원구청 앞 노상 | 37.4306, 127.1373 |
| 반다비체육센터 지상 | 37.4128, 127.1430 |

### 검증 결과 (2026-08-18, Android 36 에뮬레이터 · 목업 모드)

`docs/screenshots/`에 캡처가 있다. **버튼을 하나도 누르지 않고** 아래가 그대로 재현됐다.

| 단계 | 확인된 것 |
|---|---|
| 반경 밖 (서울시청) | 홈 히어로 "자동 인증 대기 중" |
| 반경 진입 | 로그 `[foreground-geofence] 진입: 성남시청 주차장 B2`, 로컬 알림, 시트 자동 표시 |
| 진행 중 | 킥커 "주차면 감지", 진행바 28%, 3단계 대기 상태, 뒤 히어로 "인증하고 있어요" |
| 완료 (약 3.9초) | "인증됐어요 🎉", 3단계 모두 ✓, 히어로 "단속 대상 제외", 이번 달 인증 2회→3회 |
| 반경 이탈 | 로그 `이탈`, 인증 종료, 히어로가 "대기 중"으로 복귀 |

### 어느 경로가 도는가

| 경로 | 조건 | 에뮬레이터 검증 |
|---|---|---|
| 포그라운드 워처 (`foreground_geofence.dart`) | 앱이 떠 있고 위치 권한 "사용 중" 이상 | ✅ `geo fix`로 확인 가능 |
| OS 지오펜스 (`geofence_service.dart`) | 위치 "항상 허용" + Supabase 설정 | ❌ 실기기에서 확인해야 함 |

목업 모드에서는 서버가 없어 OS 지오펜스를 등록하지 않는다. 백그라운드 isolate가
서버 없이는 인증을 진행시킬 수 없기 때문이다.

## 빌드 산출물 크기

```bash
flutter build apk --release                  # 126.6 MB — 3개 ABI를 다 담은 fat APK
flutter build apk --release --split-per-abi  # arm64 49.4 / armeabi-v7a 41.5 / x86_64 52.2 MB
flutter build appbundle --release            # 스토어 배포용 (기기별로 필요한 ABI만 내려감)
```

fat APK가 큰 이유는 결함이 아니라 **네이버 지도 네이티브 SDK가 ABI당 18~25MB**이기
때문이다. 실기기에 직접 넣어 볼 때는 `app-arm64-v8a-release.apk`를 쓰고,
스토어에는 AAB를 올린다. 그 외 큰 항목은 Flutter 엔진(ABI당 8~12MB)과
Noto Sans KR 가변 폰트(5.1MB, 서브셋하면 줄일 수 있다).

## 접근성

장애인 대상 앱이므로 다음은 요건이다.

- 모든 탭 가능 요소 최소 44dp, 주 CTA 50–56dp
- 아이콘·이모지 버튼에 `Semantics(label:)` — 스크린리더로 전 화면 완주 가능
- 글자 크기 확대(최대 1.6배)를 존중 — 고정 높이 대신 `minHeight`
- 색만으로 상태를 구분하지 않음 (인증/미인증에 ✓·! 병기)
- 인증 완료 시 스크린리더 안내 + 햅틱
- `MediaQuery.disableAnimations`를 켜면 깜빡임·부유 애니메이션이 멈춘다

## 프로토타입과 의도적으로 다른 점

| 프로토타입 | 구현 | 이유 |
|---|---|---|
| 아바타 이니셜 `SH` | 이름 뒤 두 글자 (`형수`) | 한글 이름에서 로마자 이니셜을 만들 수 없다 |
| 완료 히어로 "2시간 12분 남음" | "단속 대상 제외" | 무료 주차 시간 정책이 데이터에 없다 |
| 로그인 화면 없음 | 로그인 화면 신설 | 소셜 로그인 요구사항 |
| 지도 격자 목업 | 네이버 지도 (키 없으면 격자 목업) | |

## 알려진 문제

- **목업 지도의 핀이 겹친다** — 좌표 투영은 맞지만 잔여면 라벨이 서로 포개진다.
  네이버 지도로 바꾸면 SDK가 마커 충돌을 처리하므로, 목업에서는 그대로 둔다.
- 릴리스 fat APK가 126MB (위 "빌드 산출물 크기" 참고 — split/AAB로 해결)

## 아직 남은 것

- **G.Eye-Parking 연동 스펙 미정** — `certify-parking`의 전달 단계는 인터페이스만 잡아 두었다.
- 주차면 실시간 잔여면의 실제 데이터 출처(공공 API vs 카메라 집계)
- 복지카드 OCR — 현재는 읽어온 정보를 "확인"만 한다
- FCM 푸시 (지금은 로컬 알림만)
- 이모지 아이콘 → Lucide 아이콘 세트 교체
- Noto Sans KR 가변 폰트 서브셋(현재 10MB)
- iOS 빌드는 macOS 필요 (GitHub Actions macOS runner 또는 Codemagic)
