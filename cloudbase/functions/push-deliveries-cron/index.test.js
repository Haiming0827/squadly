const assert = require('node:assert/strict');
const { test } = require('node:test');
const { main } = require('./index');

test('scheduled worker calls the HTTPS endpoint with the private worker secret', async () => {
  const originalUrl = process.env.PUSH_WORKER_URL;
  const originalSecret = process.env.PUSH_WORKER_SECRET;
  const originalApiKey = process.env.CLOUDBASE_APIKEY;
  const originalFetch = globalThis.fetch;
  let request;
  process.env.PUSH_WORKER_URL = 'https://push.example.test/deliver';
  process.env.PUSH_WORKER_SECRET = 'scheduler-secret-with-at-least-32-characters';
  process.env.CLOUDBASE_APIKEY = 'server-only-api-key';
  globalThis.fetch = async (url, init) => {
    request = { url, init };
    return Response.json({ claimed: 2 });
  };
  try {
    assert.deepEqual(await main(), { claimed: 2 });
    assert.equal(request.url, process.env.PUSH_WORKER_URL);
    assert.equal(
      request.init.headers['x-squadly-worker-secret'],
      process.env.PUSH_WORKER_SECRET,
    );
    assert.equal(
      request.init.headers.authorization,
      `Bearer ${process.env.CLOUDBASE_APIKEY}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
    if (originalUrl === undefined) delete process.env.PUSH_WORKER_URL;
    else process.env.PUSH_WORKER_URL = originalUrl;
    if (originalSecret === undefined) delete process.env.PUSH_WORKER_SECRET;
    else process.env.PUSH_WORKER_SECRET = originalSecret;
    if (originalApiKey === undefined) delete process.env.CLOUDBASE_APIKEY;
    else process.env.CLOUDBASE_APIKEY = originalApiKey;
  }
});

test('scheduled worker refuses non-HTTPS URLs and short secrets', async () => {
  const originalUrl = process.env.PUSH_WORKER_URL;
  const originalSecret = process.env.PUSH_WORKER_SECRET;
  const originalApiKey = process.env.CLOUDBASE_APIKEY;
  process.env.PUSH_WORKER_URL = 'http://push.example.test/deliver';
  process.env.PUSH_WORKER_SECRET = 'too-short';
  process.env.CLOUDBASE_APIKEY = 'server-only-api-key';
  try {
    await assert.rejects(main(), /Invalid push worker URL/);
    process.env.PUSH_WORKER_URL = 'https://push.example.test/deliver';
    await assert.rejects(main(), /Invalid push worker secret/);
  } finally {
    if (originalUrl === undefined) delete process.env.PUSH_WORKER_URL;
    else process.env.PUSH_WORKER_URL = originalUrl;
    if (originalSecret === undefined) delete process.env.PUSH_WORKER_SECRET;
    else process.env.PUSH_WORKER_SECRET = originalSecret;
    if (originalApiKey === undefined) delete process.env.CLOUDBASE_APIKEY;
    else process.env.CLOUDBASE_APIKEY = originalApiKey;
  }
});
