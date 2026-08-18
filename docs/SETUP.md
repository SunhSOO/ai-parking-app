# 남은 설정 체크리스트

앱과 DB는 이미 연결돼 동작한다. 여기 있는 세 가지만 마치면 실제 서비스 형태가 된다.
**위에서부터 순서대로** 하면 되고, 각 단계마다 "확인하는 법"이 있다.

프로젝트 공통 값:

| 항목 | 값 |
|---|---|
| Android 패키지명 | `kr.gailab.ai_parking` |
| iOS 번들 ID | `kr.gailab.aiParking` |
| 디버그 SHA-1 (구글용) | `32:25:36:88:A4:5B:95:AC:8E:61:00:49:0A:09:D9:EE:4C:F4:F0:D7` |
| 디버그 키 해시 (카카오용) | `MiU2iKRblayOYQBJCgnZ7kz08Nc=` |
| Supabase 콜백 URL | `https://<project-ref>.supabase.co/auth/v1/callback` |

> 위 SHA-1·키 해시는 **디버그용**이다. 스토어에 올릴 때는 릴리스 키스토어로 다시 뽑아
> 각 콘솔에 **추가**로 등록해야 한다 (기존 것을 지우지 말 것).

---

## 1️⃣ RLS 구멍 막기 — 5분

`daily_counters` 테이블에 RLS가 없어서 **익명 키만 있으면 누구나 읽고 쓸 수 있다.**
접수번호를 조작하거나 고갈시킬 수 있다.

### 하는 법

Supabase 대시보드 → 왼쪽 **SQL Editor** → **New query** → 아래를 붙여넣고 **Run**:

```sql
alter table public.daily_counters enable row level security;
revoke all on public.spatial_ref_sys from anon, authenticated;
```

정책(policy)을 하나도 안 만드는 게 의도다. RLS만 켜면 앱에서는 완전히 막히고,
접수번호를 발급하는 `next_receipt_no()` 함수는 `SECURITY DEFINER`라 소유자 권한으로
돌기 때문에 **신고 접수는 그대로 동작한다.**

### 확인하는 법

- 대시보드 → **Advisors** → Security → "Row Level Security is disabled" 경고가 사라진다
- 신고 화면에서 신고를 한 건 접수해 보고 접수번호(`R-2026-...`)가 나오면 정상

> 같은 내용이 `supabase/migrations/20260818000600_rls_daily_counters.sql` 에도 있다.
> 대시보드에서 이미 실행했더라도 이 마이그레이션은 다시 실행해도 안전하다(멱등).

---

## 2️⃣ Edge Function 배포 — 10분

지금 자동 인증이 **`detecting`(주차면 감지)에서 멈춘다.** 다음 단계(차량 대조 → 단속
시스템 전달 → 완료)를 진행시키는 `certify-parking` 함수가 배포되지 않아서다.

### 2-1. CLI 로그인

터미널(PowerShell)에서:

```powershell
cd C:\Users\sunhy\Desktop\ai-parking-app
npx supabase login
```

브라우저가 열리면 승인한다. 토큰은 **이 PC에만** 저장된다.

확인: `npx supabase projects list` 에 프로젝트가 보이면 성공.

### 2-2. 함수 배포

```powershell
npx supabase functions deploy certify-parking --project-ref <project-ref>
npx supabase functions deploy naver-auth --project-ref <project-ref> --no-verify-jwt
```

`naver-auth`만 `--no-verify-jwt`인 이유: **로그인 전에** 호출되는 함수라 JWT가 아직 없다.

### 2-3. 인증이 생기면 함수가 돌게 연결

대시보드 → **Database** → **Webhooks** → **Create a new hook**

| 항목 | 값 |
|---|---|
| Name | `certify-parking-on-insert` |
| Table | `certifications` |
| Events | **Insert** 만 체크 |
| Type | Supabase Edge Functions |
| Edge Function | `certify-parking` |
| HTTP Headers | `Authorization` : `Bearer <service_role key>` |

service_role 키는 Settings → API Keys 에 있다. **이 키는 서버(웹훅 설정)에만 넣는다.
앱이나 깃허브에는 절대 넣지 않는다.**

웹훅으로 거는 이유: 앱이 시작하든, 화면이 꺼진 상태에서 지오펜스 백그라운드가
시작하든, **누가 인증을 만들었든 항상** 함수가 돌아야 하기 때문이다.

### 확인하는 법

