const http2 = require('node:http2');

// APNs accepts HTTP/2 over TLS, not fetch's ordinary HTTP/1.1 connection.
// The factory is injected in tests to speak actual h2 to a loopback server.
async function sendApns(request, { connect = http2.connect, timeoutMs = 10000 } = {}) {
  let url;
  try { url = new URL(request.url); }
  catch (_) { throw new Error('Invalid APNs request'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.port
    || !['api.push.apple.com', 'api.sandbox.push.apple.com'].includes(url.hostname)
    || !/^\/3\/device\/[a-fA-F0-9]{8,512}$/.test(url.pathname)
    || url.search || url.hash || request.init.method !== 'POST'
    || typeof request.init.body !== 'string'
    || Buffer.byteLength(request.init.body) > 4096
    || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 10000) {
    return Promise.reject(new Error('Invalid APNs request'));
  }
  return new Promise((resolve, reject) => {
    let client;
    let stream;
    let settled = false;
    let status;
    let length = 0;
    const chunks = [];
    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      stream?.close();
      client?.destroy();
      if (error) reject(new Error('APNs transport unavailable'));
      else resolve(result);
    };
    const timer = setTimeout(() => finish(new Error('timeout')), timeoutMs);
    try {
      client = connect(url.origin, { minVersion: 'TLSv1.2', ALPNProtocols: ['h2'] });
      client.on('error', (error) => finish(error));
      client.on('close', () => { if (!settled) finish(new Error('closed')); });
      stream = client.request({
        ...request.init.headers,
        ':method': 'POST', ':path': url.pathname,
      });
      stream.on('response', (headers) => { status = headers[':status']; });
      stream.on('error', (error) => finish(error));
      stream.on('aborted', () => finish(new Error('aborted')));
      stream.on('close', () => { if (!settled) finish(new Error('closed')); });
      stream.on('data', (chunk) => {
        if (settled) return;
        length += chunk.length;
        if (length > 4096) finish(new Error('response too large'));
        else chunks.push(chunk);
      });
      stream.on('end', () => {
        if (!Number.isInteger(status) || status < 200 || status > 599) {
          finish(new Error('invalid response')); return;
        }
        let reason = null;
        if (length) {
          try {
            const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
            if (/^[A-Za-z0-9_]{1,100}$/.test(value?.reason)) reason = value.reason;
          } catch (_) { /* A malformed error body cannot become log content. */ }
        }
        finish(null, { status, reason });
      });
      stream.end(request.init.body);
    } catch (error) { finish(error); }
  });
}

module.exports = { sendApns };
