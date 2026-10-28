const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const { createHandler } = require('./index');
const { createBackend } = require('./backend');
const { sanitizePhoto, digest, MAX_BYTES } = require('./sanitize');
const squad = '10000000-0000-4000-8000-000000000001';
const media = '10000000-0000-4000-8000-000000000002';
const attempt = '10000000-0000-4000-8000-000000000003';
const message = '10000000-0000-4000-8000-000000000004';
const nonce = '10000000-0000-4000-8000-000000000005';
const objectKey = `${media}/${attempt}.jpg`;
const token = 'valid-user-token-for-tests';
const bytes = fs.readFileSync(path.join(__dirname, '../../../test/features/photos/fixtures/sanitized.jpg'));
const send = (action, extra = {}) => ({ action, squad_id: squad, ...extra });
const payload = send('publish', { client_nonce: nonce, source_sha256: digest(bytes), bytes: bytes.toString('base64') });
const event = (body, extra = {}) => ({ httpMethod: 'POST', headers: { authorization: `Bearer ${token}` }, body: JSON.stringify(body), ...extra });
const result = { message_id: message, media_id: media, squad_id: squad, author_id: 'user-a', client_nonce: nonce,
  published_at: '2026-10-27T09:00:00Z', reply_to_message_id: null };
function fixture(overrides = {}) {
  const calls = [];
  const backend = {
    async userRpc(name, params, bearer) {
      calls.push({ name, params, bearer });
      if (name === 'reserve_photo_upload') return { media_id: media, attempt_id: attempt, object_key: objectKey };
      if (name === 'authorize_photo_upload_attempt') return { authorized: true };
      if (name === 'authorize_photo_read') return { media_id: media, object_key: objectKey,
        sha256: digest(bytes), width: 4, height: 3, byte_length: bytes.length };
      return { revoked: true };
    },
    async serviceRpc(name, params) { calls.push({ name, params }); return result; },
    async upload(key, data) { calls.push({ name: 'upload', key, data }); },
    async download(key) { calls.push({ name: 'download', key }); return bytes; },
    async remove(key) { calls.push({ name: 'remove', key }); },
    ...overrides,
  };
  return { backend, calls, handle: createHandler({ backend, cleanupSecret: 's'.repeat(32) }) };
}

