#!/usr/bin/env bash
# ============================================================
# web-search-routing 环境体检脚本
# 用法：
#   bash doctor.sh
#   bash doctor.sh --json
# ============================================================
set -euo pipefail

JSON=0
if [ "${1:-}" = "--json" ]; then
  JSON=1
elif [ "$#" -gt 0 ]; then
  echo "用法：bash doctor.sh [--json]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="agent-web-search-routing"
SKILL_NAME="web-search-routing"
EXPECTED_VERSION="3.2.0"

execute_capture() {
  local output
  if output=$("$@" 2>&1); then
    printf '%s' "$output"
    return 0
  fi
  return 1
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

to_bool() {
  if [ "$1" = "1" ]; then printf 'true'; else printf 'false'; fi
}

join_json_array() {
  local first=1
  printf '['
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    if [ "$first" = "0" ]; then printf ','; fi
    printf '%s' "$item"
    first=0
  done
  printf ']'
}

json_str_array() {
  local first=1
  printf '['
  local item
  for item in "$@"; do
    [ -n "$item" ] || continue
    if [ "$first" = "0" ]; then printf ','; fi
    printf '%s' "$item" | json_escape
    first=0
  done
  printf ']'
}

path_entries_json() {
  local label="$1"
  shift
  local first=1
  local output='{"label":'
  output+="$(printf '%s' "$label" | json_escape)"
  output+=',"paths":['
  local path
  for path in "$@"; do
    [ -e "$path" ] || continue
    if [ "$first" = "0" ]; then output+=','; fi
    output+="{\"path\":$(printf '%s' "$path" | json_escape),\"exists\":true,\"type\":"
    if [ -d "$path" ]; then
      output+='"directory"'
    elif [ -f "$path" ]; then
      output+='"file"'
    else
      output+='"other"'
    fi
    output+='}'
    first=0
  done
  output+=']}'
  printf '%s' "$output"
}

HINTS=()
REQUIRED_MISSING=()
OPTIONAL_MISSING=()
WARNINGS=()

append_hint() { HINTS+=("$1"); }
add_required_missing() { REQUIRED_MISSING+=("$1"); }
add_optional_missing() { OPTIONAL_MISSING+=("$1"); }
add_warning() { WARNINGS+=("$1"); }

HOME_CODEX="${CODEX_HOME:-$HOME/.codex}"
HOME_CLAUDE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

HARNESS_CHECKS=(
  "$(path_entries_json "codex" "$HOME_CODEX" "$HOME_CODEX/skills" "$HOME_CODEX/AGENTS.md")"
  "$(path_entries_json "claude" "$HOME_CLAUDE" "$HOME_CLAUDE/skills")"
  "$(path_entries_json "proma_community" "$HOME/.proma-community" "$HOME/.proma-community/default-skills" "$HOME/.proma-community/agent-workspaces")"
  "$(path_entries_json "proma_legacy_compat" "$HOME/.proma" "$HOME/.proma/default-skills")"
)

SOURCE_PRESENT=0
[ -f "$SCRIPT_DIR/SKILL.md" ] && SOURCE_PRESENT=1

skill_dest_path_json() {
  local label="$1" path="$2"
  local path_exists=0 skill_exists=0
  [ -e "$path" ] && path_exists=1
  [ -f "$path/SKILL.md" ] && skill_exists=1
  printf '{"label":%s,"path":%s,"exists":%s,"skill_installed":%s}' \
    "$(printf '%s' "$label" | json_escape)" \
    "$(printf '%s' "$path" | json_escape)" \
    "$(to_bool "$path_exists")" \
    "$(to_bool "$skill_exists")"
}

INSTALL_ENTRIES=(
  "$(skill_dest_path_json "source_repo" "$SCRIPT_DIR")"
  "$(skill_dest_path_json "codex_skills" "$HOME_CODEX/skills/$REPO_NAME")"
  "$(skill_dest_path_json "claude_skills" "$HOME_CLAUDE/skills/$REPO_NAME")"
  "$(skill_dest_path_json "proma_community_default" "$HOME/.proma-community/default-skills/$REPO_NAME")"
  "$(skill_dest_path_json "proma_legacy_default" "$HOME/.proma/default-skills/$REPO_NAME")"
)

if compgen -G "$HOME/.proma-community/agent-workspaces/*/skills" > /dev/null; then
  for ws_skills in "$HOME"/.proma-community/agent-workspaces/*/skills; do
    [ -d "$ws_skills" ] || continue
    INSTALL_ENTRIES+=("$(skill_dest_path_json "proma_workspace" "$ws_skills/$REPO_NAME")")
  done
fi

if [ "$SOURCE_PRESENT" = "1" ]; then
  append_hint "当前脚本位于仓库源目录：${SCRIPT_DIR}。Proma 新版安装目标优先使用 ~/.proma-community/default-skills 或 ~/.proma-community/agent-workspaces/*/skills/。"
else
  add_warning "未在脚本同目录发现 SKILL.md；如从安装副本运行，请确认安装是否完整。"
fi

if [ ! -d "$HOME/.proma-community/default-skills" ] && [ ! -d "$HOME/.proma-community/agent-workspaces" ]; then
  add_warning "未发现新版 Proma 目录 ~/.proma-community/default-skills 或 agent-workspaces；若使用新版 Proma，请先启动一次客户端生成目录。"
fi
if [ -d "$HOME/.proma/default-skills" ] && [ ! -d "$HOME/.proma-community" ]; then
  append_hint "检测到旧版 ~/.proma/default-skills；新版 Proma 优先使用 ~/.proma-community/*。"
fi

# ---- Museon ----
MUSEON_INSTALLED=0
MUSEON_WHOAMI_OK=0
MUSEON_PATH=""
MUSEON_VERSION=""
MUSEON_USER_HINT=""
if MUSEON_PATH="$(command -v museoncli 2>/dev/null)"; then
  MUSEON_INSTALLED=1
  if museon_whoami_output="$(execute_capture museoncli whoami)"; then
    MUSEON_WHOAMI_OK=1
    MUSEON_USER_HINT="$(MUSEON_WHOAMI_OUTPUT="$museon_whoami_output" python3 - <<'PY'
import json, os
raw = os.environ.get('MUSEON_WHOAMI_OUTPUT', '')
try:
    data = json.loads(raw)
    user = data.get('data', {}).get('user', {})
    print('signed in' if user.get('id') or user.get('email') else 'whoami ok')
except Exception:
    print('whoami ok')
PY
)"
  fi
  MUSEON_VERSION="$(MUSEON_PATH="$MUSEON_PATH" python3 - <<'PY'
