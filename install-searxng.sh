#!/usr/bin/env bash
# ============================================================
# install-searxng.sh — SearXNG 本地零成本搜索渠道一键安装（web-search-routing v3.4）
#
# 作用：为 web-search-routing Skill 部署一个本地 SearXNG 元搜索实例，
#       作为 Tier1 内最优先的零成本通用搜索渠道（无额度上限、无 API Key）。
#
# 完成内容：
#   1. clone SearXNG 源码到 ~/searxng-src（已存在则 git pull 升级）
#   2. 创建 Python 3.12 venv（优先 uv，回退 python3 -m venv）
#   3. 写 ~/.config/searxng/settings.yml（开 JSON API + 关 limiter + 随机 secret key
#      + 可选出站代理 + 禁用易验证码引擎）
#   4. 安装 launchd 自启（macOS）/ systemd --user 或手动指引（Linux）
#   5. 安装 ~/.local/bin/searxng.sh 与 websearch-free.sh 封装脚本
#   6. 健康验证：HTTP 200 + JSON 结果
#
# 用法：
#   bash install-searxng.sh              # 自动探测代理（国内环境推荐）
#   bash install-searxng.sh --no-proxy   # 强制直连（海外网络环境）
#   bash install-searxng.sh --proxy http://127.0.0.1:7890   # 指定代理
#
# 可重复运行（幂等）：已有配置/密钥会被保留。
# ============================================================
set -euo pipefail

SEARXNG_HOME="${SEARXNG_HOME:-$HOME/searxng-src}"
CONFIG_DIR="$HOME/.config/searxng"
CONFIG_FILE="$CONFIG_DIR/settings.yml"
BIN_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/searxng"
BASE_URL="${SEARXNG_BASE_URL:-http://127.0.0.1:8888}"
LAUNCHD_LABEL="com.searxng.local"
PY_VERSION="${SEARXNG_PYTHON:-3.12}"

log() { printf '👉 %s\n' "$*"; }
ok()  { printf '✅ %s\n' "$*"; }
warn(){ printf '⚠️  %s\n' "$*" >&2; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1; }

# ---------- 参数解析 ----------
PROXY_MODE="auto"
PROXY_URL=""
for arg in "$@"; do
  case "$arg" in
    --no-proxy) PROXY_MODE="none" ;;
    --proxy)    die "--proxy 需要带值：--proxy http://127.0.0.1:7890" ;;
    --proxy=*)  PROXY_MODE="explicit"; PROXY_URL="${arg#--proxy=}" ;;
    -h|--help)  sed -n '2,28p' "$0"; exit 0 ;;
    *)          die "未知参数：${arg}（支持 --no-proxy / --proxy=<url>）" ;;
  esac
done

# ---------- 依赖检查 ----------
for cmd in git curl; do
  need "$cmd" || die "缺少 ${cmd}，请先安装（macOS: xcode-select --install / brew install ${cmd}）"
done
if ! need python3; then
  die "缺少 python3。请先安装 Python 3.11+（https://www.python.org/downloads/ 或 brew install python）"
fi

# ---------- 代理探测 ----------
# SearXNG 内部用 httpx，不读 HTTP_PROXY 环境变量，必须在 settings.yml 显式声明。
# （这是文档没写的坑：不配代理时国内环境所有引擎会全部超时。）
detect_proxy() {
  if [ "$PROXY_MODE" = "none" ]; then
    PROXY_URL=""; return 0
  fi
  if [ "$PROXY_MODE" = "explicit" ]; then return 0; fi

  # 1) 环境变量里有就直接用
  if [ -n "${HTTPS_PROXY:-}${https_proxy:-}" ]; then
    PROXY_URL="${HTTPS_PROXY:-${https_proxy:-}}"
    log "检测到环境代理 ${PROXY_URL}，将写入 SearXNG 配置"
    return 0
  fi

  # 2) 直连能出网就不配代理（海外网络环境）
  if curl -s -m 5 -o /dev/null -w '' https://www.google.com 2>/dev/null; then
    log "直连可出网，不配置代理"
    PROXY_URL=""
    return 0
  fi

  # 3) 探测常见本机代理端口（Clash 7890/7897、V2Ray 10809/1087、Privoxy 8118）
  local port
  for port in 7890 7897 10809 1087 8118; do
    if curl -s -m 4 -x "http://127.0.0.1:$port" -o /dev/null https://www.google.com 2>/dev/null; then
      PROXY_URL="http://127.0.0.1:$port"
      log "探测到本机代理 $PROXY_URL 可用，将写入 SearXNG 配置"
      return 0
    fi
  done

  warn "未探测到可用代理。直连 Google 失败，多数引擎可能超时；仍将继续安装（百度等国内引擎可用）。"
  warn "如有代理，可运行：bash install-searxng.sh --proxy http://127.0.0.1:7890"
  PROXY_URL=""
}

