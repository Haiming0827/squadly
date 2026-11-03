#!/usr/bin/env python3
"""Ordinary C JWT controls for service-only privacy work; never dispatches pushes."""
import argparse
import base64
import json
import os
from pathlib import Path
import stat
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPRedirectHandler

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--report', required=True)
parser.add_argument('--refresh-test-account', action='store_true')
args = parser.parse_args()
path = Path(args.config)
assert not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == 0o600
config = json.loads(path.read_text())
assert config['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c'
assert config['region'] == 'ap-shanghai'
actor = config['actors']['c']  # Controlled non-member fixture only, never A/B SDK refresh.
base = 'https://' + config['environmentId'] + '.api.tcloudbasegateway.com'

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *unused):
        return None

opener = build_opener(NoRedirect())


def request(route, body=None, jwt=None):
    headers = {'Content-Type': 'application/json', 'x-device-id': actor['deviceId']}
    if jwt:
        headers['Authorization'] = 'Bearer ' + jwt
    req = Request(base + route, data=None if body is None else json.dumps(body).encode(), headers=headers)
    try:
        with opener.open(req, timeout=20) as response:
            return response.status, json.loads(response.read(65536))
    except HTTPError as error:
        raw = error.read(65536)
        try:
            value = json.loads(raw)
        except ValueError:
            value = None
        return error.code, value


def claims(jwt):
    value = json.loads(base64.urlsafe_b64decode(jwt.split('.')[1] + '==='))
    assert value['sub'] == actor['userId'] and value.get('role') in ('user', 'authenticated')
    assert value.get('is_system_admin') is not True and value['exp'] > time.time() + 60
    return value

if args.refresh_test_account:
    status, value = request('/auth/v1/token?' + urlencode({'client_id': config['environmentId']}), {
        'client_id': config['environmentId'], 'grant_type': 'refresh_token',
        'refresh_token': actor['refresh_token'],
    })
    assert status == 200, 'Controlled C session refresh failed; response redacted'
    value = value.get('data', value)
    claims(value['access_token'])
    actor['jwt'] = value['access_token']
    actor['refresh_token'] = value['refresh_token']
    temporary = path.with_suffix('.tmp')
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        json.dump(config, stream)
    os.replace(temporary, path)
claims(actor['jwt'])
checks = []


def check(label, ok, status):
    checks.append({'check': label, 'passed': bool(ok), 'httpStatus': status})
    if not ok:
        raise RuntimeError('Staging check failed: ' + label + '; response redacted')

status, value = request('/auth/v1/user/me?' + urlencode({'client_id': config['environmentId']}), jwt=actor['jwt'])
value = value.get('data', value) if isinstance(value, dict) else {}
check('ordinary_identity_positive', status == 200 and (value.get('sub') or value.get('uid')) == actor['userId'], status)
status, value = request('/v1/rdb/rest/profiles?' + urlencode({'id': 'eq.' + actor['userId'], 'select': 'id'}), jwt=actor['jwt'])
check('own_profile_positive', status == 200 and value == [{'id': actor['userId']}], status)

fake = '94000000-0000-4000-8000-000000000001'
# Invalid limit prevents claiming anyone's lease even if a permission regression
# accidentally exposes the RPC. Permission denial must occur before validation.
operations = [
    ('table', '/photo_sync_deliveries?select=id&limit=0', None),
    ('claim', '/rpc/claim_push_work', {'p_limit': 0, 'p_provider': 'apns'}),
    ('quiet_claim', '/rpc/claim_photo_sync', {'p_limit': 0}),
    ('enqueue', '/rpc/enqueue_photo_sync', {'p_squad_id': fake}),
    ('complete', '/rpc/complete_push_work', {'p_lease_kind': 'photo_sync', 'p_delivery_id': fake, 'p_claim_id': fake, 'p_outcome': 'sent'}),
    ('quiet_complete', '/rpc/complete_photo_sync', {'p_delivery_id': fake, 'p_claim_id': fake, 'p_outcome': 'sent'}),
]
try:
    for name, route, body in operations:
        status, value = request('/v1/rdb/rest' + route, body, actor['jwt'])
        check('ordinary_' + name + '_denied', status == 403 and isinstance(value, dict) and value.get('code') in ('42501', 'DATABASE_42501'), status)
    for name, route, body in operations[:2]:
        status, _ = request('/v1/rdb/rest' + route, body)
        check('anonymous_' + name + '_denied', status in (401, 403), status)
finally:
    Path(args.report).write_text(json.dumps({'environment': 'staging', 'ordinaryActor': 'controlled_nonmember_c',
        'serviceKeyUsed': False, 'dispatchAttempted': False, 'checks': checks,
        'passed': sum(c['passed'] for c in checks), 'failed': sum(not c['passed'] for c in checks)}, indent=2) + '\n')
print(str(len(checks)) + ' ordinary/anonymous staging checks passed; no queue claimed or provider invoked.')