import json, os, subprocess
path = os.environ.get('MUSEON_PATH', 'museoncli')
try:
    p = subprocess.run([path, 'version'], capture_output=True, text=True, timeout=8)
    raw = (p.stdout or p.stderr or '').strip()
    try:
        data = json.loads(raw)
        version = data.get('data', {}).get('cli_version') or data.get('version') or 'available'
    except Exception:
        version = raw or 'available'
    print(version)
except Exception:
    print('available')
PY
)"
else
  add_required_missing "museoncli"
  append_hint "Museon 是 W3 社交口碑发现的必需渠道。用户同意安装后，Agent 应先检查 python3/uv/git/curl，再安装官方最新版 Museon CLI，并优先运行 museoncli setup --agent auto；只有浏览器 OAuth 需要用户操作。"
fi
if [ "$MUSEON_INSTALLED" = "1" ] && [ "$MUSEON_WHOAMI_OK" != "1" ]; then
  add_warning "museoncli 已安装但 whoami 不可用，可能尚未授权；Agent 应运行 museoncli auth status/start/finish --wait，并在浏览器授权后复测 whoami。"
fi

# ---- Agent Reach ----
AGENT_REACH_INSTALLED=0
AGENT_REACH_DOCTOR_OK=0
AGENT_REACH_VERSION_OK=0
AGENT_REACH_PATH=""
AGENT_REACH_VERSION=""
AGENT_REACH_DOCTOR_JSON=""
AGENT_REACH_XHS_BACKEND=""
AGENT_REACH_XHS_STATUS="unknown"
if AGENT_REACH_PATH="$(command -v agent-reach 2>/dev/null)"; then
  AGENT_REACH_INSTALLED=1
  if AGENT_REACH_VERSION="$(execute_capture agent-reach --version)"; then
    AGENT_REACH_VERSION_OK=1
  fi
  if AGENT_REACH_DOCTOR_JSON="$(execute_capture agent-reach doctor --json)"; then
    AGENT_REACH_DOCTOR_OK=1
    AGENT_REACH_XHS_BACKEND="$(AGENT_REACH_DOCTOR_JSON="$AGENT_REACH_DOCTOR_JSON" python3 - <<'PY'
