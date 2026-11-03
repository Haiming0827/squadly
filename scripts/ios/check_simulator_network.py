#!/usr/bin/env python3
"""Read-only URLSession probes executed within booted acceptance simulators."""
import argparse
import json
import platform
import re
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--device', choices=['a', 'b', 'all'], default='all')
parser.add_argument('--config', type=Path, required=True, help='Public client dart-define file, never server deployment config')
parser.add_argument('--report', type=Path)
args = parser.parse_args()
assert platform.system() == 'Darwin', 'Requires macOS/Xcode'
raw = args.config.read_text()
try:
    config = json.loads(raw)
except json.JSONDecodeError:
    config = {}
    for line in raw.splitlines():
        if line.strip() and not line.lstrip().startswith('#') and '=' in line:
            key, value = line.split('=', 1)
            config[key.strip()] = value.strip().strip('\"\'')
environment = config.get('CLOUDBASE_ENV_ID', '')
gateway = config.get('CLOUDBASE_PHOTO_GATEWAY_URL', '')
assert re.fullmatch(r'[a-zA-Z0-9-]+', environment), 'Missing public environment ID'
url = urlparse(gateway)
assert (url.scheme == 'https' and url.path == '/photos' and not url.query and not url.fragment
        and not url.username and url.port in (None, 443) and url.hostname.startswith(environment + '-')
        and url.hostname.endswith('.ap-shanghai.app.tcloudbase.com')), 'Invalid public photos URL'
targets = {'a': '370493B7-843A-47ED-AE82-7CB75E21691E', 'b': 'DA33717A-0E70-4727-8623-A22CED1A5432'}
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))
states = {device['udid']: device['state'] for group in devices['devices'].values() for device in group}
records = []
passed = True
with tempfile.TemporaryDirectory(prefix='squadly-network-') as directory:
    binary = str(Path(directory) / 'network-probe')
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    architecture = 'arm64' if platform.machine() == 'arm64' else 'x86_64'
    subprocess.run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-target', architecture + '-apple-ios15.0-simulator',
                    '-sdk', sdk, str(Path(__file__).with_name('simulator_network_probe.swift')), '-o', binary], check=True)
    for alias, device in targets.items():
        if args.device not in ('all', alias):
            continue
        assert states.get(device) == 'Booted', 'Open the requested acceptance simulator first'
        probe = subprocess.run(['xcrun', 'simctl', 'spawn', device, binary,
            'https://www.apple.com/library/test/success.html',
            'https://' + environment + '.api.tcloudbasegateway.com/auth/v1/user/me?client_id=' + environment,
            gateway], capture_output=True, text=True, timeout=80)
        checks = [json.loads(line) for line in probe.stdout.splitlines() if line.startswith('{')]
        result = {'device': alias, 'checks': checks, 'passed': probe.returncode == 0 and len(checks) == 3 and all(c.get('passed') for c in checks)}
        records.append(result)
        passed = passed and result['passed']
        print(json.dumps(result), flush=True)
report = {'kind': 'actual-iOS-simulator-URLSession', 'noCredentialsUsed': True, 'passed': passed, 'devices': records}
if args.report:
    assert not args.report.exists(), 'Choose a new report path'
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if passed else 1)
