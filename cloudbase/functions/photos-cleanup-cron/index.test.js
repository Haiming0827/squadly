const { test, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { main } = require('./index');
const original = fetch;
const variables = ['PHOTO_WORKER_URL','PHOTO_CLEANUP_SECRET','CLOUDBASE_APIKEY'];
const before = Object.fromEntries(variables.map(k => [k, process.env[k]]));
afterEach(() => { global.fetch = original; for (const k of variables) {
  if (before[k] === undefined) delete process.env[k]; else process.env[k] = before[k];
} });
function config() {
  process.env.PHOTO_WORKER_URL = 'https://env.app.tcloudbase.com/photos';
  process.env.PHOTO_CLEANUP_SECRET = 's'.repeat(32); process.env.CLOUDBASE_APIKEY = 'server-only-key';
}
test('timer sends exact cleanup action with server credentials, without redirects', async () => {
  config();
  global.fetch = async (url, init) => {
    assert.equal(url, process.env.PHOTO_WORKER_URL); assert.equal(init.redirect, 'error');
    assert.equal(init.headers.authorization, 'Bearer server-only-key');
    assert.equal(init.headers['x-squadly-media-secret'], 's'.repeat(32));
    assert.deepEqual(JSON.parse(init.body), { action: 'cleanup' });
    return new Response('{"removed":2}');
  };
  assert.deepEqual(await main(), { removed: 2 });
});
test('timer rejects incomplete or insecure configuration before fetching', async () => {
  config(); let calls = 0; global.fetch = async () => { calls++; return new Response('{}'); };
  process.env.PHOTO_WORKER_URL = 'http://env.app.tcloudbase.com/photos'; await assert.rejects(main());
  config(); process.env.PHOTO_CLEANUP_SECRET = ''; await assert.rejects(main()); assert.equal(calls, 0);
});
test('failed cleanup remains a failed invocation and preserves retry eligibility', async () => {
  config(); global.fetch = async () => new Response('{}', { status: 503 });
  await assert.rejects(main(), /returned 503/);
});
