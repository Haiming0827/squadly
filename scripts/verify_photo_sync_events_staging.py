#!/usr/bin/env python3
"""Scoped synthetic staging events, with real C JWT and server-only inspection.

Never claims a global delivery batch, sends a push, or changes A/B accounts.
"""
import argparse
import base64
import json
from pathlib import Path
import secrets
import stat
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPRedirectHandler
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--server-config', required=True)
parser.add_argument('--report', required=True)
parser.add_argument('--allow-test-writes', action='store_true')
args = parser.parse_args()
assert args.allow_test_writes, 'Explicit synthetic staging writes required'


def private_json(name):
    path = Path(name)
    assert not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == 0o600
    return json.loads(path.read_text())


config = private_json(args.config)
assert config['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c' and config['region'] == 'ap-shanghai'
server = private_json(args.server_config)
assert server['envId'] == config['environmentId']
settings = next(f['envVariables'] for f in server['functions'] if f['name'] == 'photos')
base = 'https://' + config['environmentId'] + '.api.tcloudbasegateway.com'
assert settings['CLOUDBASE_API_ORIGIN'] == base
server_key = settings['CLOUDBASE_APIKEY']
actor = config['actors']['c']
claim = json.loads(base64.urlsafe_b64decode(actor['jwt'].split('.')[1] + '==='))
assert claim['sub'] == actor['userId'] and claim.get('role') in ('user', 'authenticated')
assert claim.get('is_system_admin') is not True and claim['exp'] > time.time() + 120


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *unused):
        return None


opener = build_opener(NoRedirect())
checks = []
squad = None
device = str(uuid.uuid4())


def request(route, method='GET', body=None, administrative=False):
    headers = {'Authorization': 'Bearer ' + (server_key if administrative else actor['jwt']),
               'Content-Type': 'application/json', 'x-device-id': actor['deviceId']}
    req = Request(base + route, method=method, headers=headers,
                  data=None if body is None else json.dumps(body).encode())
    try:
        with opener.open(req, timeout=20) as response:
            raw = response.read(65536)
            return response.status, json.loads(raw) if raw else None
    except HTTPError as error:
        # No URL, token, SQL body or server error text in exceptions/reports.
        return error.code, None


def check(label, ok):
    checks.append({'check': label, 'passed': bool(ok)})
    if not ok:
        raise RuntimeError('Scoped staging check failed: ' + label + '; response redacted')


def rows():
    assert squad and uuid.UUID(squad)
    status, value = request('/v1/rdb/rest/photo_sync_deliveries?' + urlencode({
        'squad_id': 'eq.' + squad, 'select': 'id,user_id,device_id,generation,status,provider'}), administrative=True)
    check('scoped_server_read', status == 200 and isinstance(value, list))
    check('no_other_account_in_fixture', all(r['user_id'] == actor['userId'] for r in value))
    return [r for r in value if r['device_id'] == device]