# ---------- 1. 源码 ----------
if [ -d "$SEARXNG_HOME/.git" ]; then
  log "源码已存在，git pull 升级..."
  git -C "$SEARXNG_HOME" pull --ff-only || warn "git pull 失败，继续使用现有源码"
else
  log "clone SearXNG 源码到 $SEARXNG_HOME ..."
  git clone --depth 1 https://github.com/searxng/searxng.git "$SEARXNG_HOME"
fi

# ---------- 2. venv ----------
if [ ! -d "$SEARXNG_HOME/.venv" ]; then
  if need uv; then
    log "用 uv 创建 Python ${PY_VERSION} venv ..."
    (cd "$SEARXNG_HOME" && uv venv --python "$PY_VERSION") \
      || (cd "$SEARXNG_HOME" && uv venv) \
      || die "uv venv 创建失败"
  else
    log "未找到 uv，用系统 python3 创建 venv ..."
    (cd "$SEARXNG_HOME" && python3 -m venv .venv) || die "python3 -m venv 创建失败"
  fi
else
  ok "venv 已存在：$SEARXNG_HOME/.venv"
fi

# shellcheck disable=SC1091
if [ -f "$SEARXNG_HOME/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  . "$SEARXNG_HOME/.venv/bin/activate"
fi
command -v python >/dev/null 2>&1 || die "venv 激活失败"

log "安装依赖（首次约 2-5 分钟）..."
VENV_PY="$SEARXNG_HOME/.venv/bin/python"
if [ "${SEARXNG_SKIP_DEPS:-0}" = "1" ]; then
  log "SEARXNG_SKIP_DEPS=1，跳过依赖安装"
elif need uv; then
  # uv venv 默认不含 pip，统一走 uv pip（自动识别 VIRTUAL_ENV）
  # 坑：可编辑安装（-e .）构建期会 import searx，而构建依赖（msgspec/pyyaml/
  # typing_extensions）未声明在 build-system.requires 里 → 先装 requirements.txt
  # 再用 --no-build-isolation 安装，否则直接报 ModuleNotFoundError
  (cd "$SEARXNG_HOME" && \
    uv pip install --quiet setuptools && \
    uv pip install --quiet -r requirements.txt && \
    uv pip install --quiet --no-build-isolation -e . && \
    uv pip install --quiet -r requirements-server.txt) \
    || warn "uv pip 安装部分失败；若后续启动报错请重跑本脚本"
else
  "$VENV_PY" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "$VENV_PY" -m pip install --quiet --upgrade pip setuptools || warn "pip/setuptools 升级失败，继续"
  (cd "$SEARXNG_HOME" && \
    "$VENV_PY" -m pip install --quiet -r requirements.txt && \
    "$VENV_PY" -m pip install --quiet --no-build-isolation -e . && \
    "$VENV_PY" -m pip install --quiet -r requirements-server.txt) \
    || warn "部分依赖安装失败；若后续启动报错请重跑本脚本"
fi

# ---------- 3. 配置 ----------
mkdir -p "$CONFIG_DIR" "$BIN_DIR" "$STATE_DIR"

SECRET_KEY=""
# 已有配置则保留 secret key（幂等）
if [ -f "$CONFIG_FILE" ] && grep -q 'secret_key:' "$CONFIG_FILE"; then
  SECRET_KEY="$(grep 'secret_key:' "$CONFIG_FILE" | head -1 | sed 's/.*secret_key:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/')"
fi
[ -n "$SECRET_KEY" ] || SECRET_KEY="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"

detect_proxy

write_config() {
  cat > "$CONFIG_FILE" <<EOF
# SearXNG 本地实例配置 — 由 web-search-routing install-searxng.sh 生成
# 继承上游默认值，只覆盖必要项；git pull 升级源码时不会冲突。
use_default_settings: true

general:
  instance_name: "SearXNG (local)"
  donation_url: false
  contact_url: false
  enable_metrics: true

search:
  safe_search: 0
  autocomplete: ""
  default_lang: "auto"
  # ★ 关键 1：开启 JSON API（上游默认只有 html，程序化调用必需）
  formats:
    - html
    - json
    - csv
    - rss

server:
  port: 8888
  bind_address: "127.0.0.1"
  base_url: "http://127.0.0.1:8888/"
  # ★ 关键 2：本地自用关闭限流器，否则 API 请求被 429/403 拦截
  limiter: false
  public_instance: false
  image_proxy: false
  secret_key: "${SECRET_KEY}"
  # 允许 GET 调用（上游默认 POST），便于 curl / 脚本直接请求
  method: "GET"

ui:
  static_use_hash: true
  default_locale: "zh-Hans-CN"
  query_in_title: true
  infinite_scroll: false

outgoing:
  # 走代理后 RTT 变长，超时给足
  request_timeout: 10.0
  max_request_timeout: 20.0
  pool_connections: 100
  pool_maxsize: 20
  enable_http2: true
$(if [ -n "$PROXY_URL" ]; then cat <<EOF2
  # ★ 关键 3：SearXNG 用 httpx，不读 HTTP_PROXY 环境变量，必须在此显式声明。
  proxies:
    all://:
      - ${PROXY_URL}
EOF2
else cat <<EOF2
  # 未配置代理（直连环境）。若引擎大面积超时，运行
  #   bash install-searxng.sh --proxy http://127.0.0.1:7890
  # 重新写入代理后重启。
EOF2
fi)

# ───────── 引擎调优 ─────────
# 原则：关掉在共享代理出口 IP 下必然验证码/限流的引擎，避免每次搜索都拖 10s 超时。
# 想恢复某个引擎，把对应 disabled 改成 false 后重启即可（无需代理的直连环境也可全恢复）。
engines:
  # 代理出口 IP 被判定为机器人 → 稳定返回验证码/限流，关闭以提速
  - name: duckduckgo
    disabled: true
  - name: startpage
    disabled: true
  - name: brave
    disabled: true
  # Tor 相关引擎无 Tor 网络，加载即失败
  - name: ahmia
    disabled: true
  - name: torch
    disabled: true
  # wikidata 启动时拉 SPARQL 属性表，经代理常 403 → 关闭（wikipedia 保留）
  - name: wikidata
    disabled: true
  # 代理出口下同样返回验证码
  - name: qwant
    disabled: true
  - name: sogou
    disabled: true

  # ── 主力引擎：显式启用 ──
  - name: google
    disabled: false
    timeout: 10.0
  - name: bing
    disabled: false
    timeout: 10.0
  - name: wikipedia
    disabled: false
    timeout: 10.0
  - name: mojeek
    disabled: false

  # ── 中文引擎（补齐 W5 中文生态）──
  - name: baidu
    disabled: false
  - name: 360search
    disabled: false

  # ── 技术垂直（bang 语法用：!github / !so / !arxiv）──
  - name: github
    disabled: false
  - name: stackoverflow
    disabled: false
  - name: arxiv
    disabled: false
EOF
}

if [ -f "$CONFIG_FILE" ] && [ "${SEARXNG_KEEP_CONFIG:-0}" = "1" ]; then
  ok "SEARXNG_KEEP_CONFIG=1，保留现有 $CONFIG_FILE"
else
  log "写配置 $CONFIG_FILE ..."
  write_config
fi

# ---------- 4. 启动包装脚本 ----------
cat > "$BIN_DIR/searxng-start.sh" <<'EOF'
#!/bin/bash
# SearXNG 启动包装脚本 — launchd / systemd / 手动启动共用，保证环境一致。
set -e

SEARXNG_HOME="$HOME/searxng-src"
export SEARXNG_SETTINGS_PATH="$HOME/.config/searxng/settings.yml"

# 本地回环不走代理（出站代理在 settings.yml 的 outgoing.proxies 中声明）
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="localhost,127.0.0.1,::1"
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

cd "$SEARXNG_HOME"
source .venv/bin/activate
exec python -m searx.webapp
EOF
chmod +x "$BIN_DIR/searxng-start.sh"

# ---------- 5. CLI 封装：searxng.sh ----------
cat > "$BIN_DIR/searxng.sh" <<'EOF'
#!/bin/bash
# searxng.sh — 本地 SearXNG 搜索 CLI（零成本渠道）
# 由 web-search-routing install-searxng.sh 生成
#
# 用法:
#   searxng.sh "查询词"                    # 默认返回 10 条精简 JSON
#   searxng.sh "查询词" -n 20              # 指定条数
#   searxng.sh "!github searxng" -n 5      # bang 语法做垂直检索
#   searxng.sh "查询词" --raw              # 返回原始完整 JSON
#   searxng.sh "查询词" --md               # Markdown 列表（人读友好）
#   searxng.sh --health                    # 健康检查
#
# Bang 速查: !github !so(StackOverflow) !arxiv !wp(Wikipedia) !bi(Bing) !go(Google) !bd(百度)

set -uo pipefail
BASE="${SEARXNG_BASE_URL:-http://127.0.0.1:8888}"
N=10
FMT="slim"
Q=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --health)
      code=$(curl -s -m 10 --noproxy '*' -o /dev/null -w '%{http_code}' \
        --get --data-urlencode "q=ping" --data-urlencode "format=json" "$BASE/search")
      if [[ "$code" == "200" ]]; then echo "✅ SearXNG 正常 ($BASE)"; exit 0
      else echo "❌ SearXNG 异常 (HTTP $code) — 试 launchctl kickstart -k gui/$(id -u)/com.searxng.local"; exit 1; fi ;;
    -n|--num) N="$2"; shift 2 ;;
    --raw) FMT="raw"; shift ;;
    --md)  FMT="md";  shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) Q="$1"; shift ;;
  esac
