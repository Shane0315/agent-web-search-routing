#!/usr/bin/env bash
# Idempotent Museon CLI installer/helper for web-search-routing.
# Safe to rerun. It does not ask the user to copy commands; browser OAuth remains interactive.
set -euo pipefail

MUSEON_VERSION="${MUSEON_VERSION:-0.5.19}"
WHEEL_URL="${MUSEON_WHEEL_URL:-https://github.com/Museon-AI/museon-cli/releases/download/v${MUSEON_VERSION}/museoncli-${MUSEON_VERSION}-py3-none-any.whl}"
AGENT_ARG="${MUSEON_SETUP_AGENT:-auto}"

log() { printf '👉 %s\n' "$*"; }
ok() { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1; }

add_user_bin_path() {
  local user_base bin_dir
  bin_dir="$HOME/.local/bin"

  # Prefer Python's user base, because uv/pip tools may install there on some systems.
  if need python3; then
    user_base="$(python3 - <<'PY' 2>/dev/null || true
import site
print(site.getuserbase())
PY
)"
    [ -n "$user_base" ] && bin_dir="$user_base/bin:$bin_dir"
  fi

  # Common uv/cargo locations.
  bin_dir="$HOME/.cargo/bin:$bin_dir"
  export PATH="$bin_dir:$PATH"
  hash -r 2>/dev/null || true
}

install_uv() {
  add_user_bin_path
  if need uv; then
    ok "uv 已存在：$(command -v uv)"
    return 0
  fi
  if need curl; then
    log "未找到 uv，正在使用官方脚本安装到用户目录..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
  elif need wget; then
    log "未找到 uv，正在使用官方脚本安装到用户目录..."
    wget -qO- https://astral.sh/uv/install.sh | sh
  else
    die "缺少 curl/wget，无法自动安装 uv。请先安装 curl 或 uv 后重试。"
  fi
  add_user_bin_path
  # shellcheck disable=SC1091
  [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
  add_user_bin_path
  need uv || die "uv 安装后仍不可用；请检查 ~/.local/bin 或 Python user-base/bin 是否在 PATH 中。"
  ok "uv 安装完成：$(command -v uv)"
}

check_python() {
  need python3 || die "缺少 python3。Museon 需要 Python 3.11+；请先安装 Python 3.11+。"
  python3 - <<'PY' || die "Python 版本过低，Museon 需要 Python 3.11+。"
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
  ok "python3 版本满足要求：$(python3 -c 'import platform; print(platform.python_version())')"
}

install_museon() {
  add_user_bin_path
  if need museoncli; then
    ok "museoncli 已存在：$(command -v museoncli)"
  else
    log "正在安装 Museon CLI ${MUSEON_VERSION}..."
    uv tool install "$WHEEL_URL"
    add_user_bin_path
  fi
  need museoncli || die "museoncli 安装后仍不可用；请检查 uv tool bin 目录是否在 PATH 中。"
  ok "museoncli 可用：$(command -v museoncli)"
  log "版本：$(museoncli version 2>/dev/null || true)"
}

setup_agent() {
  log "正在执行 museoncli setup --agent ${AGENT_ARG} ..."
  if museoncli setup --agent "$AGENT_ARG"; then
    ok "Museon Agent Skill setup 完成。"
  else
    warn "museoncli setup --agent ${AGENT_ARG} 未成功。Proma 若未被 auto 识别，请重启后查看 setup 输出；CLI 授权仍可继续。"
  fi
}

auth_if_needed() {
  if museoncli whoami >/dev/null 2>&1; then
    ok "Museon 已授权：whoami 成功。"
    return 0
  fi

  log "当前未完成 Museon 授权。接下来需要你在浏览器里登录/批准。"
  local start_output
  start_output="$(museoncli auth status 2>/dev/null || true)"
  if ! printf '%s\n' "$start_output" | grep -Eqi 'authenticated|valid|signed in'; then
    start_output="$(museoncli auth start 2>&1 || true)"
  fi
  printf '%s\n' "$start_output" | sed -E 's/(device_code|access_token|api[_-]?key|token)[^[:space:]]*/[REDACTED]/Ig'

  if museoncli auth finish --wait --timeout 60 --poll-interval 2; then
    ok "浏览器授权完成。"
  else
    warn "授权等待超时或尚未完成。请完成页面登录/批准后，回到 Agent 说“继续”，我会复测 museoncli whoami。"
    return 2
  fi
}

verify() {
  add_user_bin_path
  museoncli whoami >/dev/null 2>&1 || die "Museon whoami 仍失败；请完成授权后重试。"
  ok "验证通过：museoncli whoami 成功。"
}

main() {
  add_user_bin_path
  check_python
  install_uv
  install_museon
  setup_agent
  auth_if_needed || exit 2
  verify
}

main "$@"