cleanup_ok = False
try:
    status, identity = request('/auth/v1/user/me?' + urlencode({'client_id': config['environmentId']}))
    identity = identity.get('data', identity) if isinstance(identity, dict) else {}
    check('ordinary_c_identity_positive', status == 200 and (identity.get('sub') or identity.get('uid')) == actor['userId'])
    status, value = request('/v1/rdb/rest/rpc/create_squad', 'POST', {'p_name': 'Synthetic privacy acceptance ' + secrets.token_hex(4)})
    # Capture the created identity before assertions so finally can clean up.
    if status == 200 and isinstance(value, dict) and value.get('created_by') == actor['userId']:
        squad = str(uuid.UUID(value['id']))
    check('ordinary_c_created_own_fixture', squad is not None and value.get('status') == 'pending')
    status, _ = request('/v1/rdb/rest/rpc/register_push_token', 'POST', {
        'p_device_id': device, 'p_provider': 'apns', 'p_token': secrets.token_hex(32)})
    check('ordinary_c_registered_synthetic_token', status == 200)
    check('no_quiet_event_before_change', rows() == [])
    query = '/v1/rdb/rest/squads?' + urlencode({'id': 'eq.' + squad})
    status, _ = request(query, 'PATCH', {'status': 'active'}, administrative=True)
    check('synthetic_activation', status == 204)
    status, _ = request(query, 'PATCH', {'status': 'pending'}, administrative=True)
    check('synthetic_inactivation', status == 204)
    current = rows()
    check('inactivation_trigger_generated_hint', len(current) == 1 and current[0]['generation'] == 1 and current[0]['status'] == 'pending' and current[0]['provider'] == 'apns')
    status, _ = request(query, 'PATCH', {'status': 'pending'}, administrative=True)
    check('repeat_state_write', status == 204)
    check('unchanged_state_did_not_enqueue', rows()[0]['generation'] == 1)
    status, _ = request('/v1/rdb/rest/squad_members?' + urlencode({'squad_id': 'eq.' + squad, 'user_id': 'eq.' + actor['userId']}), 'DELETE', administrative=True)
    check('synthetic_member_removal', status == 204)
    current = rows()
    check('former_member_still_receives_hint', len(current) == 1 and current[0]['generation'] == 2)
    status, members = request('/v1/rdb/rest/squads?' + urlencode({'id': 'eq.' + squad, 'select': 'id,status,squad_members(user_id)'}))
    check('ordinary_c_access_removed', status == 200 and members == [])
    status, _ = request(query, 'DELETE', administrative=True)
    check('synthetic_squad_deleted', status == 204)
    current = rows()
    check('hint_survives_squad_deletion', len(current) == 1 and current[0]['status'] == 'pending')
finally:
    cleanup = []
    if squad:
        # Scope is a newly returned Squad created by C in this invocation only.
        for table, filters in [
            ('squads', {'id': 'eq.' + squad}),
            ('photo_sync_deliveries', {'squad_id': 'eq.' + squad}),
        ]:
            status, _ = request('/v1/rdb/rest/' + table + '?' + urlencode(filters), 'DELETE', administrative=True)
            cleanup.append(status == 204)
    status, _ = request('/v1/rdb/rest/device_push_tokens?' + urlencode({
        'user_id': 'eq.' + actor['userId'], 'device_id': 'eq.' + device, 'provider': 'eq.apns'}), 'DELETE', administrative=True)
    cleanup.append(status == 204)
    for table, filters in ([
        ('squads', {'id': 'eq.' + squad, 'select': 'id'}),
        ('photo_sync_deliveries', {'squad_id': 'eq.' + squad, 'select': 'id'}),
    ] if squad else []) + [
        ('device_push_tokens', {'user_id': 'eq.' + actor['userId'], 'device_id': 'eq.' + device, 'select': 'device_id'}),
    ]:
        status, value = request('/v1/rdb/rest/' + table + '?' + urlencode(filters), administrative=True)
        cleanup.append(status == 200 and value == [])
    cleanup_ok = all(cleanup)
    checks.append({'check': 'synthetic_fixture_cleanup', 'passed': cleanup_ok})
    Path(args.report).write_text(json.dumps({'environment': 'staging', 'scope': 'C-owned synthetic status/removal/delete event fixture',
        'ordinaryJwtUsedForIdentityCreationRegistrationAndDenial': True, 'serverKeyUsedOnlyForScopedSyntheticMutationAndInspection': True,
        'globalClaimAttempted': False, 'providerInvoked': False, 'actualUserPhotoUsed': False,
        'checks': checks, 'passed': sum(c['passed'] for c in checks), 'failed': sum(not c['passed'] for c in checks)}, indent=2) + '\n')
assert cleanup_ok, 'Scoped fixture cleanup failed'
print(str(len(checks)) + ' scoped staging event checks passed; synthetic fixture removed, no batch claimed or push sent.')
