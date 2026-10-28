const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { once } = require('node:events');
const fs = require('node:fs');
const path = require('node:path');
const { createBackend } = require('./backend');

const image = fs.readFileSync(path.join(__dirname, '../../../test/features/photos/fixtures/sanitized.jpg'));
const objectKey = '10000000-0000-4000-8000-000000000002/10000000-0000-4000-8000-000000000003.jpg';

for (const shared of [false, true]) {
  test(`actual Storage upload sends exactly the JPEG range from ${shared ? 'shared' : 'ordinary'} memory`, async () => {
    let received;
    const server = http.createServer((request, response) => {
      const chunks = [];
      request.on('data', (chunk) => chunks.push(chunk));
      request.on('end', () => {
        received = { bytes: Buffer.concat(chunks), headers: request.headers, url: request.url };
        response.writeHead(200, { 'content-type': 'application/json' }); response.end('{}');
      });
    });
    server.listen(0, '127.0.0.1'); await once(server, 'listening');
    const backend = createBackend({
      origin: 'https://test-env.api.tcloudbasegateway.com', serviceKey: 'synthetic-service-key',
      fetchImpl: (url, init) => fetch(`http://127.0.0.1:${server.address().port}${new URL(url).pathname}`, init),
    });
    // Native image libraries can return a view into shared backing memory on
    // Linux. Include unrelated bytes outside the visible JPEG range.
    const memory = shared ? new SharedArrayBuffer(image.length + 17) : new ArrayBuffer(image.length + 17);
    const view = Buffer.from(memory, 7, image.length); image.copy(view);
    try {
      await backend.upload(objectKey, view);
      assert.equal(received.bytes.equals(image), true, 'Storage upload changed JPEG bytes');
      assert.equal(received.headers['content-type'], 'image/jpeg');
      assert.equal(received.headers.authorization, 'Bearer synthetic-service-key');
      assert.equal(received.url, `/v1/storages/object/squadly-photos/${objectKey}`);
    } finally {
      server.closeAllConnections(); await new Promise((resolve) => server.close(resolve));
    }
  });
}
