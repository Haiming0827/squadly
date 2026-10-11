import assert from 'node:assert/strict';
import { test } from 'node:test';
import { webcrypto } from 'node:crypto';

test('worker authenticates and independently dispatches generic APNs and Mi Push', async () => {
  const pair = await webcrypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify'],
  );
  const privateDer = await webcrypto.subtle.exportKey('pkcs8', pair.privateKey);
  const env = {
    PUSH_WORKER_SECRET: 'test-worker-secret-must-be-at-least-32-characters',
    SUPABASE_URL: 'https://project.example.test',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-secret',
    APNS_ENVIRONMENT: 'sandbox',
    APNS_TEAM_ID: 'TESTTEAM',
    APNS_KEY_ID: 'TESTKEY',
    APNS_PRIVATE_KEY: `-----BEGIN PRIVATE KEY-----\n${Buffer.from(privateDer).toString('base64')}\n-----END PRIVATE KEY-----`,
    APNS_BUNDLE_ID: 'com.squadly.squadly',
    MIPUSH_APP_SECRET: 'mipush-secret-test-only',
    MIPUSH_PACKAGE_NAME: 'com.squadly.squadly',
    MIPUSH_CHANNEL_ID: 'approved-test-channel',
  };
  let handler;
  globalThis.Deno = {
    env: { get: (name) => env[name] },
    serve: (callback) => { handler = callback; },
  };
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    if (url.endsWith('/rpc/claim_push_deliveries')) {
      const provider = JSON.parse(init.body).p_provider;
      if (provider === 'mipush') {
        return Response.json([{
          delivery_id: 8,
          claim_id: 'lease-mi',
          provider: 'mipush',
          token: 'mi-reg-id-test-1234',
        }]);
      }
      return Response.json([{
        delivery_id: 7,
        claim_id: 'lease-a',
        provider: 'apns',
        token: 'aabbcc',
      }]);
    }
    if (url.startsWith('https://api.sandbox.push.apple.com/')) {
      return new Response(null, { status: 200 });
    }
    if (url === 'https://api.xmpush.xiaomi.com/v2/message/regid') {
      return Response.json({ result: 'ok', code: 0, data: { id: 'test-message-id' } });
    }
    if (url.endsWith('/rpc/complete_push_delivery')) return Response.json(true);
    throw new Error(`Unexpected URL ${url}`);
  };
  try {
    await import('./index.ts');
    const denied = await handler(new Request('https://function.test', { method: 'POST' }));
    assert.equal(denied.status, 401);
    assert.equal(calls.length, 0);

    const allowed = await handler(new Request('https://function.test', {
      method: 'POST',
      headers: { 'x-squadly-worker-secret': env.PUSH_WORKER_SECRET },
    }));
    assert.equal(allowed.status, 200);
    assert.deepEqual(await allowed.json(), {
      claimed: 2,
      accepted: 2,
      failed: 0,
      apns_configured: true,
      mipush_configured: true,
    });
    assert.equal(calls.length, 6);
    assert.deepEqual(JSON.parse(calls[1].init.body), {
      aps: { alert: { title: '小分队', body: '你的小队有新消息' } },
    });
    assert.deepEqual(JSON.parse(calls[2].init.body), {
      p_delivery_id: 7,
      p_claim_id: 'lease-a',
      p_outcome: 'sent',
      p_error_code: null,
      p_token: null,
    });
    const miPush = calls[4];
    assert.equal(miPush.url, 'https://api.xmpush.xiaomi.com/v2/message/regid');
    assert.equal(miPush.init.headers.Authorization, 'key=mipush-secret-test-only');
    const miPushBody = new URLSearchParams(String(miPush.init.body));
    assert.equal(miPushBody.get('registration_id'), 'mi-reg-id-test-1234');
    assert.equal(miPushBody.get('extra.channel_id'), 'approved-test-channel');
    assert.equal(miPushBody.get('payload'), '{"type":"sync"}');
    assert.equal(miPushBody.has('message_id'), false);
    assert.deepEqual(JSON.parse(calls[5].init.body), {
      p_delivery_id: 8,
      p_claim_id: 'lease-mi',
      p_outcome: 'sent',
      p_error_code: null,
      p_token: null,
    });

    for (const name of [
      'APNS_ENVIRONMENT',
      'APNS_TEAM_ID',
      'APNS_KEY_ID',
      'APNS_PRIVATE_KEY',
      'APNS_BUNDLE_ID',
    ]) delete env[name];
    calls.length = 0;
    const miOnly = await handler(new Request('https://function.test', {
      method: 'POST',
      headers: { 'x-squadly-worker-secret': env.PUSH_WORKER_SECRET },
    }));
    assert.equal(miOnly.status, 200);
    assert.deepEqual(await miOnly.json(), {
      claimed: 1,
      accepted: 1,
      failed: 0,
      apns_configured: false,
      mipush_configured: true,
    });
    assert.equal(calls.length, 3);
    assert.equal(calls.some(({ url }) => url.startsWith('https://api.sandbox.push.apple.com/')), false);
  } finally {
    globalThis.fetch = originalFetch;
    delete globalThis.Deno;
  }
});
