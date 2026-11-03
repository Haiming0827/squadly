const assert = require('node:assert/strict');
const { test } = require('node:test');
const { generateKeyPairSync } = require('node:crypto');
const http2 = require('node:http2');
const { once } = require('node:events');
const { createHandler, main } = require('./index');
const { sendApns } = require('./apns-transport');

const privateKey = generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
  .privateKey.export({ format: 'pem', type: 'pkcs8' });
const token = 'ab'.repeat(32);
const secret = 'test-worker-secret-must-be-at-least-32-characters';

async function fixture(options, run) {
  const originalEnv = { ...process.env };
  const originalFetch = globalThis.fetch;
  for (const name of Object.keys(process.env)) {
    if (/^(APNS_|MIPUSH_|PUSH_WORKER_|CLOUDBASE_)/.test(name)) delete process.env[name];
  }
  Object.assign(process.env, {
    PUSH_WORKER_SECRET: secret,
    CLOUDBASE_PG_REST_URL: 'https://test-env.api.tcloudbasegateway.com/v1/rdb/rest',
    CLOUDBASE_APIKEY: 'server-only-test-key',
    ...(options.apns === false ? {} : {
      APNS_ENVIRONMENT: 'sandbox', APNS_TEAM_ID: 'TESTTEAM', APNS_KEY_ID: 'TESTKEY',
      APNS_PRIVATE_KEY: privateKey, APNS_BUNDLE_ID: 'com.squadly.squadly',
    }),
    ...(options.mi === false ? {} : {
      MIPUSH_APP_SECRET: 'test-mi-secret', MIPUSH_PACKAGE_NAME: 'com.squadly.squadly',
      MIPUSH_CHANNEL_ID: 'test-reviewed-channel',
    }),
    ...options.env,
  });
  const calls = [];
  const pushes = [];
  const completions = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init });
    if (String(url).endsWith('/rpc/claim_push_work')) {
      const provider = JSON.parse(init.body).p_provider;
      if (options.failedClaim === provider) return new Response(null, { status: 503 });
      const claim = { lease_kind: options.leaseKind ?? 'message',
        delivery_id: provider === 'apns' ? '7' : '8',
        claim_id: `lease-${provider}`, provider, message_kind: options.kind ?? 'photo',
        token: provider === 'apns' ? token : 'test-mi-reg-id' };
      return Response.json(options.claims ?? [claim]);
    }
    if (String(url).endsWith('/rpc/complete_push_work')) {
      const body = JSON.parse(init.body); completions.push(body);
      return Response.json(String(options.failedCompletion) !== body.p_delivery_id);
    }
    if (String(url) === 'https://api.xmpush.xiaomi.com/v2/message/regid') {
      return Response.json(options.miResponse ?? { code: 0 });
    }
    throw new Error('Unexpected request');
  };
  const handler = createHandler({ apnsTransport: async (request) => {
    pushes.push(request);
    if (options.transportFailure) throw new Error('private-device-token-must-not-escape');
    return options.transport ? options.transport(request)
      : options.apnsResponse ?? { status: 200, reason: null };
  } });
  try {
    await run({ handler, calls, pushes, completions,
      send: () => handler({ httpMethod: 'POST', headers: { 'x-squadly-worker-secret': secret } }) });
  } finally {
    globalThis.fetch = originalFetch;
    for (const name of Object.keys(process.env)) if (!(name in originalEnv)) delete process.env[name];
    Object.assign(process.env, originalEnv);
  }
}

test('worker rejects methods, absent secret and unauthenticated requests without claims', async () => {
  await fixture({}, async ({ handler, calls }) => {
    assert.equal((await main({ httpMethod: 'GET' })).statusCode, 405);
    assert.equal((await handler({ httpMethod: 'POST', headers: {} })).statusCode, 401);
    delete process.env.PUSH_WORKER_SECRET;
    assert.equal((await handler({ httpMethod: 'POST' })).body, '{"error":"push_worker_unavailable"}');
    assert.equal(calls.length, 0);
  });
});

