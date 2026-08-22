#!/usr/bin/env bash
# Idempotent Agent Reach installer/helper for web-search-routing.
# Uses the official pipx/zip path, then read-only doctor. System/channel changes require user approval.
set -euo pipefail

ARCHIVE_URL="${AGENT_REACH_ARCHIVE_URL:-https://github.com/Panniantong/agent-reach/archive/main.zip}"
SYSTEM_CHANGES="${AGENT_REACH_SYSTEM_CHANGES:-0}"
CHANNELS="${AGENT_REACH_CHANNELS:-}"
PIPX_CMD=()

log() { printf '👉 %s\n' "$*"; }
ok() { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1; }

add_user_bin_path() {
  local user_base bin_dir
  bin_dir="$HOME/.local/bin"

  if need python3; then
    user_base="$(python3 - <<'PY' 2>/dev/null || true
import site
print(site.getuserbase())
PY
)"
    [ -n "$user_base" ] && bin_dir="$user_base/bin:$bin_dir"
  fi

  bin_dir="$HOME/.cargo/bin:$bin_dir"
  export PATH="$bin_dir:$PATH"
  hash -r 2>/dev/null || true
}

run_pipx() {
  if [ "${#PIPX_CMD[@]}" -eq 0 ]; then
    die "pipx runner 未初始化。"
  fi
  "${PIPX_CMD[@]}" "$@"
}

ensure_pipx() {
  add_user_bin_path

  if need pipx; then
    ok "pipx 已存在：$(command -v pipx)"
    PIPX_CMD=(pipx)
    return 0
  fi

  need python3 || die "缺少 python3，无法自动安装 Agent Reach。"

  # Prefer uvx if available; otherwise use `uv tool run`, which exists even when uvx shim is absent.
  if need uvx; then
    log "未找到 pipx，改用 uvx 运行 pipx。"
    PIPX_CMD=(uvx --from pipx pipx)
  elif need uv; then
    log "未找到 pipx/uvx，改用 uv tool run 运行 pipx..."
    PIPX_CMD=(uv tool run --from pipx pipx)
  elif need pip3; then
    log "未找到 pipx，尝试用用户级 pip 安装 pipx..."
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath >/dev/null 2>&1 || true
    add_user_bin_path
    need pipx || die "pipx 安装后仍不可用。"
    PIPX_CMD=(pipx)
  elif python3 -m pip --version >/dev/null 2>&1; then
    log "未找到 pipx/pip3，尝试通过 python3 -m pip 用户级安装 pipx..."
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath >/dev/null 2>&1 || true
    add_user_bin_path
    need pipx || die "pipx 安装后仍不可用。"
    PIPX_CMD=(pipx)
  else
    die "缺少 pipx/uv/uvx/pip；请先安装 pipx 或 uv 后重试。"
  fi
}

install_agent_reach() {
  add_user_bin_path
  if need agent-reach; then
    ok "agent-reach 已存在：$(command -v agent-reach)"
    return 0
  fi
  log "正在从官方 GitHub zip 安装 Agent Reach..."
  run_pipx install "$ARCHIVE_URL"
  add_user_bin_path
  need agent-reach || die "agent-reach 安装后仍不可用；请检查 pipx/uvx bin 目录是否在 PATH 中。"
  ok "agent-reach 可用：$(command -v agent-reach)"
}

run_safe_checks() {
  log "运行只读环境检查：agent-reach install --env=auto"
  agent-reach install --env=auto || warn "只读检查报告了缺失或失败；继续运行 doctor 以获取详情。"
  if [ "$SYSTEM_CHANGES" = "1" ]; then
    if [ -n "$CHANNELS" ]; then
      log "用户已批准系统变更，安装基础组件和通道：${CHANNELS}"
      agent-reach install --env=auto --system --channels="$CHANNELS"
    else
      log "用户已批准系统变更，安装基础组件..."
      agent-reach install --env=auto --system
    fi
  else
    warn "未启用系统级安装。若 doctor 提示需要 --system 或 Chrome/OpenCLI/登录态，请先征得用户确认后再执行。"
  fi
}

verify() {
  log "运行 agent-reach doctor --json ..."
  if agent-reach doctor --json >/tmp/web-search-routing-agent-reach-doctor.json; then
    ok "agent-reach doctor --json 可执行。"
  else
    warn "doctor --json 返回非零；请根据输出修复缺失依赖或登录态。"
    return 1
  fi
}

main() {
  add_user_bin_path
  ensure_pipx
  install_agent_reach
  run_safe_checks
  verify
}

main "$@"
