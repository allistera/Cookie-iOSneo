#!/bin/bash
# Warm the same pinned destination used by the Cookie test plan before Xcode launches its runners.
set -euo pipefail
python3 - <<'PY'
import json
import subprocess

inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
matches = [
    device for device in inventory['devices'].get('com.apple.CoreSimulator.SimRuntime.iOS-27-0', [])
    if device['name'] == 'iPhone 18 Pro' and device['isAvailable']
]
if len(matches) != 1:
    raise SystemExit('Expected one available iPhone 18 Pro on iOS 27.0')
device = matches[0]
if device['state'] != 'Booted':
    subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=True)
subprocess.run(['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'], check=True)
print('Pinned test simulator is booted and ready')
PY
