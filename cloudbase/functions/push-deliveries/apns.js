const { webcrypto } = require('node:crypto');
const encoder = new TextEncoder();

function base64url(bytes) {
  return Buffer.from(bytes).toString('base64url');
}

async function createApnsJwt(teamId, keyId, privateKeyPem, issuedAtSeconds = Math.floor(Date.now() / 1000)) {
  const pem = privateKeyPem.replace(/\\n/g, '\n');
  const der = Buffer.from(
    pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, ''),
    'base64',
  );
  const key = await webcrypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'ES256', kid: keyId })));
  const claims = base64url(encoder.encode(JSON.stringify({ iss: teamId, iat: issuedAtSeconds })));
  const input = `${header}.${claims}`;
  const signature = await webcrypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    encoder.encode(input),
  );
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

function apnsRequest(token, jwt, bundleId, environment, messageKind = 'text') {
  if (typeof token !== 'string' || !/^[0-9a-fA-F]{8,512}$/.test(token)) throw new Error('Invalid APNs token');
  if (environment !== 'sandbox' && environment !== 'production') throw new Error('Invalid APNs environment');
  if (!['text', 'card', 'photo', 'photo_sync'].includes(messageKind)) throw new Error('Invalid message kind');
  if (!/^[A-Za-z0-9.-]{3,200}$/.test(bundleId) || typeof jwt !== 'string' || !jwt) throw new Error('Invalid APNs configuration');
  const host = environment === 'sandbox'
    ? 'api.sandbox.push.apple.com'
    : 'api.push.apple.com';
  return {
    url: `https://${host}/3/device/${token}`,
    init: {
      method: 'POST',
      headers: {
        authorization: `bearer ${jwt}`,
        'apns-topic': bundleId,
        'apns-push-type': messageKind === 'photo_sync' ? 'background' : 'alert',
        'apns-priority': messageKind === 'photo_sync' ? '5' : '10',
        'apns-expiration': '0',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        aps: {
          ...(messageKind === 'photo_sync' ? {} : {
            alert: { title: '小分队', body: '你的小队有新消息' },
          }),
          ...(['photo', 'photo_sync'].includes(messageKind) ? { 'content-available': 1 } : {}),
        },
        ...(['photo', 'photo_sync'].includes(messageKind) ? { squadly: { v: 1, type: 'photo_sync' } } : {}),
      }),
    },
  };
}

function classifyApnsResponse(status, reason) {
  if (status === 200) return 'sent';
  if (['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic'].includes(reason)) {
    return 'dead';
  }
  return 'retry';
}

module.exports = { apnsRequest, classifyApnsResponse, createApnsJwt };
