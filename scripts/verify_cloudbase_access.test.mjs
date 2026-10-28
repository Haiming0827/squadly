import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, chmod, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { validateConfig, verifyReadAccess } from './verify_cloudbase_access.mjs';

const env = 'squadly-staging-acceptance';
const names = ['memberSquad', 'audienceSquad', 'assetA', 'assetB', 'healthA', 'healthB',
  'materialA', 'materialB', 'privatePlanA', 'privatePlanB', 'sharedPlan', 'privateTaskA',
  'privateTaskB', 'sharedTask', 'privateMessageA', 'privateMessageB', 'sharedPlanMessage',
  'generalMessage', 'selectedPost', 'publicFund'];
const jwt = (name, role = 'authenticated') => ['header', Buffer.from(JSON.stringify({ sub: name, role, marker: 'sensitive-credential-marker' })).toString('base64url'), 'signature'].join('.');
function config() {
  return { environmentId: env, region: 'ap-shanghai', publishableKey: 'public-publishable-key-for-tests',
    actors: Object.fromEntries(['a', 'b', 'c'].map((name) => [name, { userId: `user-${name}`, jwt: jwt(name) }])),
    fixtures: Object.fromEntries(names.map((name, index) => [name, `00000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`])),
  };
}

test('the committed example cannot run before real credentials are supplied', async () => {
  const example = JSON.parse(await readFile(new URL('../docs/modules/backend_cloudbase/access-acceptance.example.json', import.meta.url), 'utf8'));
  assert.throws(() => validateConfig(example, example.environmentId), /publishableKey/);
});

function database(c) {
  const f = c.fixtures;
  const row = (fixture, table, visible, fields = {}) => ({ fixture, table, visible, data: { id: f[fixture], ...fields } });
  const squad = { squad_id: f.memberSquad };
  return [
    row('memberSquad', 'squads', ['a', 'b']), row('audienceSquad', 'squads', ['a', 'b', 'c']),
    ...[['A', 'a'], ['B', 'b']].flatMap(([suffix, actor]) => [
      row(`asset${suffix}`, 'private_assets', [actor], { user_id: `user-${actor}`, amount: 98765 }),
      row(`health${suffix}`, 'health_snapshots', [actor], { ...squad, user_id: `user-${actor}`, weight: 72.4 }),
      row(`material${suffix}`, 'external_data_items', [actor], { user_id: `user-${actor}`, summary: 'private-source-text' }),
      row(`privatePlan${suffix}`, 'squad_plans', [actor], { ...squad, created_by: `user-${actor}`, visibility: 'private' }),
      row(`privateTask${suffix}`, 'squad_plan_tasks', [actor], { ...squad, plan_id: f[`privatePlan${suffix}`] }),
      row(`privateMessage${suffix}`, 'squad_messages', [actor], { ...squad, plan_id: f[`privatePlan${suffix}`], body: 'private-message-text' }),
    ]),
    row('sharedPlan', 'squad_plans', ['a', 'b'], { ...squad, visibility: 'squad' }),
    row('sharedTask', 'squad_plan_tasks', ['a', 'b'], { ...squad, plan_id: f.sharedPlan }),
    row('sharedPlanMessage', 'squad_messages', ['a', 'b'], { ...squad, plan_id: f.sharedPlan }),
    row('generalMessage', 'squad_messages', ['a', 'b'], { ...squad, plan_id: null }),
    row('selectedPost', 'social_posts', ['a', 'b'], { squad_id: f.audienceSquad, author_id: 'user-a', visibility: 'selected', visible_to_user_ids: ['user-b'] }),
    row('publicFund', 'public_funds', ['a', 'b'], squad),
  ];
}

function transport(c, alter = () => null) {
  const records = database(c);
  const requests = [];
  const fetchImpl = async (url, options) => {
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    assert.equal(url.protocol, 'https:');
    assert.equal(url.hostname, `${env}.api.tcloudbasegateway.com`);
    assert.equal(url.searchParams.get('limit'), '2');
    const token = options.headers.Authorization.replace('Bearer ', '');
    const actor = Object.keys(c.actors).find((name) => c.actors[name].jwt === token) ?? 'anonymous';
    const record = records.find((r) => url.pathname === `/v1/rdb/rest/${r.table}` && url.searchParams.get('id') === `eq.${r.data.id}`);
    assert.ok(record, 'query must match a declared fixture');
    const columns = url.searchParams.get('select').split(',');
    assert.ok(columns.every((column) => !['body', 'summary', 'amount', 'weight', 'nickname', 'title', 'metric_value'].includes(column)));
    requests.push({ actor, fixture: record.fixture });
    const changed = alter({ actor, record, columns });
    if (changed) return changed;
    const rows = record.visible.includes(actor)
      ? [Object.fromEntries(columns.map((column) => [column, record.data[column]]))] : [];
    return Response.json(rows, { status: actor === 'anonymous' ? 403 : 200 });
  };
  return { fetchImpl, requests };
}