done

[[ -z "$Q" ]] && { echo "用法: searxng.sh \"查询词\" [-n 条数] [--raw|--md]" >&2; exit 1; }

RESP=$(curl -s -m 30 --noproxy '*' --get \
  --data-urlencode "q=$Q" --data-urlencode "format=json" "$BASE/search" 2>/dev/null)

[[ -z "$RESP" ]] && { echo "❌ 无响应，服务可能未运行（searxng.sh --health）" >&2; exit 1; }

if [[ "$FMT" == "raw" ]]; then echo "$RESP"; exit 0; fi

echo "$RESP" | N="$N" FMT="$FMT" python3 -c '
import json,sys,os
n=int(os.environ["N"]); fmt=os.environ["FMT"]
d=json.load(sys.stdin)
rs=d.get("results",[])[:n]
if fmt=="md":
    print(f'"'"'# 搜索: {d.get("query","")}  （{len(d.get("results",[]))} 条命中，显示前 {len(rs)}）\n'"'"')
    for i,r in enumerate(rs,1):
        print(f'"'"'{i}. [{r.get("title","无标题")}]({r.get("url","")})'"'"')
        c=(r.get("content") or "").strip().replace("\n"," ")
        if c: print(f"   {c[:200]}")
        print(f'"'"'   `{r.get("engine","")}`\n'"'"')