test('photo pushes request background opportunity without content or identity', async () => {
  await fixture({}, async ({ send, pushes, calls, completions }) => {
    const response = await send();
    assert.equal(response.statusCode, 200);
    assert.deepEqual(JSON.parse(response.body), {
      claimed: 2, accepted: 2, failed: 0, apns_configured: true, mipush_configured: true,
    });
    assert.deepEqual(JSON.parse(pushes[0].init.body), {
      aps: { alert: { title: '小分队', body: '你的小队有新消息' }, 'content-available': 1 },
      squadly: { v: 1, type: 'photo_sync' },
    });
    assert.equal(pushes[0].init.headers['apns-push-type'], 'alert');
    assert.equal(pushes[0].init.headers['apns-priority'], '10');
    assert.ok(!calls.some((call) => call.url.includes('push.apple.com')));
    const mi = calls.find((call) => call.url.includes('xmpush.xiaomi.com'));
    assert.equal(new URLSearchParams(mi.init.body).get('payload'), '{"type":"sync"}');
    assert.deepEqual(completions.map((c) => c.p_outcome).sort(), ['sent', 'sent']);
    assert.ok(calls.filter((call) => call.url.includes('/rpc/'))
      .every((call) => call.init.redirect === 'error'
        && call.init.headers.authorization === 'Bearer server-only-test-key'));
  });
});

for (const kind of ['text', 'card']) test(`${kind} pushes do not fetch photos in the background`, async () => {
  await fixture({ kind, mi: false }, async ({ send, pushes }) => {
    assert.equal((await send()).statusCode, 200);
    assert.deepEqual(JSON.parse(pushes[0].init.body), {
      aps: { alert: { title: '小分队', body: '你的小队有新消息' } },
    });
  });
});

test('APNs transport failure retries only its device while Mi Push completes', async () => {
  await fixture({ transportFailure: true }, async ({ send, completions }) => {
    const response = await send();
    assert.deepEqual(JSON.parse(response.body), {
      claimed: 2, accepted: 1, failed: 1, apns_configured: true, mipush_configured: true,
    });
    assert.equal(completions.find((c) => c.p_delivery_id === '7').p_error_code, 'transport_error');
    assert.equal(completions.find((c) => c.p_delivery_id === '8').p_outcome, 'sent');
    assert.ok(!response.body.includes('private-device-token'));
  });
});

test('invalid APNs token uses a token-bound dead receipt; platform rejection remains retryable', async () => {
  for (const [reason, outcome] of [['Unregistered', 'dead'], ['ExpiredProviderToken', 'retry']]) {
    await fixture({ mi: false, apnsResponse: { status: 410, reason } }, async ({ send, completions }) => {
      assert.equal((await send()).statusCode, 200);
      assert.equal(completions[0].p_outcome, outcome);
      assert.equal(completions[0].p_token, outcome === 'dead' ? token : null);
    });
  }
});

for (const failedClaim of ['apns', 'mipush']) test(`${failedClaim} claim failure does not skip the other channel`, async () => {
  await fixture({ failedClaim }, async ({ send, completions }) => {
    assert.equal((await send()).statusCode, 503);
    assert.equal(completions.length, 1);
    assert.equal(completions[0].p_delivery_id, failedClaim === 'apns' ? '8' : '7');
  });
});

test('APNs completion rejection cannot be counted as a completed dispatch', async () => {
  await fixture({ failedCompletion: 7 }, async ({ send, completions }) => {
    const response = await send();
    assert.equal(response.statusCode, 503);
    assert.equal(response.body, '{"error":"push_worker_unavailable"}');
    assert.equal(completions.find((c) => c.p_delivery_id === '8').p_outcome, 'sent');
  });
});

for (const env of [{ APNS_KEY_ID: '' }, { APNS_PRIVATE_KEY: 'invalid private material' }]) {
  test('broken APNs credentials do not prevent the configured Mi Push channel', async () => {
    await fixture({ env }, async ({ send, completions, pushes }) => {
      assert.equal((await send()).statusCode, 503);
      assert.equal(pushes.length, 0);
      assert.equal(completions.find((c) => c.p_delivery_id === '8').p_outcome, 'sent');
    });
  });
}

