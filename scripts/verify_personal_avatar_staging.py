#!/usr/bin/env python3
"""Check existing profile owner RLS with ordinary A/B SDK access snapshots.

The owner's original avatar is restored in finally and a private recovery file
is removed only after verifying restoration. No refresh tokens are read/rotated.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPRedirectHandler

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--report', required=True)
parser.add_argument('--backup', required=True)
parser.add_argument('--allow-test-writes', action='store_true')
args = parser.parse_args()
assert args.allow_test_writes and not Path(args.report).exists() and not Path(args.backup).exists()
config_path = Path(args.config)
assert stat.S_IMODE(config_path.stat().st_mode) == 0o600 and not config_path.is_symlink()
config = json.loads(config_path.read_text())
assert config['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c' and config['region'] == 'ap-shanghai'
base = 'https://' + config['environmentId'] + '.api.tcloudbasegateway.com/v1/rdb/rest/'
actors = {}
for alias, device in [('a', '370493B7-843A-47ED-AE82-7CB75E21691E'), ('b', 'DA33717A-0E70-4727-8623-A22CED1A5432')]:
    root = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, 'com.squadly.squadly', 'data'], text=True).strip())
    prefs = plistlib.loads((root / 'Library/Preferences/com.squadly.squadly.plist').read_bytes())
    sdk = json.loads(prefs['flutter.credentials_' + config['environmentId']])
    token = sdk['access_token']
    claim = json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '==='))
    assert sdk['user']['id'] == config['actors'][alias]['userId'] == claim['sub']
    assert claim.get('role') in ('user', 'authenticated') and claim.get('is_system_admin') is not True
    assert claim['exp'] > time.time() + 300, 'Reopen actual Apps to renew SDK sessions; values redacted'
    actors[alias] = {'id': claim['sub'], 'token': token}

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *unused):
        return None

opener = build_opener(NoRedirect())
checks = []

def check(label, condition):
    checks.append({'check': label, 'passed': bool(condition)})
    if not condition:
        raise RuntimeError('Profile check failed: ' + label + '; response redacted')
    print(label + ': pass', flush=True)

def request(actor, owner, avatar=None, write=False):
    query = urlencode({'id': 'eq.' + owner, 'select': 'id,nickname,avatar_url'})
    token = config['publishableKey'] if actor == 'anonymous' else actors[actor]['token']
    req = Request(base + 'profiles?' + query, method='PATCH' if write else 'GET', headers={
        'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json', 'Prefer': 'return=representation',
    }, data=json.dumps({'avatar_url': avatar}).encode() if write else None)
    try:
        with opener.open(req, timeout=35) as response:
            return response.status, json.loads(response.read())
    except HTTPError as error:
        return error.code, None

def own_profile():
    code, rows = request('a', actors['a']['id'])
    check('own_profile_read', code == 200 and isinstance(rows, list) and len(rows) == 1)
    return rows[0]

original = own_profile()
backup = Path(args.backup)
fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as file:
    json.dump({'environmentId': config['environmentId'], 'userId': actors['a']['id'], 'avatar': original['avatar_url']}, file)
error_label = None
try:
    avatar = 'data:image/png;base64,' + base64.b64encode(Path('test/features/squad/fixtures/avatar.png').read_bytes()).decode()
    code, rows = request('a', actors['a']['id'], avatar, write=True)
    check('owner_avatar_write', code == 200 and len(rows) == 1 and rows[0]['avatar_url'] == avatar)
    check('nickname_preserved', rows[0]['nickname'] == original['nickname'])
    code, rows = request('b', actors['a']['id'])
    check('teammate_reads_shared_avatar', code == 200 and len(rows) == 1 and rows[0]['avatar_url'] == avatar)
    code, rows = request('b', actors['a']['id'], None, write=True)
    check('teammate_cannot_write_owner_profile', (code == 200 and rows == []) or code in (401, 403))
    check('owner_avatar_unchanged_after_peer_attempt', own_profile()['avatar_url'] == avatar)
    code, _ = request('anonymous', actors['a']['id'], None, write=True)
    check('anonymous_write_denied', code in (401, 403))
finally:
    code, rows = request('a', actors['a']['id'], original['avatar_url'], write=True)
    check('original_avatar_restore_write', code == 200 and len(rows) == 1)
    restored = own_profile()
    check('original_profile_restored', restored['avatar_url'] == original['avatar_url'] and restored['nickname'] == original['nickname'])
    backup.unlink()

report = {'date': '2026-11-03', 'scope': 'ordinary A/B existing profiles owner RLS', 'passed': all(c['passed'] for c in checks), 'checks': checks,
          'originalAvatarRestored': True, 'notVerified': ['physical-device avatar picker', 'Android native picker']}
Path(args.report).parent.mkdir(parents=True, exist_ok=True)
Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