import json, os, sys
raw = os.environ.get('AGENT_REACH_DOCTOR_JSON', '')
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

def walk(obj):
    if isinstance(obj, dict):
        for key, value in obj.items():
            lk = str(key).lower()
            if lk in {'xiaohongshu', 'xhs', 'redbook'} and isinstance(value, dict):
                for bk in ('active_backend', 'backend', 'current_backend'):
                    if bk in value:
                        return value[bk]
            got = walk(value)
            if got is not None:
                return got
    elif isinstance(obj, list):
        for item in obj:
            got = walk(item)
            if got is not None:
                return got
    return None
backend = walk(data)
if backend is not None:
    print(backend)
PY
)"
    if [ -n "$AGENT_REACH_XHS_BACKEND" ]; then
      if [ "$AGENT_REACH_XHS_BACKEND" != "null" ] && [ "$AGENT_REACH_XHS_BACKEND" != "none" ]; then
        AGENT_REACH_XHS_STATUS="active"
      else
        AGENT_REACH_XHS_STATUS="inactive"
      fi
    fi
  fi
else
  add_optional_missing "agent-reach"
  append_hint "Agent Reach 是 W3 原帖/评论核验增强渠道（可选但推荐）。用户同意后，Agent 可按官方文档用 pipx install https://github.com/Panniantong/agent-reach/archive/main.zip 安装，再运行 agent-reach install --env=auto 和 agent-reach doctor --json。"
fi
if [ "$AGENT_REACH_INSTALLED" = "1" ] && [ "$AGENT_REACH_DOCTOR_OK" != "1" ]; then
  add_warning "agent-reach 已安装，但 doctor --json 不可用或执行失败；小红书登录态无法确认。"
fi
if [ "$AGENT_REACH_INSTALLED" = "1" ] && [ "$AGENT_REACH_DOCTOR_OK" = "1" ] && [ "$AGENT_REACH_XHS_STATUS" != "active" ]; then
  add_warning "Agent Reach 可用，但未读取到已激活的小红书 active_backend；核验能力可能受限，可能需要 Chrome 登录态或 OpenCLI 配置。"
fi

# ---- 配置线索：只做存在性/线索检查，不打印密钥值 ----
TAVILY_FOUND=0
for chat_tools in "$HOME/.proma-community/chat-tools.json" "$HOME/.proma/chat-tools.json"; do
  if [ -f "$chat_tools" ] && grep -Eq 'web-search|tavily|tvly-' "$chat_tools"; then
    TAVILY_FOUND=1
    break
  fi
done
if [ "${TAVILY_API_KEY:-}" != "" ]; then TAVILY_FOUND=1; fi
[ "$TAVILY_FOUND" = "1" ] || add_optional_missing "tavily_config"

BRAVE_FOUND=0
BRAVE_RUNTIME_POSSIBLE=0
if command -v brave-search-mcp >/dev/null 2>&1; then
  BRAVE_RUNTIME_POSSIBLE=1
elif command -v npx >/dev/null 2>&1; then
  BRAVE_RUNTIME_POSSIBLE=1
  add_warning "检测到 npx，可作为 Brave MCP 运行器；但这不等同于 Brave 已配置。Brave 只有存在 BRAVE_API_KEY/BRAVE_SEARCH_API_KEY、Brave MCP 配置或 brave-search-mcp 命令及配置时才算配置线索。"
fi
if [ "${BRAVE_API_KEY:-}" != "" ] || [ "${BRAVE_SEARCH_API_KEY:-}" != "" ]; then BRAVE_FOUND=1; fi
if command -v brave-search-mcp >/dev/null 2>&1; then BRAVE_FOUND=1; fi
for mcp_file in "$HOME/.proma-community/mcp.json" "$HOME/.proma/mcp.json" "$HOME/.codex/mcp.json" "$HOME/.claude/mcp.json"; do
  if [ -f "$mcp_file" ] && grep -Eq 'BRAVE_API_KEY|BRAVE_SEARCH_API_KEY|brave-search|brave_search|@brave/' "$mcp_file"; then
    BRAVE_FOUND=1
    break
  fi
