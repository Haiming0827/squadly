#!/usr/bin/env python3
"""Provision a synthetic >100KB JPEG and an existing ordinary access snapshot."""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import random
import stat
import subprocess
import time
import uuid
from urllib.parse import urlparse
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--config', type=Path, required=True)
parser.add_argument('--device', required=True, help='Independent integration host simulator ID')
parser.add_argument('--sdk-device', default='DA33717A-0E70-4727-8623-A22CED1A5432')
parser.add_argument('--ledger', type=Path, required=True)
parser.add_argument('--allow-test-writes', action='store_true')
args = parser.parse_args()
assert args.allow_test_writes, 'Explicit synthetic test write authorization required'
assert not args.config.is_symlink() and stat.S_IMODE(args.config.stat().st_mode) == 0o600
assert not args.ledger.exists(), 'Choose a new private test ledger'
c = json.loads(args.config.read_text())
assert c['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c' and c['region'] == 'ap-shanghai'
assert args.sdk_device == 'DA33717A-0E70-4727-8623-A22CED1A5432', 'This fixture expects the existing B acceptance account'
root = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.sdk_device, 'com.squadly.squadly', 'data'], text=True).strip())
prefs = plistlib.loads((root / 'Library/Preferences/com.squadly.squadly.plist').read_bytes())
session = json.loads(prefs['flutter.credentials_' + c['environmentId']])
token = session['access_token']
claims = json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '==='))
assert claims['sub'] == c['actors']['b']['userId'] == session['user']['id']
assert claims.get('role') in ('user', 'authenticated') and claims.get('is_system_admin') is not True
assert claims['exp'] > time.time() + 300, 'Restore the existing B SDK session in the acceptance App first'
image = Image.frombytes('RGB', (1600, 1200), random.Random(711).randbytes(1600 * 1200 * 3))
stream = io.BytesIO()
image.save(stream, format='JPEG', quality=85)
content = stream.getvalue()
assert 100 * 1024 < len(content) <= 2 * 1024 * 1024
f = c['photoAcceptance']
gateway = urlparse(f['workerUrl'])
assert (gateway.scheme == 'https' and gateway.path == '/photos' and not gateway.query and not gateway.fragment
        and not gateway.username and gateway.port is None and gateway.hostname.startswith(c['environmentId'] + '-')
        and gateway.hostname.endswith('.ap-shanghai.app.tcloudbase.com')), 'Unexpected staging media destination'
nonce = str(uuid.uuid4())
fixture = {'environmentId': c['environmentId'], 'userId': claims['sub'], 'accessToken': token,
    'gateway': f['workerUrl'], 'squadId': f['squad'], 'parentMessageId': f['widgetFixtureMessage'],
    'nonce': nonce, 'bytes': base64.b64encode(content).decode(), 'sha256': hashlib.sha256(content).hexdigest()}
host = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'com.example.squadlyIntegrationTest', 'data'], text=True).strip())
target = host / 'Documents/photo-upload-transport-fixture.json'
assert not target.exists()
ledger = {'environmentId': c['environmentId'], 'actor': 'b', 'squadId': f['squad'], 'nonce': nonce, 'inputBytes': len(content)}
for path, data in [(args.ledger, ledger), (target, fixture)]:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as file:
        json.dump(data, file)
print('Synthetic 1600x1200 JPEG and ordinary access snapshot provisioned at mode 0600; no refresh token copied or rotated.')
