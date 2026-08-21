#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass() { printf '✅ %s\n' "$1"; }

bash -n install.sh
pass "install.sh syntax"

bash -n doctor.sh
pass "doctor.sh syntax"

bash -n install-museon.sh
pass "install-museon.sh syntax"

bash -n install-agent-reach.sh
pass "install-agent-reach.sh syntax"

# Text-mode doctor must survive UTF-8 locales (regression for $VAR touching CJK).
bash doctor.sh >/tmp/web-search-routing-doctor.txt
pass "bash doctor.sh text mode"

if locale -a 2>/dev/null | grep -qi '^C\.UTF-*8$'; then
  LANG=C.UTF-8 LC_ALL=C.UTF-8 bash doctor.sh >/tmp/web-search-routing-doctor-c-utf8.txt
  pass "LANG=C.UTF-8 bash doctor.sh text mode"
else
  pass "skip LANG=C.UTF-8 doctor.sh (locale unavailable)"
fi

python3 - <<'PY'
import pathlib
import re

root = pathlib.Path('.')
expected = '3.2.0'
checks = {
    'SKILL.md': [r'(?m)^\s*version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?'],
    'channels.yaml': [r'(?m)^version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?'],
    'README.md': [r'version-([0-9]+\.[0-9]+\.[0-9]+)'],
    'INSTALL.md': [r'安装指南（v([0-9]+\.[0-9]+\.[0-9]+)）'],
}
for name, patterns in checks.items():
    text = (root / name).read_text(encoding='utf-8')
    versions = []
    for pattern in patterns:
        versions.extend(re.findall(pattern, text))
    if not versions:
        raise SystemExit(f'{name}: missing skill version anchor')
    bad = [v for v in set(versions) if v != expected]
    if bad:
        raise SystemExit(f'{name}: expected {expected}, found {sorted(set(versions))}')
    print(f'✅ {name} version == {expected}')

# INSTALL/README may mention third-party versions, but the skill-version check must not match them.
install = (root / 'INSTALL.md').read_text(encoding='utf-8')
readme = (root / 'README.md').read_text(encoding='utf-8')
for name, text in [('INSTALL.md', install), ('README.md', readme)]:
    for bad in re.findall(r'安装指南（v([0-9]+\.[0-9]+\.[0-9]+)）', text):
        if bad != expected:
            raise SystemExit(f'{name}: stale install guide version {bad}')
PY
pass "version consistency anchored to this skill only"

if python3 - <<'PY'
try:
    import yaml
except Exception:
    raise SystemExit(1)
with open('channels.yaml', encoding='utf-8') as f:
    data = yaml.safe_load(f)
assert data['version'] == '3.2.0'
assert 'channels' in data
PY
then
  pass "channels.yaml parses with PyYAML"
elif command -v ruby >/dev/null 2>&1 && ruby -e 'require "yaml"; data=YAML.load_file("channels.yaml"); raise unless data["version"] == "3.2.0" && data.key?("channels")'; then
  pass "channels.yaml parses with ruby YAML"
else
  grep -Eq '^version: "3.2.0"$' channels.yaml
  grep -Eq '^channels:' channels.yaml
  grep -Eq '^priority_default:' channels.yaml
  pass "channels.yaml minimal structural checks (PyYAML/ruby YAML unavailable)"
fi

bash doctor.sh --json | python3 -m json.tool >/tmp/web-search-routing-doctor.json
pass "doctor.sh --json is valid JSON"

python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(['bash', 'doctor.sh', '--json'], text=True)
data = json.loads(raw)
assert data['schema_version'] == 1
assert data['skill_version'] == '3.2.0'
assert data['status'] in {'required_missing', 'optional_missing', 'warnings', 'w3_ready', 'ok'}
assert set(data['missing']) == set(data['required_missing']) | set(data['optional_missing'])
# Optional API channels must not turn the overall status into required_missing/ok=false.
if data['required_missing']:
    assert data['ok'] is False
else:
    assert data['ok'] is True
print('✅ doctor.sh --json status semantics')
PY

echo "All tests passed."
