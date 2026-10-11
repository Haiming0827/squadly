import assert from 'node:assert/strict';
import { test } from 'node:test';
import { webcrypto } from 'node:crypto';

import { apnsRequest, classifyApnsResponse, createApnsJwt } from './apns.ts';

test('APNs JWT has verifiable ES256 signature', async () => {
  const pair = await webcrypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  );
  const privateDer = new Uint8Array(await webcrypto.subtle.exportKey('pkcs8', pair.privateKey));
  const privatePem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(privateDer).toString('base64')}\n-----END PRIVATE KEY-----`;
  const jwt = await createApnsJwt('TESTTEAM', 'TESTKEY', privatePem, 1234567890);
  const [header, claims, signature] = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url').toString()), {
    alg: 'ES256', kid: 'TESTKEY',
  });
  assert.deepEqual(JSON.parse(Buffer.from(claims, 'base64url').toString()), {
    iss: 'TESTTEAM', iat: 1234567890,
  });
  assert.equal(await webcrypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    pair.publicKey,
    Buffer.from(signature, 'base64url'),
    new TextEncoder().encode(`${header}.${claims}`),
  ), true);
});

test('APNs payload is generic and environment-specific', () => {
  const request = apnsRequest('aabbcc', 'jwt', 'com.squadly.squadly', 'sandbox');
  assert.equal(request.url, 'https://api.sandbox.push.apple.com/3/device/aabbcc');
  assert.deepEqual(JSON.parse(request.init.body), {
    aps: { alert: { title: '小分队', body: '你的小队有新消息' } },
  });
  assert.equal(request.init.headers['apns-topic'], 'com.squadly.squadly');
  assert.equal(classifyApnsResponse(200, null), 'sent');
  assert.equal(classifyApnsResponse(410, 'Unregistered'), 'dead');
  assert.equal(classifyApnsResponse(429, 'TooManyRequests'), 'retry');
  assert.throws(() => apnsRequest('not-a-token', 'jwt', 'bundle', 'production'));
});
