#!/usr/bin/env python3
"""Provision only a short JWT in an isolated simulator container, never build flags."""
import argparse
import base64
import json
import os
import plistlib
from pathlib import Path
import re
import stat
import subprocess
import time
import uuid
from urllib.parse import urlencode, urlparse
from urllib.request import Request, build_opener, HTTPRedirectHandler

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--device', required=True)
parser.add_argument('--actor', choices=['a', 'b', 'c'], default='a')
parser.add_argument('--expect-member-denied', action='store_true')
parser.add_argument('--read-sdk-session', action='store_true')
parser.add_argument('--sdk-device')
parser.add_argument('--allow-test-writes', action='store_true')
args = parser.parse_args()
assert args.allow_test_writes, 'Explicit local fixture writes required'
path = Path(args.config)
assert not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == 0o600
c = json.loads(path.read_text())
assert c['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c' and c['region'] == 'ap-shanghai'
actor = c['actors'][args.actor]
if args.read_sdk_session:
    assert args.actor in ('a', 'b'), 'Only existing acceptance app accounts have SDK sessions'
    source_device = args.sdk_device or args.device
    assert re.fullmatch(r'[0-9A-Fa-f-]{36}', source_device)
    app = Path(subprocess.check_output(['xcrun','simctl','get_app_container',source_device,'com.squadly.squadly','data'],text=True).strip())
    preferences = plistlib.loads((app / 'Library/Preferences/com.squadly.squadly.plist').read_bytes())
    session = json.loads(preferences['flutter.credentials_' + c['environmentId']])
    assert session['user']['id'] == actor['userId']
    actor = {**actor, 'jwt': session['access_token'], 'deviceId': preferences['flutter.device_id']}
claims = json.loads(base64.urlsafe_b64decode(actor['jwt'].split('.')[1] + '==='))
assert claims['sub'] == actor['userId'] and claims.get('role') in ('user', 'authenticated') and claims.get('is_system_admin') is not True
assert claims['exp'] > time.time() + 300, 'Obtain a fresh ordinary SDK session first'
assert re.fullmatch(r'[0-9A-Fa-f-]{36}', args.device)

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None

opener = build_opener(NoRedirect())
base = 'https://' + c['environmentId'] + '.api.tcloudbasegateway.com'

def api(route, body=None):
    request = Request(base + route, data=None if body is None else json.dumps(body).encode(),
        headers={'Authorization': 'Bearer ' + actor['jwt'], 'Content-Type': 'application/json', 'x-device-id': actor['deviceId']})
    with opener.open(request, timeout=25) as response:
        assert response.status == 200
        return json.loads(response.read(65536))

identity = api('/auth/v1/user/me?client_id=' + c['environmentId'])
identity = identity.get('data', identity)
assert (identity.get('sub') or identity.get('uid')) == actor['userId']
own = api('/v1/rdb/rest/profiles?' + urlencode({'id': 'eq.' + actor['userId'], 'select': 'id'}))
assert len(own) == 1 and own[0]['id'] == actor['userId']
f = c['photoAcceptance']
head = api('/v1/rdb/rest/rpc/get_squad_photo_head', {'p_squad_id': f['squad']})
if args.expect_member_denied:
    assert args.actor == 'c' and head is None
else:
    assert args.actor in ('a', 'b') and head['photo']['id'] == f['widgetFixtureMessage']
    photo = head['photo']
    assert photo['sender_id'] == c['actors']['a']['userId'] and photo['photo']['width'] == 4 and photo['photo']['height'] == 3 and photo['photo']['revoked'] is False
gateway = urlparse(f['workerUrl'])
assert gateway.scheme == 'https' and gateway.hostname.startswith(c['environmentId'] + '-') and gateway.hostname.endswith('.ap-shanghai.app.tcloudbase.com')
assert gateway.path == '/photos' and not gateway.query and not gateway.fragment and not gateway.username and gateway.port is None
root = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'com.example.squadlyIntegrationTest', 'data'], text=True).strip())
target = root / 'Documents/native-photo-fetch-fixture.json'
target.parent.mkdir(exist_ok=True)
fixture = {'fixtureId': uuid.uuid4().hex, 'environmentId': c['environmentId'], 'userId': actor['userId'], 'accessToken': actor['jwt'],
    'squadId': f['squad'], 'messageId': f['widgetFixtureMessage'], 'gateway': f['workerUrl'], 'expectMemberDenied': args.expect_member_denied}
descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(descriptor, 'w') as stream: json.dump(fixture, stream)
print('Private simulator fixture provisioned after real identity/profile and member access controls; no token in build flags.')
