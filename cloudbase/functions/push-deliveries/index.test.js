const assert = require('node:assert/strict');
const { test } = require('node:test');
const { webcrypto } = require('node:crypto');
const { main } = require('./index');

test('worker authenticates, claims both channels, and completes safe generic pushes', async () => {
  const keyPair = await webcrypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  );
  const privateDer = await webcrypto.subtle.exportKey('pkcs8', keyPair.privateKey);
  const env = {
    PUSH_WORKER_SECRET: 'test-worker-secret-must-be-at-least-32-characters',
    CLOUDBASE_PG_REST_URL: 'https://env.example/v1/rdb/rest',
    CLOUDBASE_APIKEY: 'server-only-cloudbase-api-key',
    APNS_ENVIRONMENT: 'sandbox',
    APNS_TEAM_ID: 'TESTTEAM',
    APNS_KEY_ID: 'TESTKEY',
    APNS_PRIVATE_KEY: `-----BEGIN PRIVATE KEY-----\n${Buffer.from(privateDer).toString('base64')}\n-----END PRIVATE KEY-----`,
    APNS_BUNDLE_ID: 'com.squadly.squadly',
    MIPUSH_APP_SECRET: 'mipush-secret-test-only',
    MIPUSH_PACKAGE_NAME: 'com.squadly.squadly',
    MIPUSH_CHANNEL_ID: 'approved-test-channel',
  };
  const originalEnv = { ...process.env };
  Object.assign(process.env, env);
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init });
    if (String(url).endsWith('/rpc/claim_push_deliveries')) {
      const provider = JSON.parse(init.body).p_provider;
      return Response.json(provider === 'mipush'
        ? [{ delivery_id: 8, claim_id: 'lease-mi', provider, token: 'mi-reg-id-test' }]
        : [{ delivery_id: 7, claim_id: 'lease-apns', provider, token: 'aabbcc' }]);
    }
    if (String(url).startsWith('https://api.sandbox.push.apple.com/')) {
      return new Response(null, { status: 200 });
    }
    if (String(url) === 'https://api.xmpush.xiaomi.com/v2/message/regid') {
      return Response.json({ code: 0, data: { id: 'test-message-id' } });
    }
    if (String(url).endsWith('/rpc/complete_push_delivery')) {
      return Response.json(true);
    }
    throw new Error(`Unexpected URL ${url}`);
  };

  try {
    const denied = await main({ httpMethod: 'POST', headers: {} });
    assert.equal(denied.statusCode, 401);
    assert.equal(calls.length, 0);

    const allowed = await main({
      httpMethod: 'POST',
      headers: { 'x-squadly-worker-secret': env.PUSH_WORKER_SECRET },
    });
    assert.equal(allowed.statusCode, 200);
    assert.deepEqual(JSON.parse(allowed.body), {
      claimed: 2,
      accepted: 2,
      failed: 0,
      apns_configured: true,
      mipush_configured: true,
    });
    assert.equal(calls.length, 6);
    assert.equal(
      calls[0].init.headers.authorization,
      `Bearer ${env.CLOUDBASE_APIKEY}`,
    );
    assert.deepEqual(JSON.parse(calls[1].init.body), {
      aps: { alert: { title: '小分队', body: '你的小队有新消息' } },
    });
    assert.deepEqual(JSON.parse(calls[2].init.body), {
      p_delivery_id: 7,
      p_claim_id: 'lease-apns',
      p_outcome: 'sent',
      p_error_code: null,
      p_token: null,
    });
    const miRequest = calls[4];
    assert.equal(
      miRequest.init.headers.authorization,
      `key=${env.MIPUSH_APP_SECRET}`,
    );
    const miBody = new URLSearchParams(String(miRequest.init.body));
    assert.equal(miBody.get('registration_id'), 'mi-reg-id-test');
    assert.equal(miBody.get('extra.channel_id'), env.MIPUSH_CHANNEL_ID);
    assert.equal(miBody.get('payload'), '{"type":"sync"}');
    assert.deepEqual(JSON.parse(calls[5].init.body), {
      p_delivery_id: 8,
      p_claim_id: 'lease-mi',
      p_outcome: 'sent',
      p_error_code: null,
      p_token: null,
    });
  } finally {
    globalThis.fetch = originalFetch;
    for (const name of Object.keys(process.env)) {
      if (!(name in originalEnv)) delete process.env[name];
    }
    Object.assign(process.env, originalEnv);
  }
});

test('worker rejects non-POST requests and does not expose configuration errors', async () => {
  const methodResult = await main({ httpMethod: 'GET', headers: {} });
  assert.equal(methodResult.statusCode, 405);

  const originalSecret = process.env.PUSH_WORKER_SECRET;
  delete process.env.PUSH_WORKER_SECRET;
  try {
    const unavailable = await main({ httpMethod: 'POST', headers: {} });
    assert.equal(unavailable.statusCode, 503);
    assert.equal(unavailable.body, '{"error":"push_worker_unavailable"}');
  } finally {
    if (originalSecret === undefined) delete process.env.PUSH_WORKER_SECRET;
    else process.env.PUSH_WORKER_SECRET = originalSecret;
  }
});
