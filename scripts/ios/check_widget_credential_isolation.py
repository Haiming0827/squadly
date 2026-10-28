#!/usr/bin/env python3
"""Inspect built Mach-O code, including Xcode debug dylibs, not source intent."""
import plistlib
import subprocess
import sys
from pathlib import Path

app = Path(sys.argv[1])
extension = app / 'PlugIns' / 'SquadPhotoWidget.appex'
assert app.is_dir() and extension.is_dir(), 'Built app and photo extension required'
magic = {bytes.fromhex(x) for x in ['feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca']}

def symbols(path):
    result = subprocess.run(['nm', '-a', str(path)], capture_output=True, text=True, check=True)
    return result.stdout

with (app / 'Info.plist').open('rb') as stream:
    executable = plistlib.load(stream)['CFBundleExecutable']
main = [app / executable, app / (executable + '.debug.dylib')]
main_symbols = ''.join(symbols(path) for path in main if path.is_file())
assert 'BackgroundCredential' in main_symbols and '_SecItemAdd' in main_symbols, 'Main app credential implementation missing'
count = 0
for path in extension.rglob('*'):
    if not path.is_file():
        continue
    with path.open('rb') as stream:
        if stream.read(4) not in magic:
            continue
    count += 1
    value = symbols(path)
    assert 'BackgroundCredential' not in value, 'Credential code linked into extension'
    assert not any(name in value for name in ['_SecItemAdd', '_SecItemCopyMatching', '_SecItemDelete']), 'Keychain access linked into extension'
assert count, 'No extension Mach-O inspected'
print('Credential isolation passed: main app only; all', count, 'extension Mach-O files inspected (including debug dylibs).')
