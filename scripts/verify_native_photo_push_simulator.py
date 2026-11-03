#!/usr/bin/env python3
"""Inject a content-free hint and assert native cache mutation, never widget paint."""
import argparse
import json
from pathlib import Path
import plistlib
import stat
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--config', required=True)
parser.add_argument('--report', required=True)
parser.add_argument('--register-probe', action='store_true')
parser.add_argument('--expect-member-denied', action='store_true')
args = parser.parse_args()
config = Path(args.config)
assert not config.is_symlink() and stat.S_IMODE(config.stat().st_mode) == 0o600
c = json.loads(config.read_text())
assert c['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c'
output = Path(args.report)
assert not output.exists(), 'Choose a new report path'
host = 'com.example.squadlyIntegrationTest'

def sim(*values):
    return subprocess.check_output(['xcrun', 'simctl', *values], text=True).strip()

raw = sim('get_app_container', args.device, host, 'groups')
try: groups = json.loads(raw)
except json.JSONDecodeError: groups = dict(line.split('\t', 1) for line in raw.splitlines() if '\t' in line)
manifest = Path(groups['group.com.example.squadlyIntegrationTest.widgets']) / 'photo-widget-v1.json'
before = json.loads(manifest.read_text())
assert before.get('binding', {}).get('previewEnabled')
assert bool(before.get('photo')) == args.expect_member_denied, 'Seed empty positive cache or a synthetic old negative cache first'
assert before['session']['expiresAt'] + 978307200 > time.time() + 90
app = Path(sim('get_app_container', args.device, host, 'app'))
with (app / 'Info.plist').open('rb') as stream: info = plistlib.load(stream)
assert 'remote-notification' in info.get('UIBackgroundModes', [])
data = Path(sim('get_app_container', args.device, host, 'data'))
pending = data / 'Documents/native-photo-fetch-fixture.json'
pending_id = json.loads(pending.read_text()).get('fixtureId') if pending.exists() else None
launch = ['launch', '--terminate-running-process', args.device, host]
if args.register_probe: launch.append('--native-photo-push-probe')
sim(*launch)
if pending_id:
    ready = data / 'Documents/native-photo-fetch-ready.json'
    wait = time.monotonic() + 20
    while time.monotonic() < wait:
        if ready.exists() and json.loads(ready.read_text()).get('fixtureId') == pending_id: break
        time.sleep(0.2)
    else: raise RuntimeError('Signed host did not complete private credential setup')
preferences_file = data / 'Library/Preferences' / (host + '.plist')
def probe():
    if not preferences_file.exists(): return {}
    with preferences_file.open('rb') as stream: values = plistlib.load(stream)
    return {key: values['native_photo_push_probe_' + key] for key in
        ['authorized', 'registered', 'received', 'result', 'app_state', 'refresh', 'protected_data', 'registration_error', 'backgrounded']
        if 'native_photo_push_probe_' + key in values}
if args.register_probe:
    wait = time.monotonic() + 5
    while time.monotonic() < wait and 'registered' not in probe(): time.sleep(0.2)
sim('launch', '--terminate-running-process', args.device, 'com.squadly.squadly')
payload = Path(__file__).resolve().parents[1] / 'integration_test/fixtures/photo-sync.apns'
sim('push', args.device, host, str(payload))
start = time.monotonic()
expected = c['photoAcceptance']['widgetFixtureMessage']
matched = False
last = before
while time.monotonic() - start < 35:
    last = json.loads(manifest.read_text())
    photo = last.get('photo') or {}
    positive = photo.get('messageID') == expected and photo.get('jpeg') and photo.get('expiresAt', 0) + 978307200 > time.time()
    denied = not photo and last.get('failure') is True and last.get('session', {}).get('generation') != before['session']['generation']
    if (denied if args.expect_member_denied else positive):
        matched = True
        break
    time.sleep(0.5)
report = {'scope': 'simulator-injected-notification-native-staging-fetch', 'passed': matched,
    'nativeCacheUpdatedAfterInjection': matched, 'hostLaunchedBeforeBackgrounding': True,
    'registerProbe': args.register_probe, 'observationSeconds': round(time.monotonic() - start, 2),
    'expectedMemberDenied': args.expect_member_denied,
    'nativeHostProbe': probe() if args.register_probe else {},
    'finalState': {'photoPresent': bool(last.get('photo')), 'failure': last.get('failure'),
        'headRevision': (last.get('head') or {}).get('revision')},
    'notVerified': ['APNs_provider_delivery', 'physical_device_background', 'actual_desktop_paint', 'cold_engine_launch'],
    'completePhotoLoop': False}
output.write_text(json.dumps(report, indent=2) + '\n')
print('Simulator-injected native photo cache update:', 'pass' if matched else 'FAIL')
if not matched: raise SystemExit(1)
