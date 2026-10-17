const { apnsRequest, classifyApnsResponse, createApnsJwt } = require('./apns');
const { classifyMiPushResponse, miPushRequest } = require('./mipush');

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function matchesSecret(provided, expected) {
  if (typeof provided !== 'string' || provided.length !== expected.length) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < expected.length; index++) {
    difference |= provided.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

function response(statusCode, payload) {
  return {
    statusCode,
    headers: { 'content-type': 'application/json; charset=utf-8' },
    body: payload == null ? '' : JSON.stringify(payload),
  };
}

async function rpc(name, body) {
  const baseUrl = required('CLOUDBASE_PG_REST_URL').replace(/\/$/, '');
  if (!baseUrl.startsWith('https://') || !baseUrl.endsWith('/v1/rdb/rest')) {
    throw new Error('Invalid CloudBase PG REST URL');
  }
  const apiKey = required('CLOUDBASE_APIKEY');
  const result = await fetch(`${baseUrl}/rpc/${name}`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  if (!result.ok) throw new Error(`RPC ${name} returned ${result.status}`);
  return result.json();
}

async function dispatch(provider, claims, configuration, counters) {
  const completed = await Promise.allSettled(claims.map(async (claim) => {
    let outcome = 'retry';
    let reason = null;
    try {
      const push = provider === 'apns'
        ? apnsRequest(
          claim.token,
          configuration.jwt,
          required('APNS_BUNDLE_ID'),
          configuration.environment,
        )
        : miPushRequest(
          claim.token,
          required('MIPUSH_APP_SECRET'),
          required('MIPUSH_PACKAGE_NAME'),
          required('MIPUSH_CHANNEL_ID'),
        );
      const result = await fetch(push.url, {
        ...push.init,
        signal: AbortSignal.timeout(10000),
      });
      if (provider === 'mipush') {
        const value = await result.json().catch(() => null);
        const parsed = value && typeof value === 'object' ? value : null;
        outcome = classifyMiPushResponse(result.status, parsed);
        const invalidTarget = parsed?.invalid_target ?? parsed?.data?.invalid_target;
        if (outcome === 'dead' && typeof invalidTarget === 'number' && invalidTarget > 0) {
          reason = 'InvalidRegId';
        } else if (typeof parsed?.code === 'number' && parsed.code !== 0) {
          reason = `MiPushCode${parsed.code}`;
        }
      } else {
        if (!result.ok) {
          const value = await result.json().catch(() => null);
          if (typeof value?.reason === 'string') reason = value.reason.slice(0, 100);
        }
        outcome = classifyApnsResponse(result.status, reason);
      }
    } catch (_) {
      reason = 'transport_error';
    }
    await rpc('complete_push_delivery', {
      p_delivery_id: claim.delivery_id,
      p_claim_id: claim.claim_id,
      p_outcome: outcome,
      p_error_code: reason,
      p_token: outcome === 'dead' ? claim.token : null,
    });
    if (outcome === 'sent') counters.accepted++;
    else counters.failed++;
  }));
  const failedCompletion = completed.find((result) => result.status === 'rejected');
  if (failedCompletion) throw failedCompletion.reason;
}

async function handle(event) {
  const method = event?.httpMethod ?? event?.method;
  if (method !== 'POST') return response(405, null);
  const expectedSecret = process.env.PUSH_WORKER_SECRET;
  if (!expectedSecret || expectedSecret.length < 32) {
    return response(503, { error: 'push_worker_unavailable' });
  }
  const headers = event?.headers ?? {};
  const providedSecret = headers['x-squadly-worker-secret']
    ?? headers['X-Squadly-Worker-Secret']
    ?? headers['x-Squadly-Worker-Secret'];
  if (!matchesSecret(providedSecret, expectedSecret)) return response(401, null);

  try {
    const apnsSettings = [
      process.env.APNS_ENVIRONMENT,
      process.env.APNS_TEAM_ID,
      process.env.APNS_KEY_ID,
      process.env.APNS_PRIVATE_KEY,
      process.env.APNS_BUNDLE_ID,
    ];
    const apnsConfigured = apnsSettings.every(Boolean);
    if (apnsSettings.some(Boolean) && !apnsConfigured) {
      throw new Error('APNs configuration is incomplete');
    }
    const miPushSettings = [
      process.env.MIPUSH_APP_SECRET,
      process.env.MIPUSH_PACKAGE_NAME,
      process.env.MIPUSH_CHANNEL_ID,
    ];
    const miPushConfigured = miPushSettings.every(Boolean);
    if (miPushSettings.some(Boolean) && !miPushConfigured) {
      throw new Error('Mi Push configuration is incomplete');
    }
    if (!apnsConfigured && !miPushConfigured) {
      throw new Error('No push provider is configured');
    }

    let configuration = null;
    if (apnsConfigured) {
      const environment = required('APNS_ENVIRONMENT');
      if (environment !== 'sandbox' && environment !== 'production') {
        throw new Error('Invalid APNS_ENVIRONMENT');
      }
      configuration = {
        environment,
        jwt: await createApnsJwt(
          required('APNS_TEAM_ID'),
          required('APNS_KEY_ID'),
          required('APNS_PRIVATE_KEY'),
        ),
      };
    }

    const counters = { accepted: 0, failed: 0 };
    let apnsClaims = [];
    let miPushClaims = [];
    if (apnsConfigured) {
      apnsClaims = await rpc('claim_push_deliveries', {
        p_limit: 20,
        p_provider: 'apns',
      });
      await dispatch('apns', apnsClaims, configuration, counters);
    }
    if (miPushConfigured) {
      miPushClaims = await rpc('claim_push_deliveries', {
        p_limit: 20,
        p_provider: 'mipush',
      });
      await dispatch('mipush', miPushClaims, null, counters);
    }
    return response(200, {
      claimed: apnsClaims.length + miPushClaims.length,
      accepted: counters.accepted,
      failed: counters.failed,
      apns_configured: apnsConfigured,
      mipush_configured: miPushConfigured,
    });
  } catch (_) {
    // Do not log device tokens, key material, message IDs, or request bodies.
    return response(503, { error: 'push_worker_unavailable' });
  }
}

exports.main = handle;