test('all 80 fixture/actor boundaries pass without requesting private values', async () => {
  const c = config();
  const network = transport(c);
  const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
  assert.equal(report.passed, true);
  assert.equal(report.checks.length, 80);
  assert.equal(network.requests.length, 80);
  const output = JSON.stringify(report);
  for (const value of [c.actors.a.jwt, c.actors.a.userId, c.fixtures.assetA, '98765', '72.4', 'private-source-text', 'private-message-text']) {
    assert.ok(!output.includes(value));
  }
  assert.ok(report.notVerified.includes('writes_and_RPC_permissions'));
});

test('missing owner fixtures block negative results instead of proving RLS', async () => {
  const c = config();
  const network = transport(c, ({ record }) => record.fixture === 'assetA' ? Response.json([]) : null);
  const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
  assert.equal(report.passed, false);
  assert.equal(report.checks.find((r) => r.resource === 'assetA' && r.actor === 'b').status, 'blocked');
});

test('expired actor credentials cannot make negative visibility checks pass', async () => {
  const c = config();
  const network = transport(c, ({ actor }) => actor === 'b' ? new Response(null, { status: 401 }) : null);
  const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
  assert.equal(report.passed, false);
  assert.equal(report.checks.find((r) => r.resource === 'assetA' && r.actor === 'b').status, 'blocked');
});

test('a JWT expiring after an earlier positive control still fails acceptance', async () => {
  const c = config();
  let expired = false;
  const network = transport(c, ({ actor, record }) => {
    if (actor !== 'c') return null;
    if (record.fixture === 'assetA') expired = true;
    return expired ? new Response(null, { status: 401 }) : null;
  });
  const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
  assert.equal(report.passed, false);
  assert.equal(report.checks.find((r) => r.resource === 'assetA' && r.actor === 'c').status, 'blocked');
});

for (const status of [400, 404, 500]) {
  test(`HTTP ${status} is a failure, not an authorization denial`, async () => {
    const c = config();
    const network = transport(c, ({ actor, record }) => actor === 'c' && record.fixture === 'assetA' ? new Response(null, { status }) : null);
    const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
    assert.equal(report.passed, false);
    assert.equal(report.checks.find((r) => r.resource === 'assetA' && r.actor === 'c').status, 'fail');
  });
}

test('an unauthorized visible row fails the matrix', async () => {
  const c = config();
  const network = transport(c, ({ actor, record }) => actor === 'b' && record.fixture === 'assetA' ? Response.json([{ id: record.data.id }]) : null);
  const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
  assert.equal(report.passed, false);
  assert.equal(report.checks.find((r) => r.resource === 'assetA' && r.actor === 'b').reason, 'unexpected_visibility');
});

test('unexpected private columns and transport errors stay out of reports', async () => {
  const c = config();
  const network = transport(c, ({ actor, record }) => {
    if (actor === 'a' && record.fixture === 'assetA') return Response.json([{ ...record.data, secret: 'do-not-log-this' }]);
    if (actor === 'b' && record.fixture === 'healthB') throw new Error(`do-not-log-this ${c.actors.b.jwt}`);
    return null;
  });
  const report = await verifyReadAccess(c, { expectedEnvironment: env, fetchImpl: network.fetchImpl });
  assert.equal(report.passed, false);
  assert.ok(!JSON.stringify(report).includes('do-not-log-this'));
  assert.ok(!JSON.stringify(report).includes(c.actors.b.jwt));
});

test('wrong environment and server credentials fail before any network call', async () => {
  const c = config();
  const fetchImpl = () => assert.fail('network must not run');
  await assert.rejects(verifyReadAccess(c, { expectedEnvironment: 'other-staging', fetchImpl }), /environmentId/);
  c.actors.a.jwt = jwt('a', 'service_role');
  await assert.rejects(verifyReadAccess(c, { expectedEnvironment: env, fetchImpl }), /actors.a.jwt/);
});

test('incomplete or duplicated fixtures and identities cannot be silently skipped', () => {
  for (const change of [
    (c) => delete c.fixtures.privateMessageA,
    (c) => c.actors.b.userId = c.actors.a.userId,
    (c) => c.actors.b.jwt = c.actors.a.jwt,
    (c) => c.fixtures.assetA = c.fixtures.assetB,
  ]) {
    const c = config();
    change(c);
    assert.throws(() => validateConfig(c, env), /Invalid acceptance configuration/);
  }
});

test('CLI refuses broadly readable credential files without echoing contents', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'squadly-access-test-'));
  try {
    const file = join(directory, 'credentials.json');
    await writeFile(file, JSON.stringify(config()), { mode: 0o600 });
    await chmod(file, 0o644);
    const result = spawnSync(process.execPath, ['scripts/verify_cloudbase_access.mjs', '--config', file, '--environment', env], { encoding: 'utf8' });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /permissions_require_0600/);
    assert.ok(!result.stderr.includes('sensitive-credential-marker'));
    assert.equal(result.stdout, '');
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
