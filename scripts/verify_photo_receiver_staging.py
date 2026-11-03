#!/usr/bin/env python3
"""Real A/B receiver safety, synthetic photos only; scoped server cleanup."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, build_opener, HTTPRedirectHandler
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--server-config', required=True)
parser.add_argument('--report', required=True)
parser.add_argument('--read-sdk-sessions', action='store_true')
parser.add_argument('--allow-test-writes', action='store_true')
args = parser.parse_args()
assert args.allow_test_writes
assert not Path(args.report).exists(), 'Use a new evidence path'


def private(path):
    p = Path(path)
    assert not p.is_symlink() and stat.S_IMODE(p.stat().st_mode) == 0o600
    return json.loads(p.read_text())


c = private(args.config)
assert c['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c' and c['region'] == 'ap-shanghai'
server = private(args.server_config)
assert server['envId'] == c['environmentId']
settings = next(f['envVariables'] for f in server['functions'] if f['name'] == 'photos')
base = 'https://' + c['environmentId'] + '.api.tcloudbasegateway.com'
assert settings['CLOUDBASE_API_ORIGIN'] == base
server_key = settings['CLOUDBASE_APIKEY']
gateway = c['photoAcceptance']['workerUrl']
url = urlparse(gateway)
assert url.scheme == 'https' and url.path == '/photos' and not url.query and not url.fragment and not url.username and url.port is None
assert url.hostname.startswith(c['environmentId'] + '-') and url.hostname.endswith('.ap-shanghai.app.tcloudbase.com')
if args.read_sdk_sessions:
    for actor, device in [('a', '370493B7-843A-47ED-AE82-7CB75E21691E'), ('b', 'DA33717A-0E70-4727-8623-A22CED1A5432')]:
        root = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, 'com.squadly.squadly', 'data'], text=True).strip())
        prefs = plistlib.loads((root / 'Library/Preferences/com.squadly.squadly.plist').read_bytes())
        sdk = json.loads(prefs['flutter.credentials_' + c['environmentId']])
        assert sdk['user']['id'] == c['actors'][actor]['userId']
        c['actors'][actor]['jwt'] = sdk['access_token']
        c['actors'][actor]['deviceId'] = prefs['flutter.device_id']
# Never read or rotate A/B SDK refresh tokens; do not persist copied JWTs.
for alias in ['a', 'b', 'c']:
    actor = c['actors'][alias]
    claim = json.loads(base64.urlsafe_b64decode(actor['jwt'].split('.')[1] + '==='))
    assert claim['sub'] == actor['userId'] and claim.get('role') in ('user', 'authenticated')
    assert claim.get('is_system_admin') is not True and claim['exp'] > time.time() + 300


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *unused):
        return None


opener = build_opener(NoRedirect())
checks = []
squad = None
published = []
object_keys = []
devices = {}


def http(path, actor='a', body=None, method=None, media=False):
    key = server_key if actor == 'server' else c['publishableKey'] if actor == 'anonymous' else c['actors'][actor]['jwt']
    headers = {'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}
    if actor in c['actors']:
        headers['x-device-id'] = c['actors'][actor]['deviceId']
    req = Request(gateway if media else base + path, method=method or ('POST' if body is not None else 'GET'), headers=headers,
                  data=None if body is None else json.dumps(body).encode())
    try:
        with opener.open(req, timeout=55) as response:
            raw = response.read(3 * 1024 * 1024)
            try:
                value = json.loads(raw) if raw else None
            except ValueError:
                value = None
            return response.status, value
    except HTTPError as error:
        try:
            value = json.loads(error.read(65536))
        except ValueError:
            value = None
        return error.code, value


def check(label, ok):
    checks.append({'check': label, 'passed': bool(ok)})
    if not ok:
        raise RuntimeError('Receiver safety check failed: ' + label + '; response redacted')
    print(label + ': pass', flush=True)


def ok(result, label):
    status, value = result
    check(label, status in (200, 201, 204) and not (isinstance(value, dict) and value.get('error')))
    return value


def rpc(name, body, actor='a'):
    return http('/v1/rdb/rest/rpc/' + name, actor, body)


def photo(action, message, actor='a', **extra):
    return http('', actor, {'action': action, 'squad_id': squad, 'message_id': message, **extra}, media=True)


def head(actor):
    return ok(rpc('get_squad_photo_head', {'p_squad_id': squad}, actor), actor + '_head')


cleanup = []
try:
    for alias in ['a', 'b', 'c']:
        value = ok(http('/auth/v1/user/me?' + urlencode({'client_id': c['environmentId']}), alias), alias + '_identity_http')
        value = value.get('data', value)
        check(alias + '_ordinary_identity', (value.get('sub') or value.get('uid')) == c['actors'][alias]['userId'])
        value = ok(http('/v1/rdb/rest/profiles?' + urlencode({'id': 'eq.' + c['actors'][alias]['userId'], 'select': 'id'}), alias), alias + '_profile_http')
        check(alias + '_own_profile_positive', value == [{'id': c['actors'][alias]['userId']}])
    team = ok(rpc('create_squad', {'p_name': '验收测试-接收者安全-' + uuid.uuid4().hex[:8]}), 'create_owned_fixture')
    assert team['created_by'] == c['actors']['a']['userId']
    squad = str(uuid.UUID(team['id']))
    invite = ok(rpc('issue_invitation', {'p_squad_id': squad}), 'invite_b')
    ok(rpc('redeem_invitation', {'p_credential': invite['code']}, 'b'), 'b_redeems_real_invite')
    for alias in ['a', 'b']:
        device = str(uuid.uuid4()); devices[alias] = device
        ok(rpc('register_push_token', {'p_device_id': device, 'p_provider': 'apns', 'p_token': uuid.uuid4().hex + uuid.uuid4().hex}, alias), alias + '_synthetic_device_registered')
    data = Path('test/features/photos/fixtures/sanitized.jpg').read_bytes()
    for index in range(2):
        value = ok(http('', 'a', {'action': 'publish', 'squad_id': squad, 'client_nonce': str(uuid.uuid4()),
            'source_sha256': hashlib.sha256(data).hexdigest(), 'bytes': base64.b64encode(data).decode()}, media=True), 'publish_synthetic_' + str(index))
        published.append(value)
        authority = ok(rpc('authorize_photo_read', {'p_squad_id': squad, 'p_message_id': value['message_id']}), 'own_object_authority_' + str(index))
        key = authority['object_key']
        assert key.startswith(value['media_id'] + '/') and key.endswith('.jpg') and len(key) == 77
        object_keys.append(key)
    first, latest = [p['message_id'] for p in published]
    # Derive latest by actual server order instead of assuming distinct timestamps.
    before_a = head('a'); latest = before_a['photo']['id']; first = next(p['message_id'] for p in published if p['message_id'] != latest)
    before_b = head('b'); check('same_initial_projection', before_a == before_b)
    value = ok(photo('load', latest, 'b'), 'b_bytes_before_hide')
    check('real_bytes_positive', hashlib.sha256(base64.b64decode(value['bytes'])).hexdigest() == value['sha256'])
    check('hide_confirmation', ok(photo('hide', latest, 'b'), 'b_hide') == {'hidden': True})
    queue = ok(http('/v1/rdb/rest/photo_sync_deliveries?' + urlencode({'squad_id': 'eq.' + squad, 'select': 'user_id,device_id'}), 'server'), 'scoped_private_hint_inspection')
    check('hide_only_hints_receiver_devices', bool(queue) and all(r['user_id'] == c['actors']['b']['userId'] for r in queue) and any(r['device_id'] == devices['b'] for r in queue))
    after_b = head('b'); check('private_version_and_fallback', int(after_b['revision']) == int(before_b['revision']) + 1 and after_b['photo']['id'] == first)
    check('author_head_unchanged', head('a') == before_a)
    value = ok(photo('load', latest, 'a'), 'a_bytes_after_b_hide'); check('author_bytes_unchanged', hashlib.sha256(base64.b64decode(value['bytes'])).hexdigest() == value['sha256'])
    status, value = photo('load', latest, 'b'); check('hidden_bytes_denied', status == 404 and 'bytes' not in (value or {}))
    check('hidden_parent_denied', ok(rpc('get_squad_photo', {'p_squad_id': squad, 'p_message_id': latest}, 'b'), 'hidden_parent_http') is None)
    wall = ok(rpc('page_squad_photos', {'p_squad_id': squad}, 'b'), 'hidden_wall_http'); check('hidden_wall_excludes_target', [p['id'] for p in wall] == [first])
    timeline = ok(rpc('page_squad_timeline', {'p_squad_id': squad}, 'b'), 'receiver_timeline_http'); check('hidden_timeline_tombstone', next(p for p in timeline if p['id'] == latest)['photo']['hidden'] is True)
    ok(photo('hide', latest, 'b'), 'repeat_hide'); check('repeat_hide_keeps_version', head('b') == after_b)
    status, _ = photo('report', first, 'a', reason='privacy'); check('self_report_denied', status == 404)
    for alias in ['c', 'anonymous']:
        status, _ = photo('hide', first, alias); check(alias + '_hide_denied', status in (401, 403, 404))
        status, _ = photo('report', first, alias, reason='privacy'); check(alias + '_report_denied', status in (401, 403, 404))
    status, _ = photo('report', first, 'b', reason='private-free-form'); check('free_form_reason_rejected', status == 422)
    check('report_confirmation', ok(photo('report', first, 'b', reason='privacy'), 'b_report') == {'hidden': True, 'reported': True})
    check('report_hides_last_photo', head('b') == {'revision': str(int(before_b['revision']) + 2), 'photo': None})
    ok(photo('report', first, 'b', reason='spam'), 'repeat_report')
    query = urlencode({'squad_id': 'eq.' + squad, 'select': 'reason,status'})
    rows = ok(http('/v1/rdb/rest/photo_reports?' + query, 'server'), 'scoped_server_report_inspection')
    check('one_original_report_case', rows == [{'reason': 'privacy', 'status': 'open'}])
    for alias in ['a', 'b', 'c']:
        status, _ = http('/v1/rdb/rest/photo_reports?' + query, alias); check(alias + '_report_table_denied', status == 403)
finally:
    # Only objects and identities created/returned in this invocation are touched.
    for value in published:
        status, _ = photo('revoke', value['message_id']); cleanup.append(status == 200)
    if published and len(object_keys) < len(published):
        ids = 'in.(' + ','.join(p['media_id'] for p in published) + ')'
        status, attempts = http('/v1/rdb/rest/photo_upload_attempts?' + urlencode({'media_id': ids, 'select': 'media_id,object_key'}), 'server')
        if status == 200 and isinstance(attempts, list):
            for attempt in attempts:
                key = attempt['object_key']
                if key.startswith(attempt['media_id'] + '/') and len(key) == 77 and key.endswith('.jpg') and key not in object_keys:
                    object_keys.append(key)
    for key in object_keys:
        status, _ = http('/v1/storages/object/squadly-photos', 'server', {'prefixes': [key]}, 'DELETE'); cleanup.append(status == 200)
        status, _ = http('/v1/storages/object/squadly-photos/' + key, 'server'); cleanup.append(status == 404)
    if squad:
        filters = '?' + urlencode({'squad_id': 'eq.' + squad})
        status, _ = http('/v1/rdb/rest/photo_media' + filters, 'server', {'state': 'preparing', 'active_attempt_id': None, 'revoked_at': None}, 'PATCH'); cleanup.append(status == 204)
        for table in ['squad_messages', 'photo_upload_attempts', 'photo_media', 'squads', 'photo_sync_deliveries']:
            key = 'id' if table == 'squads' else 'media_id' if table == 'photo_upload_attempts' else 'squad_id'
            value = 'in.(' + ','.join(p['media_id'] for p in published) + ')' if key == 'media_id' else 'eq.' + squad
            if key == 'media_id' and not published:
                continue
            status, _ = http('/v1/rdb/rest/' + table + '?' + urlencode({key: value}), 'server', method='DELETE'); cleanup.append(status == 204)
        for table in ['squads', 'photo_reports', 'hidden_photos', 'photo_sync_deliveries']:
            key = 'id' if table == 'squads' else 'squad_id'
            status, rows = http('/v1/rdb/rest/' + table + '?' + urlencode({key: 'eq.' + squad, 'select': key}), 'server')
            cleanup.append(status == 200 and rows == [])
    for alias, device in devices.items():
        filters = urlencode({'user_id': 'eq.' + c['actors'][alias]['userId'], 'device_id': 'eq.' + device, 'provider': 'eq.apns'})
        status, _ = http('/v1/rdb/rest/device_push_tokens?' + filters, 'server', method='DELETE'); cleanup.append(status == 204)
        status, rows = http('/v1/rdb/rest/device_push_tokens?' + filters + '&select=device_id', 'server'); cleanup.append(status == 200 and rows == [])
    cleanup_ok = all(cleanup) and bool(cleanup)
    checks.append({'check': 'scoped_fixture_and_object_cleanup', 'passed': cleanup_ok})
    Path(args.report).write_text(json.dumps({'scope': 'real ordinary A/B/C receiver safety with real synthetic media',
        'checks': checks, 'passed': sum(x['passed'] for x in checks), 'failed': sum(not x['passed'] for x in checks),
        'serviceKeyUsedForUserAssertions': False, 'serviceKeyUsedForScopedReportInspectionAndCleanup': True,
        'globalClaimAttempted': False, 'providerInvoked': False, 'completePhotoLoop': False}, indent=2) + '\n')
assert cleanup_ok, 'Scoped cleanup failed; values redacted'
print('Real A/B receiver safety and scoped cleanup passed; report has no credentials or image paths.')