else:
    out=[{"title":r.get("title"),"url":r.get("url"),
          "content":(r.get("content") or "").strip()[:300],
          "engine":r.get("engine")} for r in rs]
    print(json.dumps({"query":d.get("query"),"total":len(d.get("results",[])),
        "results":out,"unresponsive":d.get("unresponsive_engines",[])},
        ensure_ascii=False,indent=2))
'
EOF
chmod +x "$BIN_DIR/searxng.sh"

# ---------- 6. CLI 封装：websearch-free.sh（零成本「发现→全文」链路） ----------
cat > "$BIN_DIR/websearch-free.sh" <<'EOF'
#!/bin/bash
# websearch-free.sh — 零成本「发现 → 全文」链路
# SearXNG (本地聚合搜索) → Jina Reader (本地全文提取，可选)
# 由 web-search-routing install-searxng.sh 生成
#
# 用途：替代 Tavily / Firecrawl 的大部分场景，全程不消耗任何 API 额度。
# 注意：全文提取需要本地 Jina Reader（http://127.0.0.1:8082）。未部署时
#       仍可用，只是只返回搜索结果概览（-k 0 效果）。
#
# 用法:
#   websearch-free.sh "查询词"              # 搜索 + 抓取前 3 篇全文
#   websearch-free.sh "查询词" -k 5         # 抓取前 5 篇
#   websearch-free.sh "查询词" -k 0         # 只搜索不抓取（等同 searxng.sh --md）
#   websearch-free.sh "查询词" -c 3000      # 每篇正文截断字数（默认 2000）

