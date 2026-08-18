// 네이버 로그인 → Supabase 세션 교환
//
// Supabase Auth는 카카오·구글은 기본 provider로 지원하지만 **네이버는 지원하지 않는다.**
// 그래서 앱이 네이티브 SDK로 받은 네이버 액세스 토큰을 여기로 보내면,
// 이 함수가 네이버에 직접 물어 신원을 확인하고 Supabase 사용자를 만들거나 찾아
// refresh token을 돌려준다. 앱은 그걸로 `auth.setSession()`을 호출한다.
//
// 배포:
//   supabase functions deploy naver-auth --no-verify-jwt
// (로그인 전에 호출되므로 JWT 검증을 끈다)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

interface NaverProfile {
  id: string;
  email?: string;
  name?: string;
  nickname?: string;
  mobile?: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const { access_token } = await req.json();
    if (!access_token) return json({ error: 'access_token이 필요합니다' }, 400);

    // 1. 네이버에 토큰의 주인을 물어본다.
    const naverRes = await fetch('https://openapi.naver.com/v1/nid/me', {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    const naverBody = await naverRes.json();
    if (!naverRes.ok || naverBody.resultcode !== '00') {
      return json({ error: '네이버 토큰 검증 실패', detail: naverBody }, 401);
    }

    const profile = naverBody.response as NaverProfile;

    // 네이버 계정에 이메일이 없을 수도 있어 고유 id 기반 주소를 대신 쓴다.
    const email = profile.email ?? `naver_${profile.id}@users.noreply.gailab.kr`;

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 2. 이미 있는 사용자면 그대로, 없으면 만든다.
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: {
        provider: 'naver',
        naver_id: profile.id,
        name: profile.name ?? profile.nickname,
      },
    });

    if (createError && !`${createError.message}`.includes('already been registered')) {
      return json({ error: '사용자 생성 실패', detail: createError.message }, 500);
    }
    if (created?.user) {
      // handle_new_user() 트리거가 profiles 행을 만들지만, 이름은 여기서 채워 준다.
      await admin
        .from('profiles')
        .update({ name: profile.name ?? profile.nickname })
        .eq('id', created.user.id);
    }

    // 3. 매직링크를 발급해 곧바로 소비하는 방식으로 세션을 만든다.
    //    (Supabase Admin API에는 "세션 직접 발급"이 없다)
    const { data: link, error: linkError } = await admin.auth.admin.generateLink({
      type: 'magiclink',
      email,
    });
    if (linkError || !link?.properties?.hashed_token) {
      return json({ error: '세션 발급 실패', detail: linkError?.message }, 500);
    }

    const anon = createClient(SUPABASE_URL, ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: session, error: otpError } = await anon.auth.verifyOtp({
      token_hash: link.properties.hashed_token,
      type: 'email',
    });
    if (otpError || !session.session) {
      return json({ error: '세션 확인 실패', detail: otpError?.message }, 500);
    }

    return json({
      refresh_token: session.session.refresh_token,
      access_token: session.session.access_token,
      user_id: session.session.user.id,
    });
  } catch (e) {
    return json({ error: `${e}` }, 500);
  }
});