done
[ "$BRAVE_FOUND" = "1" ] || add_optional_missing "brave_config"

ZHIPU_FOUND=0
for zvar in ZHIPU_API_KEY ZHIPUAI_API_KEY GLM_API_KEY BIGMODEL_API_KEY; do
  if [ "${!zvar:-}" != "" ]; then ZHIPU_FOUND=1; break; fi
done
for mc in "$HOME/.proma/mcp.json" "$HOME/.proma-community/mcp.json" "$HOME/.codex/mcp.json" "$HOME/.claude/mcp.json"; do
  if [ -f "$mc" ] && grep -Eqi 'zhipu|bigmodel|glm' "$mc"; then ZHIPU_FOUND=1; break; fi
done
[ "$ZHIPU_FOUND" = "1" ] || add_optional_missing "zhipu_config"

append_hint "普通 API 渠道（Tavily/Brave/智谱）只影响非 W3 或兜底搜索；缺失记为 optional_missing，不会把 ok 置为 false。W3 口碑质量优先补齐 Museon，推荐再补 Agent Reach。"

# ---- 版本一致性 ----
VERSION_PROBLEMS=0
VERSION_FILES_JSON='[]'
if [ "$SOURCE_PRESENT" = "1" ] && command -v python3 >/dev/null 2>&1; then
  VERSION_FILES_JSON="$(EXPECTED_VERSION="$EXPECTED_VERSION" SCRIPT_DIR="$SCRIPT_DIR" python3 - <<'PY'
import json, os, re
expected = os.environ['EXPECTED_VERSION']
root = os.environ['SCRIPT_DIR']
files = ['README.md', 'INSTALL.md', 'SKILL.md', 'channels.yaml']
items = []
for name in files:
    path = os.path.join(root, name)
    try:
        text = open(path, encoding='utf-8').read()
    except OSError:
        continue
    if name == 'SKILL.md':
        matches = re.findall(r'(?ms)^metadata:\s*$\s+version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?', text)
    elif name == 'channels.yaml':
        matches = re.findall(r'(?m)^version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?', text)
    elif name == 'README.md':
        matches = re.findall(r'version-([0-9]+\.[0-9]+\.[0-9]+)', text)
    else:
        matches = re.findall(r'安装指南（v([0-9]+\.[0-9]+\.[0-9]+)）', text)
    unique = sorted(set(matches))
    items.append({'file': name, 'versions': unique, 'ok': bool(unique) and all(v == expected for v in unique)})
print(json.dumps(items, ensure_ascii=False))
PY
)"
  VERSION_PROBLEMS="$(VERSION_FILES_JSON="$VERSION_FILES_JSON" python3 - <<'PY'
import json, os
try:
    items = json.loads(os.environ.get('VERSION_FILES_JSON', '[]'))
except Exception:
    print(1)
else:
    print(0 if all(i.get('ok') for i in items) else 1)
PY
)"
fi
if [ "$VERSION_PROBLEMS" != "0" ]; then
  add_warning "文档/配置版本引用存在不一致，请检查 README.md、INSTALL.md、SKILL.md、channels.yaml 是否都为 ${EXPECTED_VERSION}。"
fi

W3_READY=0
if [ "$MUSEON_INSTALLED" = "1" ] && [ "$MUSEON_WHOAMI_OK" = "1" ]; then
  W3_READY=1
fi
REQUIRED_MISSING_COUNT="${#REQUIRED_MISSING[@]}"
OPTIONAL_MISSING_COUNT="${#OPTIONAL_MISSING[@]}"
WARNINGS_COUNT="${#WARNINGS[@]}"
OK=0
if [ "$REQUIRED_MISSING_COUNT" -eq 0 ]; then OK=1; fi
if [ "$W3_READY" = "1" ]; then
  STATUS="w3_ready"
elif [ "$REQUIRED_MISSING_COUNT" -gt 0 ]; then
  STATUS="required_missing"
