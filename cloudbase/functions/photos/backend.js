const { PhotoError, MAX_BYTES } = require('./sanitize');
const KEY = /^[a-f0-9-]{36}\/[a-f0-9-]{36}\.jpg$/;
const BUCKET = 'squadly-photos';

function createBackend({ origin, serviceKey, fetchImpl = fetch }) {
  const parsed = new URL(origin);
  if (parsed.protocol !== 'https:' || parsed.pathname !== '/' || parsed.search || parsed.hash
    || !/^[a-zA-Z0-9-]+\.api\.(intl\.)?tcloudbasegateway\.com$/.test(parsed.hostname)
    || parsed.port || parsed.username || parsed.password || !serviceKey) throw new Error('Invalid media backend configuration');
  const base = parsed.origin;
  const request = async (path, token, init) => {
    let result;
    try {
      result = await fetchImpl(base + path, {
        ...init, redirect: 'error', signal: AbortSignal.timeout(15000),
        headers: { ...init.headers, authorization: `Bearer ${token}` },
      });
    } catch (_) { throw new PhotoError('backend_unavailable', 503); }
    if (!result.ok) {
      if (result.status === 401 || result.status === 403) throw new PhotoError('unauthorized', 401);
      throw new PhotoError('backend_unavailable', 503);
    }
    return result;
  };
  async function rpc(name, params, token) {
    const result = await request(`/v1/rdb/rest/rpc/${name}`, token, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(params),
    });
    return result.json();
  }
  const objectPath = (key) => {
    if (!KEY.test(key)) throw new PhotoError('invalid_backend_response', 503);
    return `/v1/storages/object/${BUCKET}/${key}`;
  };
  return {
    userRpc: (name, params, token) => rpc(name, params, token),
    serviceRpc: (name, params) => rpc(name, params, serviceKey),
    async upload(key, bytes) {
      if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length > MAX_BYTES) {
        throw new PhotoError('invalid_photo');
      }
      // Sharp may return shared native backing memory. Fetch BodyInit rejects
      // or string-coerces that view depending on the Node runtime. Copy only
      // the visible JPEG range into an ordinary owned buffer before I/O.
      const body = Buffer.from(bytes);
      await request(objectPath(key), serviceKey, {
        method: 'POST', headers: {
          'content-type': 'image/jpeg', 'cache-control': 'max-age=0', 'x-upsert': 'false',
        }, body,
      });
    },
    async download(key) {
      const result = await request(objectPath(key), serviceKey, { method: 'GET' });
      const length = Number(result.headers.get('content-length'));
      if (length > MAX_BYTES) throw new PhotoError('invalid_backend_response', 503);
      // Stream into a bounded buffer even if upstream has no Content-Length.
      const chunks = []; let size = 0;
      for await (const chunk of result.body) {
        size += chunk.length;
        if (size > MAX_BYTES) { await result.body.cancel().catch(() => {}); throw new PhotoError('invalid_backend_response', 503); }
        chunks.push(chunk);
      }
      return Buffer.concat(chunks);
    },
    async remove(key) {
      objectPath(key);
      await request(`/v1/storages/object/${BUCKET}`, serviceKey, {
        method: 'DELETE', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ prefixes: [key] }),
      });
    },
  };
}
module.exports = { createBackend };