test('invalid kind fails closed without a generic photo fallback', async () => {
  await fixture({ kind: 'private_health', mi: false }, async ({ send, pushes, completions }) => {
    assert.equal((await send()).statusCode, 200);
    assert.equal(pushes.length, 0);
    assert.equal(completions[0].p_outcome, 'retry');
  });
});

test('no configured provider leaves the queue unclaimed', async () => {
  await fixture({ apns: false, mi: false }, async ({ send, calls }) => {
    assert.equal((await send()).statusCode, 503);
    assert.equal(calls.length, 0);
  });
});

for (const kind of ['photo', 'photo_sync']) test(`worker completes ${kind} receipt after actual HTTP/2 acceptance`, async () => {
  const server = http2.createServer();
  const sessions = new Set();
  server.on('session', (session) => { sessions.add(session); session.on('error', () => {}); });
  let received = false;
  server.on('stream', (stream, headers) => {
    const bytes = [];
    stream.on('error', () => {}); stream.on('data', (chunk) => bytes.push(chunk));
    stream.on('end', () => {
      assert.equal(headers[':method'], 'POST');
      const payload = JSON.parse(Buffer.concat(bytes));
      assert.equal(payload.squadly.type, 'photo_sync');
      assert.equal(headers['apns-push-type'], kind === 'photo_sync' ? 'background' : 'alert');
      assert.equal(headers['apns-priority'], kind === 'photo_sync' ? '5' : '10');
      if (kind === 'photo_sync') assert.deepEqual(payload.aps, { 'content-available': 1 });
      received = true; stream.respond({ ':status': 200 }); stream.end();
    });
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  try {
    await fixture({ mi: false, kind, leaseKind: kind === 'photo_sync' ? 'photo_sync' : 'message',
      transport: (request) => sendApns(request, {
      connect: () => http2.connect(`http://127.0.0.1:${server.address().port}`),
    }) }, async ({ send, completions }) => {
      const response = await send();
      assert.equal(received, true);
      assert.equal(response.statusCode, 200);
      assert.equal(completions[0].p_outcome, 'sent');
    });
  } finally {
    for (const session of sessions) session.destroy();
    await new Promise((resolve) => server.close(resolve));
  }
});

test('revocation sends a quiet background hint and completes its separate lease', async () => {
  await fixture({ mi: false, leaseKind: 'photo_sync', kind: 'photo_sync' }, async ({ send, pushes, completions, calls }) => {
    assert.equal((await send()).statusCode, 200);
    assert.deepEqual(JSON.parse(pushes[0].init.body), {
      aps: { 'content-available': 1 }, squadly: { v: 1, type: 'photo_sync' },
    });
    assert.equal(pushes[0].init.headers['apns-push-type'], 'background');
    assert.equal(pushes[0].init.headers['apns-priority'], '5');
    assert.equal(pushes[0].init.headers['apns-expiration'], '0');
    assert.equal(completions[0].p_lease_kind, 'photo_sync');
    assert.equal(completions[0].p_delivery_id, '7');
    assert.ok(calls.some((call) => call.url.endsWith('/rpc/complete_push_work')));
  });
});

for (const options of [
  { leaseKind: 'message', kind: 'photo_sync', mi: false },
  { leaseKind: 'photo_sync', kind: 'photo', mi: false },
  { leaseKind: 'untrusted', kind: 'photo', mi: false },
  { leaseKind: 'photo_sync', kind: 'photo_sync', apns: false },
]) test(`invalid work combination ${JSON.stringify(options)} cannot send`, async () => {
  await fixture(options, async ({ send, pushes, calls, completions }) => {
    assert.equal((await send()).statusCode, 200);
    assert.equal(pushes.length, 0);
    assert.equal(calls.filter((call) => call.url.includes('xmpush.xiaomi.com')).length, 0);
    assert.equal(completions[0].p_outcome, 'retry');
  });
});