elif [ "$OPTIONAL_MISSING_COUNT" -gt 0 ]; then
  STATUS="optional_missing"
elif [ "$WARNINGS_COUNT" -gt 0 ]; then
  STATUS="warnings"
else
  STATUS="ok"
fi

if [ "$JSON" = "1" ]; then
  printf '{'
  printf '"schema_version":1,'
  printf '"ok":%s,' "$(to_bool "$OK")"
  printf '"status":"%s",' "$STATUS"
  printf '"skill_version":"%s",' "$EXPECTED_VERSION"
  printf '"script_dir":%s,' "$(printf '%s' "$SCRIPT_DIR" | json_escape)"
  printf '"harness":%s,' "$(printf '%s\n' "${HARNESS_CHECKS[@]}" | join_json_array)"
  printf '"install_locations":%s,' "$(printf '%s\n' "${INSTALL_ENTRIES[@]}" | join_json_array)"
  printf '"museon":{"installed":%s,"path":%s,"whoami_ok":%s,"version":%s,"auth_hint":%s},' \
    "$(to_bool "$MUSEON_INSTALLED")" \
    "$(printf '%s' "$MUSEON_PATH" | json_escape)" \
    "$(to_bool "$MUSEON_WHOAMI_OK")" \
    "$(printf '%s' "$MUSEON_VERSION" | json_escape)" \
    "$(printf '%s' "$MUSEON_USER_HINT" | json_escape)"
  printf '"agent_reach":{"installed":%s,"path":%s,"version_ok":%s,"version":%s,"doctor_ok":%s,"xiaohongshu_status":%s,"active_backend":%s},' \
    "$(to_bool "$AGENT_REACH_INSTALLED")" \
    "$(printf '%s' "$AGENT_REACH_PATH" | json_escape)" \
    "$(to_bool "$AGENT_REACH_VERSION_OK")" \
    "$(printf '%s' "$AGENT_REACH_VERSION" | json_escape)" \
    "$(to_bool "$AGENT_REACH_DOCTOR_OK")" \
    "$(printf '%s' "$AGENT_REACH_XHS_STATUS" | json_escape)" \
    "$(printf '%s' "$AGENT_REACH_XHS_BACKEND" | json_escape)"
  printf '"config_clues":{"tavily":%s,"brave":%s,"zhipu":%s},' \
    "$(to_bool "$TAVILY_FOUND")" "$(to_bool "$BRAVE_FOUND")" "$(to_bool "$ZHIPU_FOUND")"
  printf '"required_missing":%s,' "$(json_str_array "${REQUIRED_MISSING[@]}")"
  printf '"optional_missing":%s,' "$(json_str_array "${OPTIONAL_MISSING[@]}")"
  printf '"missing":%s,' "$(json_str_array "${REQUIRED_MISSING[@]}" "${OPTIONAL_MISSING[@]}")"
  printf '"warnings":%s,' "$(json_str_array "${WARNINGS[@]}")"
  printf '"hints":%s' "$(json_str_array "${HINTS[@]}")"
  printf '}\n'
  exit 0
fi

status_mark() { if [ "$1" = "1" ]; then echo "✅"; else echo "❌"; fi; }
warn_mark() { if [ "$1" = "1" ]; then echo "✅"; else echo "⚠️"; fi; }

