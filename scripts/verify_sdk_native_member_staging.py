#!/usr/bin/env python3
"""Prepare/finish one ordinary A/C native renewal fixture; no global cleanup."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlencode, urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener
import uuid

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('phase', choices=['prepare', 'finish'])
parser.add_argument('--config', required=True)
parser.add_argument('--server-config', required=True)
parser.add_argument('--device', required=True)
parser.add_argument('--ledger', required=True)
parser.add_argument('--report', required=True)
parser.add_argument('--allow-test-writes', action='store_true')
parser.add_argument('--test-passed', action='store_true')
args = parser.parse_args()
assert args.allow_test_writes
assert str(uuid.UUID(args.device)).lower() == args.device.lower()


def private(path):
    p = Path(path)
    assert not p.is_symlink() and stat.S_IMODE(p.stat().st_mode) == 0o600
    return json.loads(p.read_text())


def write_private(path, value, create=False):
    p = Path(path)
    assert not p.is_symlink()
    if create:
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False)
    else:
        assert stat.S_IMODE(p.stat().st_mode) == 0o600
        temp = p.with_suffix('.tmp')
        write_private(temp, value, create=True)
        os.replace(temp, p)


c = private(args.config)
assert c['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c' and c['region'] == 'ap-shanghai'
base = 'https://' + c['environmentId'] + '.api.tcloudbasegateway.com'
gateway = c['photoAcceptance']['workerUrl']
u = urlparse(gateway)
assert u.scheme == 'https' and u.path == '/photos' and not u.query and not u.fragment and not u.username and u.port is None
assert u.hostname.startswith(c['environmentId'] + '-') and u.hostname.endswith('.ap-shanghai.app.tcloudbase.com')
app = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'com.squadly.squadly', 'data'], text=True).strip())
prefs = plistlib.loads((app / 'Library/Preferences/com.squadly.squadly.plist').read_bytes())
sdk = json.loads(prefs['flutter.credentials_' + c['environmentId']])
assert sdk['user']['id'] == c['actors']['a']['userId']
a = {**c['actors']['a'], 'jwt': sdk['access_token'], 'deviceId': prefs['flutter.device_id']}
# Do not inspect or rotate the main A SDK refresh token, or persist its access JWT.
actors = {'a': a, 'c': c['actors']['c']}
for alias, actor in actors.items():
    claim = json.loads(base64.urlsafe_b64decode(actor['jwt'].split('.')[1] + '==='))
    assert claim['sub'] == actor['userId'] and claim.get('role') in ('user', 'authenticated') and claim.get('is_system_admin') is not True
    if args.phase == 'prepare':
        assert claim['exp'] > time.time() + 300, 'Ordinary SDK session needs renewal before fixture setup; values redacted'

host = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'com.example.squadlyIntegrationTest', 'data'], text=True).strip()) / 'Documents'
source = host / 'sdk-session-staging-fixture.json'
output = host / 'sdk-session-staging-output.json'
ledger = Path(args.ledger)
report = Path(args.report)
server_key = None
operation = "bootstrap"
last_status = None


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *unused):
        return None


opener = build_opener(NoRedirect())


def http(path='', alias='a', body=None, method=None, media=False):
    global operation, last_status
    surface = 'photo:' + str(body.get('action')) if media else 'storage' if path.startswith('/v1/storages/') else urlparse(path).path.rsplit('/', 1)[-1]
    operation = surface + ':' + (method or ('POST' if body is not None else 'GET'))
    last_status = None
    assert alias in ('a', 'c', 'server')
    if alias == 'server':
        assert args.phase == 'finish' and server_key
        token = server_key
    else:
        token = actors[alias]['jwt']
    headers = {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}
    if alias in actors:
        headers['x-device-id'] = actors[alias]['deviceId']
    request = Request(gateway if media else base + path, headers=headers,
        data=None if body is None else json.dumps(body).encode(), method=method or ('POST' if body is not None else 'GET'))
    try:
        with opener.open(request, timeout=45) as response:
            last_status = response.status
            raw = response.read(3 * 1024 * 1024)
            return response.status, json.loads(raw) if raw else None
    except HTTPError as error:
        last_status = error.code
        return error.code, None


def rpc(name, body, alias='a'):
    return http('/v1/rdb/rest/rpc/' + name, alias, body)


def save():
    write_private(ledger, state)


def check(label, passed):
    state['checks'].append({'check': label, 'passed': bool(passed)})
    save()
    if not passed:
        raise RuntimeError('Check failed: ' + label + '; response redacted')
    print(label + ': pass', flush=True)


def ok(result, label):
    status, value = result
    check(label, status in (200, 201, 204) and not (isinstance(value, dict) and value.get('error')))
    return value


def pg(table, filters, alias='server', method='GET', body=None):
    return http('/v1/rdb/rest/' + table + '?' + urlencode(filters), alias, body, method)


def collect():
    stats = state.get('nativeMemberPhotoResult')
    if output.exists() and output.stat().st_size:
        value = private(output)
        claim = json.loads(base64.urlsafe_b64decode(value['accessToken'].split('.')[1] + '==='))
        assert claim['sub'] == actors['c']['userId'] and claim['exp'] > time.time() + 60
        stats = value.get('nativeMemberPhoto')
        bootstrap = value.get('productionProviderBootstrap', False)
        assert isinstance(bootstrap, bool)
        state['productionProviderBootstrap'] = bootstrap
        save()
        if stats is not None:
            assert set(stats) == {'passed', 'renewalAndFetchMilliseconds', 'duplicateDidNotRenew', 'readCursorUnchanged'}
            assert all(isinstance(stats[k], bool) for k in ['passed', 'duplicateDidNotRenew', 'readCursorUnchanged'])
            assert type(stats['renewalAndFetchMilliseconds']) is int and 0 <= stats['renewalAndFetchMilliseconds'] < 27000
            state['nativeMemberPhotoResult'] = stats
            save()
        subprocess.run(['python3', str(ROOT / 'scripts/prepare_sdk_session_staging.py'), '--config', args.config,
            '--device', args.device, '--allow-test-writes', '--collect'], check=True)
        check('rotated_c_collected', not source.exists() and not output.exists())
    else:
        # No SDK result was written. Keep the existing C credentials unchanged.
        for p in (source, output):
            if p.exists():
                assert not p.is_symlink() and stat.S_IMODE(p.stat().st_mode) == 0o600
                p.unlink()
    return stats


try:
    if args.phase == 'prepare':
        assert not ledger.exists() and not report.exists() and not source.exists() and not output.exists()
        state = {'name': '验收测试-SDK成员照片-' + uuid.uuid4().hex, 'squad': None, 'nonce': str(uuid.uuid4()),
            'message': None, 'media': None, 'objectKeys': [], 'checks': []}
        write_private(ledger, state, create=True)
        for alias in actors:
            user = ok(http('/auth/v1/user/me?' + urlencode({'client_id': c['environmentId']}), alias), alias + '_identity_http')
            user = user.get('data', user)
            check(alias + '_ordinary_identity', (user.get('sub') or user.get('uid')) == actors[alias]['userId'])
            profile = ok(pg('profiles', {'id': 'eq.' + actors[alias]['userId'], 'select': 'id'}, alias), alias + '_profile_http')
            check(alias + '_own_profile', profile == [{'id': actors[alias]['userId']}])
        team = ok(rpc('create_squad', {'p_name': state['name']}), 'create_fixture')
        assert team['created_by'] == a['userId']
        state['squad'] = str(uuid.UUID(team['id'])); save()
        invite = ok(rpc('issue_invitation', {'p_squad_id': state['squad']}), 'issue_c_invite')
        ok(rpc('redeem_invitation', {'p_credential': invite['code']}, 'c'), 'c_redeems_invite')
        members = ok(pg('squad_members', {'squad_id': 'eq.' + state['squad'], 'select': 'user_id'}, 'c'), 'c_members_http')
        check('exact_two_ordinary_members', len(members) == 2 and {v['user_id'] for v in members} == {a['userId'], actors['c']['userId']})
        data = (ROOT / 'test/features/photos/fixtures/sanitized.jpg').read_bytes()
        published = ok(http(alias='a', media=True, body={'action': 'publish', 'squad_id': state['squad'], 'client_nonce': state['nonce'],
            'source_sha256': hashlib.sha256(data).hexdigest(), 'bytes': base64.b64encode(data).decode()}), 'publish_synthetic')
        state['message'] = str(uuid.UUID(published['message_id'])); state['media'] = str(uuid.UUID(published['media_id'])); save()
        authority = ok(rpc('authorize_photo_read', {'p_squad_id': state['squad'], 'p_message_id': state['message']}), 'own_object_authority')
        key = authority['object_key']
        assert re.fullmatch(re.escape(state['media']) + r'/[0-9a-f-]{36}\.jpg', key)
        state['objectKeys'] = [key]; save()
        head = ok(rpc('get_squad_photo_head', {'p_squad_id': state['squad']}, 'c'), 'c_visible_head_http')
        check('c_visible_synthetic_photo', head['photo']['id'] == state['message'] and head['photo']['photo']['width'] == 4 and head['photo']['photo']['height'] == 3)
        cursors = ok(pg('conversation_read_cursors', {'squad_id': 'eq.' + state['squad'], 'select': 'read_message_id'}, 'c'), 'initial_read_cursor_http')
        check('no_initial_read_cursor', cursors == [])
        subprocess.run(['python3', str(ROOT / 'scripts/prepare_sdk_session_staging.py'), '--config', args.config,
            '--device', args.device, '--allow-test-writes'], check=True)
        fixture = private(source)
        fixture['nativeMemberPhoto'] = {'squadId': state['squad'], 'messageId': state['message']}
        write_private(source, fixture)
        print('Controlled A/C member-photo fixture ready; no credentials or object paths reported.')
    else:
        state = private(ledger)
        stats = collect()
        server = private(args.server_config)
        assert server['envId'] == c['environmentId']
        settings = next(f['envVariables'] for f in server['functions'] if f['name'] == 'photos')
        assert settings['CLOUDBASE_API_ORIGIN'] == base
        server_key = settings['CLOUDBASE_APIKEY']
        if state['squad'] is None:
            rows = ok(pg('squads', {'name': 'eq.' + state['name'], 'created_by': 'eq.' + a['userId'], 'select': 'id'}), 'recover_unique_fixture')
            assert len(rows) <= 1
            if rows:
                state['squad'] = str(uuid.UUID(rows[0]['id'])); save()
        squad = state['squad']
        if squad:
            media = ok(pg('photo_media', {'squad_id': 'eq.' + squad, 'client_nonce': 'eq.' + state['nonce'], 'select': 'id'}), 'scoped_media_lookup')
            assert len(media) <= 1
            media_ids = [str(uuid.UUID(v['id'])) for v in media]
            if media_ids:
                attempts = ok(pg('photo_upload_attempts', {'media_id': 'in.(' + ','.join(media_ids) + ')', 'select': 'media_id,object_key'}), 'scoped_attempt_lookup')
                for value in attempts:
                    assert value['media_id'] in media_ids and re.fullmatch(re.escape(value['media_id']) + r'/[0-9a-f-]{36}\.jpg', value['object_key'])
                    if value['object_key'] not in state['objectKeys']:
                        state['objectKeys'].append(value['object_key']); save()
            if state['message']:
                # A prior clear-cycle PATCH can commit even if its HTTP reply is
                # lost. Do not revoke again after clearing active_attempt_id:
                # revoked media intentionally requires that reference. Resume
                # only from a durably confirmed ordinary-author revocation.
                confirmed = state.get('authorRevoked', False) or any(
                    x['check'] == 'author_revoke' and x['passed'] for x in state['checks'])
                if not confirmed:
                    status, _ = http(alias='a', media=True, body={'action': 'revoke', 'squad_id': squad, 'message_id': state['message']})
                    check('author_revoke', status in (200, 404))
                else:
                    check('author_revoke_already_confirmed', True)
                state['authorRevoked'] = True
                save()
            for key in state['objectKeys']:
                check('delete_scoped_object', http('/v1/storages/object/squadly-photos', 'server', {'prefixes': [key]}, 'DELETE')[0] == 200)
                check('object_absent', http('/v1/storages/object/squadly-photos/' + key, 'server')[0] == 404)
            ok(pg('photo_media', {'squad_id': 'eq.' + squad}, method='PATCH', body={'state': 'preparing', 'active_attempt_id': None, 'revoked_at': None}), 'clear_fixture_media_cycle')
            for table in ['squad_messages', 'photo_upload_attempts', 'photo_media', 'squads', 'photo_sync_deliveries']:
                field = 'id' if table == 'squads' else 'media_id' if table == 'photo_upload_attempts' else 'squad_id'
                if field == 'media_id' and not media_ids:
                    continue
                query = 'in.(' + ','.join(media_ids) + ')' if field == 'media_id' else 'eq.' + squad
                ok(pg(table, {field: query}, method='DELETE'), 'delete_fixture_' + table)
            for table in ['squads', 'squad_messages', 'photo_media', 'photo_sync_deliveries']:
                field = 'id' if table == 'squads' else 'squad_id'
                check(table + '_absent', ok(pg(table, {field: 'eq.' + squad, 'select': field}), 'verify_' + table) == [])
        verified = bool(args.test_passed and stats and stats['passed'] and stats['duplicateDidNotRenew'] and stats['readCursorUnchanged'])
        result = {'date': '2026-10-31', 'scope': 'ordinary C actual SDK rotation to native member media',
            'testPassed': verified, 'nativeMemberPhoto': stats, 'cleanupCompleted': True,
            'productionProviderBootstrap': state.get('productionProviderBootstrap', False), 'checks': state['checks'],
            'controlledFailures': state.get('controlledFailures', []),
            'serviceKeyUsedForUserAssertions': False, 'serviceKeyUsedForScopedCleanup': True,
            'pushProviderInvoked': False, 'globalClaimAttempted': False, 'completePhotoLoop': False}
        report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        ledger.unlink()
        print('Scoped member-photo fixture cleaned; sanitized report saved.')
        if args.test_passed and not verified:
            raise SystemExit('A process exit or skipped test is insufficient without the native SDK result; details redacted.')
except Exception as error:
    failure = {'operation': operation, 'class': type(error).__name__, 'causeClass': type(error.__cause__).__name__ if error.__cause__ else None, 'httpStatus': last_status}
    if 'state' in globals() and ledger.exists():
        state.setdefault('controlledFailures', []).append(failure)
        save()
    print('Controlled failure: ' + json.dumps(failure), flush=True)
    print('Member-photo staging phase failed; response and credentials redacted. Retain private ledger and finish scoped cleanup.', flush=True)
    raise SystemExit(1)
