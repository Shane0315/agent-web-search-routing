#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass() { printf '✅ %s\n' "$1"; }
section() { printf '\n== %s ==\n' "$1"; }

section "shell syntax"
bash -n install.sh
pass "install.sh syntax"
bash -n doctor.sh
pass "doctor.sh syntax"
bash -n install-museon.sh
pass "install-museon.sh syntax"
bash -n install-agent-reach.sh
pass "install-agent-reach.sh syntax"

section "doctor text mode"
bash doctor.sh >/tmp/web-search-routing-doctor.txt
pass "bash doctor.sh text mode"

if locale -a 2>/dev/null | grep -qi '^C\.UTF-*8$'; then
  LANG=C.UTF-8 LC_ALL=C.UTF-8 bash doctor.sh >/tmp/web-search-routing-doctor-c-utf8.txt
  pass "LANG=C.UTF-8 bash doctor.sh text mode"
else
  pass "skip LANG=C.UTF-8 doctor.sh (locale unavailable)"
fi

section "version consistency"
python3 - <<'PY'
import pathlib
import re

root = pathlib.Path('.')
expected = '3.2.1'
checks = {
    'SKILL.md': [r'(?m)^\s*version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?'],
    'channels.yaml': [r'(?m)^version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?'],
    'README.md': [r'version-([0-9]+\.[0-9]+\.[0-9]+)'],
    'INSTALL.md': [r'安装指南（v([0-9]+\.[0-9]+\.[0-9]+)）'],
    'doctor.sh': [r'EXPECTED_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"'],
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
PY
pass "version consistency anchored to this skill only"

section "channels.yaml"
if python3 - <<'PY'
try:
    import yaml
except Exception:
    raise SystemExit(1)
with open('channels.yaml', encoding='utf-8') as f:
    data = yaml.safe_load(f)
assert data['version'] == '3.2.1'
assert 'channels' in data
assert 'museon' in data['channels']
assert data['channels']['museon']['required'] is True
PY
then
  pass "channels.yaml parses with PyYAML"
elif command -v ruby >/dev/null 2>&1 && ruby -e 'require "yaml"; data=YAML.load_file("channels.yaml"); raise unless data["version"] == "3.2.1" && data.key?("channels") && data["channels"].key?("museon")'; then
  pass "channels.yaml parses with ruby YAML"
else
  grep -Eq '^version: "3.2.1"$' channels.yaml
  grep -Eq '^channels:' channels.yaml
  grep -Eq '^priority_default:' channels.yaml
  grep -Eq 'museon:' channels.yaml
  pass "channels.yaml minimal structural checks (PyYAML/ruby YAML unavailable)"
fi

section "doctor JSON"
bash doctor.sh --json | python3 -m json.tool >/tmp/web-search-routing-doctor.json
pass "doctor.sh --json is valid JSON"

python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(['bash', 'doctor.sh', '--json'], text=True)
data = json.loads(raw)
assert data['schema_version'] == 1
assert data['skill_version'] == '3.2.1'
assert data['status'] in {'required_missing', 'optional_missing', 'warnings', 'w3_ready', 'ok'}
assert set(data['missing']) == set(data['required_missing']) | set(data['optional_missing'])
if data['required_missing']:
    assert data['ok'] is False
else:
    assert data['ok'] is True
print('✅ doctor.sh --json status semantics')
PY

section "fake-home zero-channel experience"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
FAKE_JSON="$TEST_HOME/doctor.json"
HOME="$TEST_HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash doctor.sh >"$TEST_HOME/doctor.txt"
HOME="$TEST_HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash doctor.sh --json >"$FAKE_JSON"
python3 - "$FAKE_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
assert data['status'] == 'required_missing'
assert data['ok'] is False
assert 'museoncli' in data['required_missing']
assert 'agent-reach' in data['optional_missing']
assert data['museon']['installed'] is False
assert data['agent_reach']['installed'] is False
print('✅ fake-home zero-channel doctor semantics')
PY

section "install packaging"
INSTALL_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME" "$INSTALL_HOME"' EXIT
HOME="$INSTALL_HOME" CODEX_HOME="$INSTALL_HOME/.codex" bash install.sh >/tmp/web-search-routing-install.txt
DEST="$INSTALL_HOME/.codex/skills/agent-web-search-routing"
for required in \
  SKILL.md ONBOARDING.md INSTALL.md README.md LICENSE channels.yaml doctor.sh install.sh \
  install-museon.sh install-agent-reach.sh scripts/test.sh docs/new-user-dogfooding.md; do
  test -e "$DEST/$required" || { echo "missing installed file: $required"; exit 1; }
done
bash -n "$DEST/install.sh" "$DEST/doctor.sh" "$DEST/install-museon.sh" "$DEST/install-agent-reach.sh" "$DEST/scripts/test.sh"
pass "install.sh copies required runtime files and shell scripts remain parseable"

section "documentation anchors"
grep -q 'docs/doctor-json.md' README.md
grep -q 'doctor JSON' ONBOARDING.md
grep -q '自动安装' SKILL.md
pass "documentation links and onboarding anchors present"

echo
echo "All tests passed."
