import assert from 'node:assert/strict';
import { test } from 'node:test';
import { classifyMiPushResponse, miPushRequest } from './mipush.ts';

test('Mi Push sends only a generic sync hint to the selected approved channel', () => {
  const request = miPushRequest(
    'mi-reg-id-0123456789',
    'app-secret-test-only',
    'com.squadly.squadly',
    'squad-chat-approved',
  );
  assert.equal(request.url, 'https://api.xmpush.xiaomi.com/v2/message/regid');
  assert.equal(request.init.method, 'POST');
  assert.equal(request.init.headers.Authorization, 'key=app-secret-test-only');

  const form = new URLSearchParams(String(request.init.body));
  assert.equal(form.get('registration_id'), 'mi-reg-id-0123456789');
  assert.equal(form.get('restricted_package_name'), 'com.squadly.squadly');
  assert.equal(form.get('title'), '小分队');
  assert.equal(form.get('description'), '你的小队有新消息');
  assert.equal(form.get('payload'), '{"type":"sync"}');
  assert.equal(form.get('extra.channel_id'), 'squad-chat-approved');
  assert.equal(form.has('message_id'), false);
  assert.equal(form.has('health'), false);
  assert.equal(form.has('route'), false);
});

test('Mi Push classifies accepted, invalid-target, and retryable responses', () => {
  assert.equal(classifyMiPushResponse(200, { code: 0 }), 'sent');
  assert.equal(
    classifyMiPushResponse(200, { code: 0, data: { invalid_target: 1 } }),
    'dead',
  );
  assert.equal(classifyMiPushResponse(200, { code: 10016 }), 'retry');
  assert.equal(classifyMiPushResponse(503, { code: 0 }), 'retry');
  assert.equal(classifyMiPushResponse(200, null), 'retry');
});

test('Mi Push request refuses incomplete destination or credentials', () => {
  assert.throws(() => miPushRequest('', 'secret', 'pkg', 'channel'));
  assert.throws(() => miPushRequest('registration-id', '', 'pkg', 'channel'));
});