echo "📋 web-search-routing 渠道体检（v${EXPECTED_VERSION}）"
echo "状态：${STATUS}"
echo
echo "Harness 目录："
echo "  Codex:   $(status_mark "$([ -d "$HOME_CODEX" ] && echo 1 || echo 0)") ${HOME_CODEX}"
echo "  Claude:  $(status_mark "$([ -d "$HOME_CLAUDE" ] && echo 1 || echo 0)") ${HOME_CLAUDE}"
echo "  Proma 新版: $(warn_mark "$([ -d "$HOME/.proma-community" ] && echo 1 || echo 0)") ~/.proma-community"
echo "    - default-skills: $(status_mark "$([ -d "$HOME/.proma-community/default-skills" ] && echo 1 || echo 0)") ~/.proma-community/default-skills"
echo "    - agent-workspaces: $(status_mark "$([ -d "$HOME/.proma-community/agent-workspaces" ] && echo 1 || echo 0)") ~/.proma-community/agent-workspaces"
echo "  Proma 旧版兼容: $(warn_mark "$([ -d "$HOME/.proma" ] && echo 1 || echo 0)") ~/.proma（仅兼容）"
echo
echo "Skill 安装位置："
echo "  仓库源路径: $(status_mark "$SOURCE_PRESENT") ${SCRIPT_DIR}"
echo "  Codex:   $(status_mark "$([ -f "$HOME_CODEX/skills/$REPO_NAME/SKILL.md" ] && echo 1 || echo 0)") ${HOME_CODEX}/skills/${REPO_NAME}"
echo "  Claude:  $(status_mark "$([ -f "$HOME_CLAUDE/skills/$REPO_NAME/SKILL.md" ] && echo 1 || echo 0)") ${HOME_CLAUDE}/skills/${REPO_NAME}"
echo "  Proma default-skills: $(status_mark "$([ -f "$HOME/.proma-community/default-skills/$REPO_NAME/SKILL.md" ] && echo 1 || echo 0)") ~/.proma-community/default-skills/${REPO_NAME}"
if [ -d "$HOME/.proma-community/agent-workspaces" ]; then
  found_ws=0
  for ws_skills in "$HOME"/.proma-community/agent-workspaces/*/skills; do
    [ -d "$ws_skills/$REPO_NAME" ] || continue
    echo "  Proma 工作区: $(status_mark "1") ${ws_skills}/${REPO_NAME}"
    found_ws=1
  done
  [ "$found_ws" = "1" ] || echo "  Proma 工作区: ❌ 未发现已安装副本（~/.proma-community/agent-workspaces/*/skills/${REPO_NAME}）"
fi
echo "  旧版兼容: $(warn_mark "$([ -f "$HOME/.proma/default-skills/$REPO_NAME/SKILL.md" ] && echo 1 || echo 0)") ~/.proma/default-skills/${REPO_NAME}"
echo
echo "渠道工具："
echo "  Museon CLI: $(status_mark "$MUSEON_INSTALLED") $([ -n "$MUSEON_PATH" ] && echo "$MUSEON_PATH" || echo "未找到")"
echo "    whoami: $(status_mark "$MUSEON_WHOAMI_OK")$([ -n "$MUSEON_USER_HINT" ] && echo " (${MUSEON_USER_HINT})")"
[ -n "$MUSEON_VERSION" ] && echo "    version: ${MUSEON_VERSION}"
echo "  Agent Reach: $(status_mark "$AGENT_REACH_INSTALLED") $([ -n "$AGENT_REACH_PATH" ] && echo "$AGENT_REACH_PATH" || echo "未找到")"
echo "    --version: $(status_mark "$AGENT_REACH_VERSION_OK")"
echo "    doctor --json: $(status_mark "$AGENT_REACH_DOCTOR_OK")"
echo "    小红书 active_backend: ${AGENT_REACH_XHS_STATUS}$( [ -n "$AGENT_REACH_XHS_BACKEND" ] && echo " (${AGENT_REACH_XHS_BACKEND})" )"
echo
echo "配置线索（不显示密钥值）："
echo "  Tavily: $(warn_mark "$TAVILY_FOUND")"
echo "  Brave:  $(warn_mark "$BRAVE_FOUND")"
echo "  智谱:   $(warn_mark "$ZHIPU_FOUND")"
echo
if [ "$WARNINGS_COUNT" -gt 0 ]; then
  echo "警告："
  for warning in "${WARNINGS[@]}"; do echo "  - $warning"; done
  echo
fi
if [ "$REQUIRED_MISSING_COUNT" -gt 0 ]; then
  echo "必需缺失："
  for item in "${REQUIRED_MISSING[@]}"; do echo "  - $item"; done
  echo
fi
if [ "$OPTIONAL_MISSING_COUNT" -gt 0 ]; then
  echo "可选缺失："
  for item in "${OPTIONAL_MISSING[@]}"; do echo "  - $item"; done
  echo
fi
if [ "${#HINTS[@]}" -gt 0 ]; then
  echo "建议："
  for hint in "${HINTS[@]}"; do echo "  - $hint"; done
fi