에뮬레이터에서 성남시청 주차장 반경으로 위치를 옮기면(또는 홈의 "지금 인증 실행")
인증 시트가 3단계를 모두 통과해 **"인증됐어요 🎉"** 까지 가야 한다.

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb emu geo fix 127.1265 37.4200
```

안 되면 대시보드 → Edge Functions → certify-parking → **Logs** 를 본다.

### (선택) 단속 시스템 연동

G.Eye-Parking 엔드포인트가 정해지면:

```powershell
npx supabase secrets set GEYE_ENDPOINT=https://... GEYE_API_KEY=... --project-ref <project-ref>
```

설정하지 않으면 전달 단계를 건너뛰고 "연동 대기"로 기록한다. 앱 동작에는 지장 없다.

---

## 3️⃣ 키 발급 — 앱에 실제 지도와 로그인 붙이기

**쉬운 것부터** 정리했다. 하나씩 해도 되고, 하는 만큼 그 기능만 켜진다.
(키가 없는 기능은 자동으로 목업/비활성으로 남는다)

받은 값은 전부 `app/config.json` 에 넣는다. 이 파일은 git에 올라가지 않는다.

### 3-A. 네이버 지도 (가장 쉬움, 로그인과 무관)

1. [console.ncloud.com](https://console.ncloud.com) 가입 → 결제수단 등록
   (무료 한도가 넉넉하지만 카드 등록은 필요하다)
2. **Services → Application Services → Maps → Application 등록**
3. API 선택에서 **Dynamic Map** 체크
4. 서비스 환경 등록:
   - Android 앱 패키지 이름: `kr.gailab.ai_parking`
   - iOS Bundle ID: `kr.gailab.aiParking`
5. 발급된 **Client ID** 를 복사

```json
"NAVER_MAP_CLIENT_ID": "여기에 붙여넣기"
```

**확인**: 주차면 탭의 지도가 격자 목업에서 실제 네이버 지도로 바뀐다.

### 3-B. 구글 로그인

1. [console.cloud.google.com](https://console.cloud.google.com) → 프로젝트 생성
2. **API 및 서비스 → OAuth 동의 화면** 설정 (외부, 앱 이름·이메일만)
3. **사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID** 를 **3개** 만든다:

| 유형 | 입력값 | 쓰는 곳 |
|---|---|---|
| **웹 애플리케이션** | 승인된 리디렉션 URI에 `https://<project-ref>.supabase.co/auth/v1/callback` | Supabase + `GOOGLE_SERVER_CLIENT_ID` |
| **Android** | 패키지명 `kr.gailab.ai_parking`, SHA-1은 위 표의 값 | (config.json에 안 넣음) |
| **iOS** | 번들 ID `kr.gailab.aiParking` | `GOOGLE_IOS_CLIENT_ID` |

4. Supabase 대시보드 → **Authentication → Sign In / Providers → Google** 켜고,
   **웹** 클라이언트의 ID와 시크릿을 입력

```json
"GOOGLE_SERVER_CLIENT_ID": "...apps.googleusercontent.com",   // 웹 클라이언트 ID
"GOOGLE_IOS_CLIENT_ID": "...apps.googleusercontent.com"       // iOS 클라이언트 ID
```

**확인**: 로그인 화면에서 "구글로 시작하기" → 계정 선택 → 온보딩으로 넘어간다.

### 3-C. 카카오 로그인

1. [developers.kakao.com](https://developers.kakao.com) → **내 애플리케이션 → 애플리케이션 추가**
2. **앱 설정 → 플랫폼**
   - Android: 패키지명 `kr.gailab.ai_parking`, 키 해시 `MiU2iKRblayOYQBJCgnZ7kz08Nc=`
   - iOS: 번들 ID `kr.gailab.aiParking`
3. **제품 설정 → 카카오 로그인** → 활성화 ON
   - Redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback`
4. **제품 설정 → 카카오 로그인 → 보안** → Client Secret 생성
5. **제품 설정 → 카카오 로그인 → OpenID Connect** → **활성화 ON**
   (이게 꺼져 있으면 ID 토큰이 안 와서 네이티브 로그인이 웹 방식으로 우회한다)
6. Supabase → Authentication → Providers → **Kakao** 켜고
   **REST API 키**와 **Client Secret** 입력

```json
"KAKAO_NATIVE_APP_KEY": "네이티브 앱 키",
"KAKAO_JS_KEY": "JavaScript 키"
```

**확인**: "카카오로 시작하기" → 카카오톡 앱 또는 웹으로 인증 → 온보딩.

### 3-D. 네이버 로그인 (가장 손이 많이 감)

Supabase가 네이버를 기본 지원하지 않아, 앞서 만든 `naver-auth` Edge Function이
토큰을 검증하고 세션을 발급한다. **2️⃣ 단계에서 이 함수를 먼저 배포해야 한다.**

1. [developers.naver.com](https://developers.naver.com) → **애플리케이션 → 애플리케이션 등록**
2. 사용 API: **네이버 로그인** 선택, 제공 정보는 이름·이메일 정도만
3. 환경 추가:
   - Android: 패키지명 `kr.gailab.ai_parking`, 다운로드 URL 아무 값
   - iOS: 번들 ID `kr.gailab.aiParking`
4. **Client ID / Client Secret** 복사

여기까지 하시고 **저에게 알려주세요.** 네이버 로그인 SDK는 `config.json`만으로 안 되고
Android `AndroidManifest.xml`과 iOS `Info.plist`에 네이티브 설정을 넣어야 하는데,
그건 제가 코드로 붙이겠습니다.

**확인**: "네이버로 시작하기" → 네이버 앱/웹 인증 → 온보딩.

---

## 다 끝나면

- 로그인 화면의 "🛠 개발용 테스트 계정으로 로그인" 버튼은 소셜 로그인이 붙으면 필요 없다.
  `app/config.json`의 `DEV_LOGIN_EMAIL`/`DEV_LOGIN_PASSWORD`를 비우면 버튼이 사라진다.
  DB에 직접 만든 `dev@gailab.kr` 계정도 지우는 것이 좋다.
- Supabase → Authentication → **"Confirm email"** 을 다시 켜는 것을 권한다
  (지금 개발 편의로 꺼 두라고 안내했다면).
- 저장소를 공개로 바꾸려면 `gh repo edit --visibility public`. 단, 1️⃣을 먼저 끝낼 것.
