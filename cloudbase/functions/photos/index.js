const { timingSafeEqual } = require('node:crypto');
const { sanitizePhoto, digest, PhotoError, MAX_BYTES } = require('./sanitize');
const { createBackend } = require('./backend');
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA = /^[a-f0-9]{64}$/;
const MAX_BODY = 4 * Math.ceil(MAX_BYTES / 3) + 1024;
const headers = {
  'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
};
function response(statusCode, value) {
  return { statusCode, headers, body: JSON.stringify(value) };
}
function check(result) {
  if (!result || typeof result !== 'object') throw new PhotoError('invalid_backend_response', 503);
  if (result.error) {
    const statuses = { unauthenticated: 401, not_member: 403, not_found: 404,
      nonce_conflict: 409, upload_busy: 409, revoked: 410, upload_expired: 409,
      invalid_report: 422, invalid_reply: 422, squad_inactive: 403, invalid_photo: 422, rate_limited: 429 };
    if (!Object.hasOwn(statuses, result.error)) throw new PhotoError('backend_unavailable', 503);
    throw new PhotoError(result.error, statuses[result.error]);
  }
  return result;
}
function parse(event) {
  const raw = event?.body;
  if (typeof raw !== 'string' || raw.length > MAX_BODY * 1.34) throw new PhotoError('invalid_request', 400);
  let text = raw;
  if (event.isBase64Encoded) {
    text = Buffer.from(raw, 'base64').toString('utf8');
  }
  if (Buffer.byteLength(text) > MAX_BODY) throw new PhotoError('invalid_request', 413);
  let body;
  try { body = JSON.parse(text); } catch (_) { throw new PhotoError('invalid_request', 400); }
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new PhotoError('invalid_request', 400);
  return body;
}
function keys(body, allowed) {
  if (Object.keys(body).some((key) => !allowed.includes(key))) throw new PhotoError('invalid_request', 400);
}
function uuid(value) { if (typeof value !== 'string' || !UUID.test(value)) throw new PhotoError('invalid_request', 400); }
function published(result, request) {
  const names = ['message_id','media_id','squad_id','author_id','client_nonce','published_at','reply_to_message_id'];
  keys(result, names);
  uuid(result.message_id); uuid(result.media_id);
  if (result.squad_id !== request.squad_id || result.client_nonce !== request.client_nonce
    || (result.reply_to_message_id ?? null) !== (request.reply_to_message_id ?? null)
    || typeof result.author_id !== 'string' || !result.author_id
    || !Number.isFinite(Date.parse(result.published_at))) throw new PhotoError('invalid_backend_response', 503);
  return result;
}
function createHandler({ backend, sanitize = sanitizePhoto, cleanupSecret }) {
  return async (event) => {
    if ((event?.httpMethod ?? event?.method) !== 'POST') return response(405, { error: 'method_not_allowed' });
    try {
      const h = Object.fromEntries(Object.entries(event.headers ?? {}).map(([k,v]) => [k.toLowerCase(),v]));
      const token = typeof h.authorization === 'string' ? /^Bearer ([^\s]{20,16384})$/.exec(h.authorization)?.[1] : null;
      if (!token) throw new PhotoError('unauthenticated', 401);
      const body = parse(event);
      if (body.action === 'cleanup') {
        keys(body, ['action']);
        const given = h['x-squadly-media-secret'];
        if (!cleanupSecret || cleanupSecret.length < 32 || typeof given !== 'string'
          || Buffer.byteLength(given) !== Buffer.byteLength(cleanupSecret)
          || !timingSafeEqual(Buffer.from(given), Buffer.from(cleanupSecret))) throw new PhotoError('unauthorized', 401);
        const claims = await backend.serviceRpc('claim_photo_cleanup', { p_limit: 20 });
        if (!Array.isArray(claims)) throw new PhotoError('invalid_backend_response', 503);
        let removed = 0;
        for (const claim of claims) {
          uuid(claim.attempt_id); uuid(claim.claim_id);
          await backend.remove(claim.object_key);
          const done = await backend.serviceRpc('complete_photo_cleanup', {
            p_attempt_id: claim.attempt_id, p_claim_id: claim.claim_id,
          });
          if (done === true) removed++;
        }
        return response(200, { removed });
      }
      uuid(body.squad_id);
      if (body.action === 'publish') {
        keys(body, ['action','squad_id','client_nonce','reply_to_message_id','source_sha256','bytes']);
        uuid(body.client_nonce);
        if (body.reply_to_message_id != null) uuid(body.reply_to_message_id);
        if (typeof body.source_sha256 !== 'string' || !SHA.test(body.source_sha256)
          || typeof body.bytes !== 'string' || body.bytes.length > 4 * Math.ceil(MAX_BYTES / 3)) throw new PhotoError('invalid_photo');
        const bytes = Buffer.from(body.bytes, 'base64');
        if (!bytes.length || bytes.length > MAX_BYTES || bytes.toString('base64') !== body.bytes
          || digest(bytes) !== body.source_sha256) throw new PhotoError('invalid_photo');
        const reservation = check(await backend.userRpc('reserve_photo_upload', {
          p_squad_id: body.squad_id, p_client_nonce: body.client_nonce,
          p_source_sha256: body.source_sha256, p_reply_to_message_id: body.reply_to_message_id ?? null,
        }, token));
        if (reservation.published) return response(200, published(reservation.published, body));
        uuid(reservation.media_id); uuid(reservation.attempt_id);
        if (reservation.object_key !== `${reservation.media_id}/${reservation.attempt_id}.jpg`) throw new PhotoError('invalid_backend_response', 503);
        const clean = await sanitize(bytes);
        await backend.upload(reservation.object_key, clean.bytes);
        const authorization = check(await backend.userRpc('authorize_photo_upload_attempt', {
          p_media_id: reservation.media_id, p_attempt_id: reservation.attempt_id,
        }, token));
        if (authorization.authorized !== true) throw new PhotoError('unauthorized', 401);
        // An ambiguous commit failure leaves the object for leased cleanup.
        // Never delete immediately: a committed message might reference it.
        const result = check(await backend.serviceRpc('complete_photo_upload', {
          p_media_id: reservation.media_id, p_attempt_id: reservation.attempt_id,
          p_sha256: clean.sha256, p_width: clean.width, p_height: clean.height, p_byte_length: clean.byteLength,
        }));
        return response(200, published(result, body));
      }
      if (body.action === 'load') {
        keys(body, ['action','squad_id','message_id']); uuid(body.message_id);
        const params = { p_squad_id: body.squad_id, p_message_id: body.message_id };
        const before = check(await backend.userRpc('authorize_photo_read', params, token));
        const bytes = await backend.download(before.object_key);
        const after = check(await backend.userRpc('authorize_photo_read', params, token));
        if (before.media_id !== after.media_id || before.sha256 !== after.sha256
          || bytes.length !== after.byte_length || digest(bytes) !== after.sha256) throw new PhotoError('not_found', 404);
        return response(200, { bytes: bytes.toString('base64'), width: after.width, height: after.height, sha256: after.sha256 });
      }
      if (body.action === 'hide' || body.action === 'report') {
        keys(body, body.action === 'hide' ? ['action','squad_id','message_id'] : ['action','squad_id','message_id','reason']);
        uuid(body.message_id);
        if (body.action === 'report' && !['spam','harassment','privacy','other'].includes(body.reason)) throw new PhotoError('invalid_report', 422);
        const params = { p_squad_id: body.squad_id, p_message_id: body.message_id };
        if (body.action === 'report') params.p_reason = body.reason;
        const result = check(await backend.userRpc(body.action === 'hide' ? 'hide_photo_message' : 'report_photo_message', params, token));
        if (result.hidden !== true || (body.action === 'report' && result.reported !== true)) throw new PhotoError('invalid_backend_response', 503);
        return response(200, body.action === 'hide' ? { hidden: true } : { hidden: true, reported: true });
      }
      if (body.action === 'revoke') {
        keys(body, ['action','squad_id','message_id']); uuid(body.message_id);
        check(await backend.userRpc('revoke_photo_message', {
          p_squad_id: body.squad_id, p_message_id: body.message_id,
        }, token));
        return response(200, { revoked: true });
      }
      throw new PhotoError('invalid_request', 400);
    } catch (error) {
      if (error instanceof PhotoError) return response(error.status, { error: error.code });
      return response(503, { error: 'media_unavailable' });
    }
  };
}
exports.createHandler = createHandler;
exports.main = async (event) => {
  try {
    const backend = createBackend({ origin: process.env.CLOUDBASE_API_ORIGIN, serviceKey: process.env.CLOUDBASE_APIKEY });
    return await createHandler({ backend, cleanupSecret: process.env.PHOTO_CLEANUP_SECRET })(event);
  } catch (_) { return response(503, { error: 'media_unavailable' }); }
};