test('server decodes a real JPEG, strips GPS/time/device EXIF and orients fresh pixels', async () => {
  const source = await sharp({ create: { width: 30, height: 20, channels: 3, background: '#fc6634' } })
    .withExif({ IFD0: { Make: 'SecretDevice', Orientation: '6' },
      IFD2: { DateTimeOriginal: '2026:10:27 10:11:12' },
      IFD3: { GPSLatitudeRef: 'N', GPSLatitude: '31/1 14/1 0/1', GPSLongitudeRef: 'E', GPSLongitude: '121/1 28/1 0/1' } })
    .withMetadata({ orientation: 6 }).jpeg().toBuffer();
  const before = await sharp(source).metadata();
  assert.ok(before.exif); assert.equal(before.orientation, 6);
  assert.ok(before.exif.includes('SecretDevice')); assert.ok(before.exif.includes('2026:10:27'));
  const clean = await sanitizePhoto(source);
  const after = await sharp(clean.bytes).metadata();
  assert.equal(after.exif, undefined); assert.equal(after.xmp, undefined); assert.equal(after.icc, undefined);
  assert.equal(clean.width, 20); assert.equal(clean.height, 30);
  assert.equal(clean.sha256, digest(clean.bytes)); assert.notDeepEqual(clean.bytes, source);
  assert.equal(after.format, 'jpeg');
});
test('server rejects damaged, non-JPEG, over-dimension and over-byte-limit input', async () => {
  for (const invalid of [Buffer.alloc(0), Buffer.from([255,216,1,2]), Buffer.alloc(MAX_BYTES + 1),
    await sharp(bytes).png().toBuffer(),
    await sharp({ create: { width: 1601, height: 1, channels: 3, background: '#fff' } }).jpeg().toBuffer()]) {
    await assert.rejects(sanitizePhoto(invalid), { code: 'invalid_photo' });
  }
});
test('publish authorizes with user JWT, uploads only sanitized bytes, commits with safe projection', async () => {
  const f = fixture(); const reply = await f.handle(event(payload));
  assert.equal(reply.statusCode, 200); assert.deepEqual(JSON.parse(reply.body), result);
  assert.equal(f.calls[0].bearer, token);
  assert.deepEqual(f.calls.map(c => c.name), ['reserve_photo_upload','upload','authorize_photo_upload_attempt','complete_photo_upload']);
  const clean = f.calls[1].data;
  assert.equal((await sharp(clean).metadata()).exif, undefined);
  assert.equal(f.calls[3].params.p_sha256, digest(clean));
  assert.equal(reply.headers['cache-control'], 'no-store');
  assert.ok(!reply.body.includes('object_key')); assert.ok(!reply.body.includes('source_sha256'));
});
test('lost publish response retry returns committed identity without reupload', async () => {
  const f = fixture({ async userRpc() { return { published: result }; } });
  const reply = await f.handle(event(payload));
  assert.equal(reply.statusCode, 200); assert.deepEqual(JSON.parse(reply.body), result);
  assert.equal(f.calls.length, 0);
});
test('ambiguous commit failure leaves object for leased cleanup instead of deleting it', async () => {
  const f = fixture({ async serviceRpc() { throw new Error('sensitive upstream diagnostics'); } });
  const reply = await f.handle(event(payload));
  assert.equal(reply.statusCode, 503);
  assert.ok(f.calls.some(c => c.name === 'upload')); assert.ok(!f.calls.some(c => c.name === 'remove'));
  assert.ok(!reply.body.includes('sensitive'));
});
test('expired caller JWT after upload cannot certify or publish the object', async () => {
  const f = fixture(); const userRpc = f.backend.userRpc;
  f.backend.userRpc = async (name, ...args) => name === 'authorize_photo_upload_attempt'
    ? { error: 'unauthenticated' } : userRpc(name, ...args);
  const reply = await f.handle(event(payload));
  assert.equal(reply.statusCode, 401);
  assert.ok(f.calls.some(c => c.name === 'upload'));
  assert.ok(!f.calls.some(c => c.name === 'complete_photo_upload'));
});
test('permission denied cannot upload; changed digest and extra recipient fields rejected before RPC', async () => {
  const denied = fixture({ async userRpc() { return { error: 'not_member' }; } });
  assert.equal((await denied.handle(event(payload))).statusCode, 403);
  assert.equal(denied.calls.length, 0);
  const f = fixture();
  for (const invalid of [{ ...payload, source_sha256: 'b'.repeat(64) }, { ...payload, recipients: ['other-user'] },
    { ...payload, bytes: payload.bytes + '\n' }, { ...payload, bytes: 'a'.repeat(4 * Math.ceil(MAX_BYTES / 3) + 4) }]) {
    assert.notEqual((await f.handle(event(invalid))).statusCode, 200);
  }
  assert.equal(f.calls.length, 0);
});
test('load reauthorizes after fetching bytes; revoked/left midway never receives image', async () => {
  const f = fixture();
  let reads = 0; const original = f.backend.userRpc;
  f.backend.userRpc = async (...args) => ++reads === 1 ? original(...args) : { error: 'not_found' };
  const reply = await f.handle(event(send('load', { message_id: message })));
  assert.equal(reply.statusCode, 404); assert.ok(!reply.body.includes('bytes'));
  assert.equal(reads, 2);
});
test('load verifies content digest and returns only prepared fields', async () => {
  const f = fixture(); const reply = await f.handle(event(send('load', { message_id: message })));
  assert.equal(reply.statusCode, 200);
  assert.deepEqual(Object.keys(JSON.parse(reply.body)).sort(), ['bytes','height','sha256','width']);
  assert.deepEqual(f.calls.map(c => c.name), ['authorize_photo_read','download','authorize_photo_read']);
  const tampered = fixture({ async download() { return Buffer.from('wrong image'); } });
  assert.equal((await tampered.handle(event(send('load', { message_id: message })))).statusCode, 404);
});
test('revoke uses caller JWT and never lets caller choose an object path', async () => {
  const f = fixture();
  assert.equal((await f.handle(event(send('revoke', { message_id: message })))).statusCode, 200);
  assert.equal(f.calls[0].name, 'revoke_photo_message'); assert.equal(f.calls[0].bearer, token);
  assert.equal((await f.handle(event(send('revoke', { message_id: message, object_key: objectKey })))).statusCode, 400);
});
test('cleanup requires secret and completes exact lease only after Storage deletion', async () => {
  const f = fixture({ async serviceRpc(name) {
    this.events ??= []; this.events.push(name);
    if (name === 'claim_photo_cleanup') return [{ attempt_id: attempt, object_key: objectKey, claim_id: nonce }];
    return true;
  } });
  assert.equal((await f.handle(event({ action: 'cleanup' }))).statusCode, 401);
  const reply = await f.handle(event({ action: 'cleanup' }, {
    headers: { authorization: `Bearer ${token}`, 'x-squadly-media-secret': 's'.repeat(32) },
  }));
  assert.equal(reply.statusCode, 200); assert.deepEqual(JSON.parse(reply.body), { removed: 1 });
  assert.equal(f.calls[0].name, 'remove');
  assert.deepEqual(f.backend.events, ['claim_photo_cleanup','complete_photo_cleanup']);
});
test('cleanup storage failure never acknowledges the leased deletion', async () => {
  const calls = [];
  const f = fixture({
    async serviceRpc(name) { calls.push(name); return [{ attempt_id: attempt, object_key: objectKey, claim_id: nonce }]; },
    async remove() { throw new Error('transient storage outage'); },
  });
  const reply = await f.handle(event({ action: 'cleanup' }, {
    headers: { authorization: `Bearer ${token}`, 'x-squadly-media-secret': 's'.repeat(32) },
  }));
  assert.equal(reply.statusCode, 503); assert.deepEqual(calls, ['claim_photo_cleanup']);
});
test('method, missing auth, malformed JSON and unsafe metadata cannot reach backend', async () => {
  const f = fixture();
  assert.equal((await f.handle({ ...event(payload), httpMethod: 'GET' })).statusCode, 405);
  assert.equal((await f.handle({ ...event(payload), headers: {} })).statusCode, 401);
  assert.equal((await f.handle({ ...event(payload), body: '{' })).statusCode, 400);
  assert.equal((await f.handle(event({ ...payload, source_path: '/private/library.jpg' }))).statusCode, 400);
  assert.equal(f.calls.length, 0);
});
test('Storage transport uses fixed HTTPS gateway, no redirects/upsert, service key stays server side', async () => {
  const calls = [];
  const backend = createBackend({ origin: 'https://env-id.api.tcloudbasegateway.com', serviceKey: 'server-key',
    async fetchImpl(url, options) { calls.push({ url, options }); return new Response('{}', { status: 200 }); } });
  await backend.upload(objectKey, bytes); await backend.remove(objectKey);
  assert.equal(calls[0].url, `https://env-id.api.tcloudbasegateway.com/v1/storages/object/squadly-photos/${objectKey}`);
  assert.equal(calls[0].options.headers.authorization, 'Bearer server-key');
  assert.equal(calls[0].options.headers['x-upsert'], 'false'); assert.equal(calls[0].options.redirect, 'error');
  assert.deepEqual(JSON.parse(calls[1].options.body), { prefixes: [objectKey] });
  await assert.rejects(backend.upload('../private', bytes));
  for (const origin of ['http://env.api.tcloudbasegateway.com','https://evil.test','https://env.api.tcloudbasegateway.com/path']) {
    assert.throws(() => createBackend({ origin, serviceKey: 'key' }));
  }
});
