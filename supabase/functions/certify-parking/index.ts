// 자동 인증 파이프라인
//
// `certifications` 행이 'detecting' 상태로 생기면 이 함수가 나머지를 진행시킨다:
//   detecting → matching(등록 차량 대조) → sending(G.Eye-Parking 전달) → verified
//
// 호출 방법 (둘 중 하나):
//   A. Supabase Database Webhook — certifications INSERT 시 이 함수를 호출 (권장).
//      누가 인증을 시작했든(앱/지오펜스 백그라운드 isolate) 항상 돌기 때문.
//   B. 앱이 start_certification 직후 직접 invoke.
//
// 배포:
//   supabase functions deploy certify-parking
//   supabase secrets set GEYE_ENDPOINT=... GEYE_API_KEY=...
//
// GEYE_ENDPOINT가 없으면 전달 단계를 건너뛰고 '연동 대기'로 기록한다.
// (연동 스펙이 확정되기 전까지 앱 전체 플로우는 그대로 돌아가야 하므로)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const GEYE_ENDPOINT = Deno.env.get('GEYE_ENDPOINT');
const GEYE_API_KEY = Deno.env.get('GEYE_API_KEY');

/// 프로토타입의 단계 타이밍. 서버가 더 빨리 끝나도 이만큼은 유지해
/// 앱의 단계 애니메이션이 뚝뚝 끊기지 않게 한다.
const T_DETECT_MS = 1100;
const T_MATCH_MS = 2500;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function setStatus(id: string, patch: Record<string, unknown>) {
  await db.from('certifications').update(patch).eq('id', id);
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();

    // Database Webhook은 { type, record } 형태로, 직접 호출은 { certification_id }로 온다.
    const certId: string | undefined =
      payload?.record?.id ?? payload?.certification_id;
    if (!certId) {
      return new Response(JSON.stringify({ error: 'certification_id 없음' }), {
        status: 400,
      });
    }

    const { data: cert } = await db
      .from('certifications')
      .select('*')
      .eq('id', certId)
      .single();

    if (!cert) {
      return new Response(JSON.stringify({ error: '인증 세션 없음' }), {
        status: 404,
      });
    }
    if (cert.status !== 'detecting') {
      // 이미 진행됐거나 끝난 세션 — 중복 호출은 조용히 무시한다.
      return new Response(JSON.stringify({ ok: true, skipped: cert.status }));
    }

    // ---------------------------------------------------------------- 1. 대조
    await sleep(T_DETECT_MS);

    const { data: vehicles } = await db
      .from('vehicles')
      .select('plate')
      .eq('user_id', cert.user_id);

    const plates = (vehicles ?? []).map((v: { plate: string }) => v.plate);
    if (plates.length === 0) {
      await setStatus(certId, {
        status: 'failed',
        fail_reason: '등록된 차량이 없습니다',
        ended_at: new Date().toISOString(),
      });
      return new Response(JSON.stringify({ ok: false, reason: 'no_vehicle' }));
    }

    await setStatus(certId, { status: 'matching', plate: cert.plate ?? plates[0] });

    // ---------------------------------------------------------------- 2. 전달
    await sleep(T_MATCH_MS - T_DETECT_MS);
    await setStatus(certId, { status: 'sending' });

    let feeNote = '무료 · 장애인 감면 적용';

    if (GEYE_ENDPOINT) {
      const res = await fetch(GEYE_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(GEYE_API_KEY ? { Authorization: `Bearer ${GEYE_API_KEY}` } : {}),
        },
        body: JSON.stringify({
          certification_id: cert.id,
          spot_id: cert.spot_id,
          spot_name: cert.spot_name,
          plate: cert.plate ?? plates[0],
          method: cert.method,
          radius_m: cert.radius_m,
          started_at: cert.started_at,
        }),
      });

      if (!res.ok) {
        await setStatus(certId, {
          status: 'failed',
          fail_reason: `단속 시스템 전달 실패 (${res.status})`,
        });
        return new Response(JSON.stringify({ ok: false, reason: 'geye_failed' }), {
          status: 502,
        });
      }

      const body = await res.json().catch(() => ({}));
      if (typeof body?.fee_note === 'string') feeNote = body.fee_note;
    } else {
      feeNote = '무료 · 장애인 감면 적용 (단속 시스템 연동 대기)';
    }

    // ---------------------------------------------------------------- 3. 완료
    const { data: receiptNo } = await db.rpc('next_receipt_no', {
      p_kind: 'certification',
      p_prefix: 'C',
    });

    await setStatus(certId, {
      status: 'verified',
      verified_at: new Date().toISOString(),
      receipt_no: receiptNo,
      fee_note: feeNote,
      // 실제로 2xx 를 받았을 때만 true. 앱은 이 값으로 "전달됨"을 표시한다.
      transmitted: Boolean(GEYE_ENDPOINT),
    });

    return new Response(JSON.stringify({ ok: true, receipt_no: receiptNo }));
  } catch (e) {
    return new Response(JSON.stringify({ error: `${e}` }), { status: 500 });
  }
});