set -uo pipefail
SEARX="${SEARXNG_BASE_URL:-http://127.0.0.1:8888}"
JINA="${JINA_READER_URL:-http://127.0.0.1:8082}"
K=3          # 抓取全文的篇数
CHARS=2000   # 每篇正文保留字数
Q=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--fetch) K="$2"; shift 2 ;;
    -c|--chars) CHARS="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) Q="$1"; shift ;;
  esac
done
[[ -z "$Q" ]] && { echo "用法: websearch-free.sh \"查询词\" [-k 抓取篇数] [-c 截断字数]" >&2; exit 1; }

# ── 阶段 1：SearXNG 发现 ──
RESP=$(curl -s -m 30 --noproxy '*' --get \
  --data-urlencode "q=$Q" --data-urlencode "format=json" "$SEARX/search" 2>/dev/null)
[[ -z "$RESP" ]] && { echo "❌ SearXNG 无响应（searxng.sh --health）" >&2; exit 1; }

echo "$RESP" | python3 -c '
import json,sys
d=json.load(sys.stdin)
rs=d.get("results",[])
q=d.get("query","")
print("# 搜索: " + q)
print()
print("共 " + str(len(rs)) + " 条命中 · 来源: SearXNG (本地, 零成本)")
print()
print("## 结果概览")
print()
for i,r in enumerate(rs[:10],1):
    print(str(i) + ". [" + r.get("title","无标题") + "](" + r.get("url","") + ")")
    c=(r.get("content") or "").strip().replace(chr(10)," ")
    if c: print("   " + c[:180])
'

# ── 阶段 2：Jina Reader 提取全文（未部署则跳过并说明） ──
if [[ "$K" -gt 0 ]] && ! curl -s -m 5 --noproxy '*' -o /dev/null "$JINA/" 2>/dev/null; then
  echo ""
  echo "## 全文提取已跳过"
  echo "_（本地 Jina Reader ($JINA) 未运行：可运行 searxng.sh --md 查看结果概览，"
  echo "  或用浏览器/WebFetch 打开重点 URL；需要零成本全文链路可自建 jina-reader）_"
  exit 0
fi
[[ "$K" -eq 0 ]] && exit 0

