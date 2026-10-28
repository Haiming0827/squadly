const assert = require('node:assert/strict');
const { test } = require('node:test');
const http2 = require('node:http2');
const { once } = require('node:events');
const { generateKeyPairSync, verify } = require('node:crypto');
const { apnsRequest, classifyApnsResponse, createApnsJwt } = require('./apns');
const { sendApns } = require('./apns-transport');

const token = 'aa'.repeat(32);
function request() { return apnsRequest(token, 'test-provider-jwt', 'com.squadly.squadly', 'sandbox', 'photo'); }
async function withServer(handler, run) {
  const server = http2.createServer();
  const sessions = new Set();
  server.on('session', (session) => {
    sessions.add(session); session.on('error', () => {});
    session.on('close', () => sessions.delete(session));
  });
  server.on('stream', (stream, headers) => {
    stream.on('error', () => {}); handler(stream, headers);
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const connect = (origin, options) => {
    assert.equal(origin, 'https://api.sandbox.push.apple.com');
    assert.deepEqual(options.ALPNProtocols, ['h2']);
    return http2.connect(`http://127.0.0.1:${server.address().port}`);
  };
  try { await run(connect); }
  finally { for (const session of sessions) session.destroy(); await new Promise((r) => server.close(r)); }
}

test('transport speaks actual HTTP/2, POSTs the safe body and receives acceptance', async () => {
  let observed;
  await withServer((stream, headers) => {
    const chunks = [];
    stream.on('data', (chunk) => chunks.push(chunk));
    stream.on('end', () => {
      observed = { headers, body: JSON.parse(Buffer.concat(chunks)) };
      stream.respond({ ':status': 200 }); stream.end();
    });
  }, async (connect) => {
    assert.deepEqual(await sendApns(request(), { connect }), { status: 200, reason: null });
    assert.equal(observed.headers[':method'], 'POST');
    assert.equal(observed.headers[':path'], `/3/device/${token}`);
    assert.equal(observed.headers['authorization'], 'bearer test-provider-jwt');
    assert.equal(observed.body.squadly.type, 'photo_sync');
  });
});

test('HTTP/2 platform rejection returns only the safe reason and token classification', async () => {
  await withServer((stream) => {
    stream.respond({ ':status': 410 });
    stream.end(JSON.stringify({ reason: 'Unregistered', hidden: 'never retained' }));
  }, async (connect) => {
    const result = await sendApns(request(), { connect });
    assert.deepEqual(result, { status: 410, reason: 'Unregistered' });
    assert.equal(classifyApnsResponse(result.status, result.reason), 'dead');
  });
});

test('HTTP/2 response size is bounded and errors do not leak device credentials', async () => {
  await withServer((stream) => {
    stream.respond({ ':status': 500 }); stream.end('private-token-content'.repeat(500));
  }, async (connect) => {
    await assert.rejects(sendApns(request(), { connect }), { message: 'APNs transport unavailable' });
  });
});

test('total deadline rejects a stalled HTTP/2 stream and cleans up its session', async () => {
  await withServer(() => {}, async (connect) => {
    await assert.rejects(sendApns(request(), { connect, timeoutMs: 40 }), { message: 'APNs transport unavailable' });
  });
});

test('premature HTTP/2 stream termination is not counted as acceptance', async () => {
  await withServer((stream) => stream.close(http2.constants.NGHTTP2_CANCEL), async (connect) => {
    await assert.rejects(sendApns(request(), { connect }), { message: 'APNs transport unavailable' });
  });
});

test('malformed platform response text is not exposed as a reason code', async () => {
  await withServer((stream) => {
    stream.respond({ ':status': 403 }); stream.end('{"reason":"token=private-value\\n"}');
  }, async (connect) => {
    assert.deepEqual(await sendApns(request(), { connect }), { status: 403, reason: null });
  });
});

test('transport refuses non-Apple hosts, redirects and unsafe request sizes before connecting', async () => {
  for (const url of ['not-a-url', 'http://api.push.apple.com/3/device/aaaaaaaa',
    'https://api.push.apple.com.evil.test/3/device/aaaaaaaa',
    'https://user@api.push.apple.com/3/device/aaaaaaaa',
    'https://api.push.apple.com/3/device/aaaaaaaa?token=private',
    'https://api.push.apple.com/other']) {
    await assert.rejects(sendApns({ ...request(), url }), /Invalid APNs request/);
  }
  const value = request(); value.init.body = 'a'.repeat(4097);
  await assert.rejects(sendApns(value), /Invalid APNs request/);
});

test('APNs provider JWT uses a verifiable ES256 raw signature and explicit issue time', async () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const pem = privateKey.export({ format: 'pem', type: 'pkcs8' });
  const jwt = await createApnsJwt('SYNTHETIC_TEAM', 'SYNTHETIC_KEY', pem, 1800000000);
  const parts = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(parts[0], 'base64url')), { alg: 'ES256', kid: 'SYNTHETIC_KEY' });
  assert.deepEqual(JSON.parse(Buffer.from(parts[1], 'base64url')), { iss: 'SYNTHETIC_TEAM', iat: 1800000000 });
  const signature = Buffer.from(parts[2], 'base64url');
  assert.equal(signature.length, 64);
  assert.equal(verify('sha256', Buffer.from(`${parts[0]}.${parts[1]}`),
    { key: publicKey, dsaEncoding: 'ieee-p1363' }, signature), true);
});
