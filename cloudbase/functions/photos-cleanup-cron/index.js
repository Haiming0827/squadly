exports.main = async () => {
  const url = process.env.PHOTO_WORKER_URL;
  const secret = process.env.PHOTO_CLEANUP_SECRET;
  const key = process.env.CLOUDBASE_APIKEY;
  let parsed;
  try { parsed = new URL(url); } catch (_) { throw new Error('Invalid photo worker URL'); }
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password
    || !secret || secret.length < 32 || !key) throw new Error('Photo cleanup configuration is incomplete');
  const result = await fetch(url, {
    method: 'POST', redirect: 'error', headers: {
      authorization: `Bearer ${key}`, 'content-type': 'application/json',
      'x-squadly-media-secret': secret,
    }, body: JSON.stringify({ action: 'cleanup' }), signal: AbortSignal.timeout(55000),
  });
  if (!result.ok) throw new Error(`Photo cleanup returned ${result.status}`);
  return result.json();
};