URLS=$(echo "$RESP" | K="$K" python3 -c '
import json,sys,os
d=json.load(sys.stdin); seen=set(); out=[]
for r in d.get("results",[]):
    u=r.get("url","")
    if not u.startswith("http"): continue
    host=u.split("/")[2] if len(u.split("/"))>2 else u
    if host in seen: continue      # 每个域名只取一篇，保证来源多样性
    seen.add(host); out.append(u)
    if len(out)>=int(os.environ["K"]): break
print("\n".join(out))')

echo ""
echo "## 全文提取（Jina Reader, 零成本）"
i=0
while IFS= read -r u; do
  [[ -z "$u" ]] && continue
  i=$((i+1))
  echo ""
  echo "### [$i] $u"
  echo ""
  body=$(curl -s -m 40 --noproxy '*' "$JINA/$u" 2>/dev/null)
  if [[ -z "$body" ]]; then
    echo "_（提取失败，可能是反爬或超时）_"
  else
    echo "$body" | head -c "$CHARS"
    [[ ${#body} -gt $CHARS ]] && echo "" && echo "_…已截断（原文 ${#body} 字符）_"
  fi
done <<< "$URLS"
EOF
chmod +x "$BIN_DIR/websearch-free.sh"

# ---------- 7. 自启 ----------
OS="$(uname -s)"
if [ "${SEARXNG_SKIP_SERVICE:-0}" = "1" ]; then
  log "SEARXNG_SKIP_SERVICE=1，跳过自启注册与启动（测试/手动管理模式）"
  echo
  echo "✅ 安装完成（未注册自启服务）。手动启动：nohup ~/.local/bin/searxng-start.sh &"
  exit 0
fi
if [ "$OS" = "Darwin" ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHD_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${BIN_DIR}/searxng-start.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>WorkingDirectory</key>
    <string>${SEARXNG_HOME}</string>

    <key>StandardOutPath</key>
    <string>${STATE_DIR}/searxng.log</string>

    <key>StandardErrorPath</key>
    <string>${STATE_DIR}/searxng.error.log</string>

    <key>ProcessType</key>
    <string>Background</string>

    <!-- 崩溃后 10s 重启，避免疯狂重试 -->
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF
  log "注册 launchd 自启（RunAtLoad + KeepAlive）..."
  launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
  log "启动服务（首次启动引擎初始化约 10-30 秒）..."
  launchctl kickstart -k "gui/$(id -u)/${LAUNCHD_LABEL}"
else
  # Linux：systemd --user 可用则注册，否则给手动启动指引
  if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/searxng.service" <<EOF
[Unit]
Description=SearXNG local instance (web-search-routing)

[Service]
Type=simple
ExecStart=${BIN_DIR}/searxng-start.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now searxng.service
    ok "systemd 用户服务已启用（searxng.service）"
  else
    warn "非 macOS 且无 systemd --user，请手动启动：nohup ~/.local/bin/searxng-start.sh >/dev/null 2>&1 &"
  fi
fi

# ---------- 8. 健康验证 ----------
log "等待服务就绪（最长 90 秒）..."
HEALTH=1
for i in $(seq 1 30); do
  code=$(curl -s -m 8 --noproxy '*' -o /dev/null -w '%{http_code}' \
    --get --data-urlencode "q=ping" --data-urlencode "format=json" "$BASE_URL/search" 2>/dev/null || echo 000)
  if [ "$code" = "200" ]; then HEALTH=0; break; fi
  sleep 3
done

echo
if [ "$HEALTH" = "0" ]; then
  ok "SearXNG 已就绪：${BASE_URL}（JSON API 正常）"
else
  die "健康检查失败（HTTP ${code}）。排查：
  1. 看日志：tail -30 $STATE_DIR/searxng.error.log
  2. 重启：  launchctl kickstart -k gui/$(id -u)/${LAUNCHD_LABEL}   # macOS
  3. 若所有引擎超时：国内网络需配置代理后重跑
     bash install-searxng.sh --proxy http://127.0.0.1:7890"
fi

# 实测一次真实查询
log "实测一次搜索验证引擎..."
"$BIN_DIR/searxng.sh" "test" -n 2 >/dev/null 2>&1 && ok "搜索链路验证通过" || warn "首次搜索未返回结果（引擎可能仍在预热），稍后重试 searxng.sh \"test\""

case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) warn "\$HOME/.local/bin 不在 PATH 中；请将其加入 shell 配置后重开终端" ;;
esac

echo
echo "══════════════════════════════════════════════════"
echo " 安装完成。日常使用："
echo "   searxng.sh \"查询词\"            # 精简 JSON（Agent 友好）"
echo "   searxng.sh \"查询词\" --md       # Markdown 列表（人读友好）"
echo "   searxng.sh \"!github 关键词\"    # bang 垂直检索"
echo "   searxng.sh --health            # 健康检查"
echo "   websearch-free.sh \"查询词\" -k 3   # 零成本：搜索+抓 3 篇全文*"
echo " * 需本地 Jina Reader（可选）；未部署时自动跳过全文阶段"
echo "══════════════════════════════════════════════════"
echo
echo "提示：启动日志中的 wikidata/ahmia/torch 错误是已禁用引擎的正常噪音，"
echo "判断健康以 searxng.sh --health 为准。浏览器可直接访问 $BASE_URL 当日常搜索引擎。"
