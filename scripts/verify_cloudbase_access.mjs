#!/usr/bin/env node
import { readFile, stat, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const actorNames = ['a', 'b', 'c'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fixtureNames = [
  'memberSquad', 'audienceSquad', 'assetA', 'assetB', 'healthA', 'healthB',
  'materialA', 'materialB', 'privatePlanA', 'privatePlanB', 'sharedPlan',
  'privateTaskA', 'privateTaskB', 'sharedTask', 'privateMessageA',
  'privateMessageB', 'sharedPlanMessage', 'generalMessage', 'selectedPost', 'publicFund',
];

class ConfigError extends Error {
  constructor(field) { super(`Invalid acceptance configuration: ${field}`); }
}

function rejectServerCredential(value, field) {
  if (/service[_-]?role|secret[_-]?key/i.test(value)) throw new ConfigError(field);
  const parts = value.split('.');
  if (parts.length !== 3) return;
  try {
    const claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    if (['service_role', 'supabase_admin', 'postgres'].includes(claims.role)) {
      throw new ConfigError(field);
    }
  } catch (error) {
    if (error instanceof ConfigError) throw error;
    throw new ConfigError(field);
  }
}

export function validateConfig(config, expectedEnvironment) {
  if (!expectedEnvironment || config?.environmentId !== expectedEnvironment ||
      !/^[a-z0-9]+(?:-[a-z0-9]+)*$/i.test(config.environmentId) ||
      !config.environmentId.toLowerCase().includes('staging')) {
    throw new ConfigError('environmentId');
  }
  if (!['ap-shanghai', 'ap-singapore'].includes(config.region)) throw new ConfigError('region');
  if (typeof config.publishableKey !== 'string' || config.publishableKey.length < 20 || /\s|replace|placeholder|your-/i.test(config.publishableKey)) {
    throw new ConfigError('publishableKey');
  }
  rejectServerCredential(config.publishableKey, 'publishableKey');
  const identities = new Set();
  const tokens = new Set([config.publishableKey]);
  for (const name of actorNames) {
    const actor = config.actors?.[name];
    if (!actor || typeof actor.userId !== 'string' || !actor.userId.trim() || actor.userId.length > 64 || identities.has(actor.userId)) {
      throw new ConfigError(`actors.${name}.userId`);
    }
    if (typeof actor.jwt !== 'string' || actor.jwt.length < 20 || /\s|replace|placeholder/i.test(actor.jwt) || tokens.has(actor.jwt)) {
      throw new ConfigError(`actors.${name}.jwt`);
    }
    rejectServerCredential(actor.jwt, `actors.${name}.jwt`);
    identities.add(actor.userId);
    tokens.add(actor.jwt);
  }
  const ids = new Set();
  for (const name of fixtureNames) {
    const value = config.fixtures?.[name];
    if (typeof value !== 'string' || !uuid.test(value) || ids.has(value)) throw new ConfigError(`fixtures.${name}`);
    ids.add(value);
  }
  return config;
}

function resources(config) {
  const f = config.fixtures;
  const id = (name) => f[name];
  const squad = { squad_id: id('memberSquad') };
  const rows = [];
  const add = (name, table, allowed, expected) => rows.push({ name, table, allowed, expected: { id: id(name), ...expected } });
  add('memberSquad', 'squads', ['a', 'b'], {});
  for (const [suffix, actor] of [['A', 'a'], ['B', 'b']]) {
    const owner = config.actors[actor].userId;
    add(`asset${suffix}`, 'private_assets', [actor], { user_id: owner });
    add(`health${suffix}`, 'health_snapshots', [actor], { ...squad, user_id: owner });
    add(`material${suffix}`, 'external_data_items', [actor], { user_id: owner });
    add(`privatePlan${suffix}`, 'squad_plans', [actor], { ...squad, created_by: owner, visibility: 'private' });
    add(`privateTask${suffix}`, 'squad_plan_tasks', [actor], { ...squad, plan_id: id(`privatePlan${suffix}`) });
    add(`privateMessage${suffix}`, 'squad_messages', [actor], { ...squad, plan_id: id(`privatePlan${suffix}`) });
  }
  add('sharedPlan', 'squad_plans', ['a', 'b'], { ...squad, visibility: 'squad' });
  add('sharedTask', 'squad_plan_tasks', ['a', 'b'], { ...squad, plan_id: id('sharedPlan') });
  add('sharedPlanMessage', 'squad_messages', ['a', 'b'], { ...squad, plan_id: id('sharedPlan') });
  add('generalMessage', 'squad_messages', ['a', 'b'], { ...squad, plan_id: null });
  add('selectedPost', 'social_posts', ['a', 'b'], {
    squad_id: id('audienceSquad'), author_id: config.actors.a.userId,
    visibility: 'selected', visible_to_user_ids: [config.actors.b.userId],
  });
  add('publicFund', 'public_funds', ['a', 'b'], squad);
  // The last query must prove that every supplied actor remains authenticated
  // after the negative checks. Otherwise an expired JWT can masquerade as RLS.
  add('audienceSquad', 'squads', ['a', 'b', 'c'], {});
  return rows;
}

function visibleResult(response, expected) {
  if (response.error) return response.error;
  if (response.status !== 200) return 'http_rejected';
  if (!Array.isArray(response.rows) || response.rows.length !== 1) return 'fixture_not_visible';
  const row = response.rows[0];
  if (!row || typeof row !== 'object' || Array.isArray(row) ||
      Object.keys(row).sort().join(',') !== Object.keys(expected).sort().join(',')) return 'unexpected_columns';
  for (const [key, value] of Object.entries(expected)) {
    if (JSON.stringify(row[key]) !== JSON.stringify(value)) return 'fixture_relationship_mismatch';
  }
  return null;
}

function deniedResult(response) {
  if (response.error) return response.error;
  if ([401, 403].includes(response.status)) return null;
  if (response.status !== 200) return 'http_unavailable';
  if (!Array.isArray(response.rows)) return 'invalid_response';
  return response.rows.length === 0 ? null : 'unexpected_visibility';
}

/** Read-only acceptance: fixed GET projections, no RPCs or business writes. */
export async function verifyReadAccess(config, { expectedEnvironment, fetchImpl = fetch } = {}) {
  validateConfig(config, expectedEnvironment);
  const gateway = config.region === 'ap-singapore' ? 'api.intl.tcloudbasegateway.com' : 'api.tcloudbasegateway.com';
  const base = `https://${config.environmentId}.${gateway}/v1/rdb/rest/`;
  const allActors = [...actorNames, 'anonymous'];
  const observations = [];
  for (const resource of resources(config)) {
    const url = new URL(resource.table, base);
    url.searchParams.set('select', Object.keys(resource.expected).join(','));
    url.searchParams.set('id', `eq.${resource.expected.id}`);
    url.searchParams.set('limit', '2');
    const responses = await Promise.all(allActors.map(async (actor) => {
      try {
        const token = actor === 'anonymous' ? config.publishableKey : config.actors[actor].jwt;
        const response = await fetchImpl(url, {
          method: 'GET', redirect: 'error', signal: AbortSignal.timeout(10000),
          headers: { Accept: 'application/json', Authorization: `Bearer ${token}` },
        });
        const rows = response.status === 200 ? await response.json() : null;
        if (response.status !== 200) await response.body?.cancel();
        return { actor, status: response.status, rows };
      } catch {
        // Fetch/parse errors may contain URLs, credentials or response bodies.
        return { actor, error: 'transport_or_response_unavailable' };
      }
    }));
    observations.push({ resource, responses });
  }
  const authenticated = new Set();
  const finalControl = observations.at(-1);
  for (const response of finalControl.responses) {
    if (actorNames.includes(response.actor) && !visibleResult(response, finalControl.resource.expected)) authenticated.add(response.actor);
  }
  const checks = [];
  for (const { resource, responses } of observations) {
    const controlsPassed = responses.filter((r) => resource.allowed.includes(r.actor))
      .every((r) => !visibleResult(r, resource.expected));
    for (const response of responses) {
      const visible = resource.allowed.includes(response.actor);
      const reason = visible ? visibleResult(response, resource.expected) : deniedResult(response);
      const controlsMissing = !visible && (!controlsPassed ||
        (response.actor !== 'anonymous' && !authenticated.has(response.actor)));
      checks.push({
        resource: resource.name, actor: response.actor, expected: visible ? 'visible' : 'denied',
        status: reason ? 'fail' : controlsMissing ? 'blocked' : 'pass',
        reason: reason ?? (controlsMissing ? 'positive_control_missing' : 'verified'),
        ...(response.status == null ? {} : { httpStatus: response.status }),
      });
    }
  }
  return {
    environmentId: config.environmentId, checkedAt: new Date().toISOString(),
    scope: 'read_only_fixture_visibility', requiredMigration: '20261020000100',
    passed: checks.every((c) => c.status === 'pass'), checks,
    notVerified: ['schema_version_inventory', 'SDK_login_OTP', 'writes_and_RPC_permissions',
      'invitation_concurrency_capacity_leave', 'realtime_push', 'devices', 'release'],
    denialAttribution: 'HTTP 401/403 may originate at the gateway or database; the report does not distinguish them.',
  };
}

async function main() {
  const options = {};
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i += 2) {
    if (!['--config', '--environment', '--report'].includes(args[i]) || !args[i + 1] || options[args[i]]) throw new ConfigError('arguments');
    options[args[i]] = args[i + 1];
  }
  if (!options['--config']) throw new ConfigError('config_file');
  const info = await stat(options['--config']);
  if (!info.isFile() || (info.mode & 0o077) !== 0) throw new ConfigError('config_file_permissions_require_0600');
  const config = JSON.parse(await readFile(options['--config'], 'utf8'));
  const report = await verifyReadAccess(config, { expectedEnvironment: options['--environment'] });
  const output = JSON.stringify(report, null, 2) + '\n';
  if (options['--report']) await writeFile(options['--report'], output, { flag: 'wx', mode: 0o600 });
  process.stdout.write(output);
  process.exitCode = report.passed ? 0 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof ConfigError ? error.message : 'Acceptance tool failed; inspect local configuration and report path.'}\n`);
    process.exitCode = 2;
  });
}
