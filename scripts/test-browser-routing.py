#!/usr/bin/env python3
"""Static regression checks for the browser routing contract (no installs/network)."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
skill = (root / 'SKILL.md').read_text(encoding='utf-8')
channels = (root / 'channels.yaml').read_text(encoding='utf-8')
onboarding = (root / 'ONBOARDING.md').read_text(encoding='utf-8')

for text in (skill, channels, onboarding):
    for anchor in ('Ego Browser', 'ego-browser', 'ego-browser skill',
                   'references/install.md', '默认 Chrome'):
        assert anchor in text, f'Missing browser contract anchor: {anchor}'

assert '## 浏览器统一规则：必须使用 Ego Browser' in skill
assert '缺失则先安装 Skill' in skill
assert '已安装可用时不重复安装' in skill
assert '[ego-browser:skill] end of guide' in skill
assert '子 Agent 委派任务也必须携带该约束' in skill
assert 'doctor.sh' in skill and '未探测这些状态' in skill
assert '浏览器 (chrome-devtools/内置)' not in skill
assert not re.search(r'^  kimi-webbridge:', channels, re.M)
assert re.search(r'^  ego-browser:', channels, re.M)
assert '不自动复制或迁移 Cookie' in skill
assert '缺失与受限分开报告' in skill

# Every ordinary browser action in the main instructions names Ego Browser.
# The policy section explicitly discusses forbidden alternatives and is excluded.
actions = skill.split('## 用户路径（首次使用）', 1)[1]
for line in actions.splitlines():
    if '浏览器' in line:
        assert 'Ego Browser' in line or '`ego-browser`' in line, f'Unqualified browser route: {line}'

print('Ego Browser routing contract: all checks passed.')
