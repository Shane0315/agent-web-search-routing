# web-search-routing 安装指南（v3.5.0）

让 Skill 在任何 harness（ChatGPT/Codex、Claude Code、Proma 等）里**开箱即用**。
核心：Skill 会自动探测环境并选择渠道；**Museon 必装 + Agent Reach 推荐装**，
首次 W3 查询时自动引导安装。

> 💡 **新用户最简路径**：先看 [`ONBOARDING.md`](ONBOARDING.md)。只装 Museon 就能跑通 W3 发现；Agent Reach 是第二阶段核验增强（选装）。
> 完整 W3 体验（发现+核验）推荐两者都装，但不要第一次就给自己一次性安装压力。

---

## 一、快速开始（2 分钟）

**方式 A：让 AI 帮你装（推荐）**——直接对你的 Agent 说：

> 帮我安装一个 skill：web-search-routing。仓库地址 https://github.com/Shane0315/agent-web-search-routing

**方式 B：一键脚本**

```bash
curl -fsSL https://raw.githubusercontent.com/Shane0315/agent-web-search-routing/main/install.sh | bash
```

脚本自动探测 Codex / Claude Code / Proma 并复制到对应全局技能目录。

**方式 C：手动复制**

```bash
# 1. 复制 Skill 到你的 harness 全局技能目录
#    Proma 新版（推荐）: ~/.proma-community/default-skills/web-search-routing/
#    Proma 新版工作区级: ~/.proma-community/agent-workspaces/<workspace>/skills/web-search-routing/
#    Codex:             ~/.codex/skills/web-search-routing/
#    Claude Code:       ~/.claude/skills/web-search-routing/
#    旧版 Proma（仅兼容）: ~/.proma/default-skills/web-search-routing/
#    （其他 harness 参照其 skills 目录）

# 2. 编辑 channels.yaml，删除你没装的渠道
```

装好后直接提问即可。Skill 首次触发会**自动探测**你的环境：
- 有 GPT/Claude 内置搜索 → 进入**订阅模式**（优先内置，0 额外成本）
- 没有 → 进入 **API 模式**（用你配置的免费/按量渠道）

---

## 一.5、新用户引导（第一次用，看这里）

首次使用建议直接看 [`ONBOARDING.md`](ONBOARDING.md)，按“安装 Skill → 只装 Museon → 完成一次 W3 查询”的顺序跑通。

Skill 会在你**首次提问涉及口碑/评测**时自动检测并引导。这里提前给你全景：

| 你的需求 | 最少要装 | 推荐体验 |
|---------|---------|---------|
| 只看网页/事实信息 | 什么都不用装 | +智谱/Brave（可选）|
| 要看小红书/X 真实口碑 | **Museon（先装，先跑通）** | +Agent Reach（第二阶段推荐）|
| 要深挖原帖评论、逐条核验 | **Museon + Agent Reach** | 完整发现 + 核验 |

**Skill 会自动判断你缺什么；你同意后，Agent 会尽量自动完成安装和校验。** 只有浏览器 OAuth、网页登录、Chrome 登录态或系统权限确认需要你亲自操作。

---

## 二、Museon（必选渠道）安装

> 为什么必选：搜索引擎（含 GPT/Claude 内置搜索）**抓不到小红书/X/Reddit 的原生内容**。
> W3 真实口碑（评测/体验/避雷）只有 Museon 能高质量覆盖。缺失时 Skill 会在 W3 查询时引导你安装。

默认不需要手动复制下面这些命令。用户同意安装后，Agent 应先自动检查 `python3`/`uv`/网络工具，再安装官方 Museon CLI、执行 `setup` 和 `whoami`；只有浏览器 OAuth 授权需要用户操作。也可以直接运行本 Skill 附带的幂等脚本：

```bash
bash install-museon.sh
```

手动命令参考：

```bash
# 1. 安装（需 Python 3.11+ 和 uv）
MUSEON_VERSION=0.5.19
uv tool install "https://github.com/Museon-AI/museon-cli/releases/download/v${MUSEON_VERSION}/museoncli-${MUSEON_VERSION}-py3-none-any.whl"

# 2. 安装 Agent Skill（优先 auto；不要未经核实写死 proma）
museoncli setup --agent auto

# 3. 授权（浏览器 OAuth，一次性）
museoncli auth status
museoncli auth start
museoncli auth finish --wait --timeout 60 --poll-interval 2

# 4. 验证
museoncli whoami                      # 看到账号信息即成功
```

> 最新版本号查看：https://github.com/Museon-AI/museon-cli/releases。当前文档已核实 v0.5.19。

---

## 二.5、Agent Reach（推荐渠道，核验增强）安装

> 作用：W3 第 2 阶段「核验」——打开原帖、读取完整正文和评论、逐条区分
> 「个案 | 误解 | 已修复 | 高频共识」。与 Museon 互补：Museon 发现，Agent Reach 取证。
> 覆盖 15 平台（小红书/Reddit/X/IG/B站/YouTube/GitHub/V2EX/RSS…）。

```bash
# 1. 先做只读依赖与通道检查（官方文档确认可用）
agent-reach install --env=auto
agent-reach --version
agent-reach doctor --json    # 看可用 backend、通道状态和后续命令提示

# 2. 完整安装指南（按官方文档执行）：
#    https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md
#    需要系统级安装/启用通道时，再按 doctor 输出选择，例如：
#    agent-reach install --env=auto --system --channels=<doctor 或官方文档确认的通道名>

# 3. 小红书等平台可能需要 Chrome 登录态（OpenCLI 桥接）
#    - 安装官方要求的 Chrome 扩展
#    - 使用已登录小红书/Reddit 等平台的 Chrome profile
#    - 不要让 Agent 编造 opencli 子命令；以 doctor 输出和官方文档为准

# 4. 保持更新
agent-reach check-update
```

> ⚠️ 小红书通道状态为 `warn`（登录态未验证）时，核验能力受限；
> 需激活 Chrome 登录态后才能读原帖/评论。

---

## 二.7、SearXNG 本地自建（可选渠道，v3.4 新增：零成本通用搜索）

> 作用：Tier1 内最优先的通用搜索渠道——**$0、无额度上限、无 API Key、本地运行**。
> 适合频繁搜索、反复撞 Tavily/Firecrawl/Brave 月度免费额度的用户。聚合 Google/Bing/
> 百度/360/Wikipedia + GitHub/StackOverflow/arXiv 垂直引擎，还支持 bang 垂直检索
> （`!github` `!so` `!arxiv`——其他渠道做不到）。
>
> ⚠️ **纯可选**：不装它不影响 Skill 任何现有路径，只是多用一点额度。新用户建议先跑通
> Museon（W3）主线，额度真紧张了再来装这个。它也**不能替代** Museon + Agent Reach 的
> 社交口碑能力。

**一键安装（推荐让 Agent 代跑，全程无人值守）**：

```bash
bash install-searxng.sh
```

脚本自动完成：clone 源码（~/searxng-src）→ uv venv（Python 3.12）→ 写配置
（开 JSON API + 关 limiter + 随机 secret key）→ launchd 自启（崩溃自动拉起）→
安装 `searxng.sh` / `websearch-free.sh` 封装 → 健康验证。可重复运行（幂等）。

网络环境差异：

```bash
bash install-searxng.sh --no-proxy                        # 海外直连网络
bash install-searxng.sh --proxy http://127.0.0.1:7890     # 国内代理（自动探测失败时指定）
```

装完即可用（无需改 channels.yaml，Skill 按探测结果自动路由）：

```bash
searxng.sh "查询词"            # 精简 JSON（Agent 友好）
searxng.sh "查询词" --md       # Markdown 列表（人读友好）
searxng.sh "!github searxng"   # bang 垂直检索
searxng.sh --health            # 健康检查
websearch-free.sh "查询词" -k 3  # 零成本「搜索+拓3篇全文」；需本地 Jina Reader（可选）
```

> 💡 脚本已处理三个文档没写的坑：① 上游默认 `formats` 只有 html，必须显式加 `json`；
> ② `limiter` 必须关，否则 API 被 403/429；③ SearXNG 内部用 httpx **不读 HTTP_PROXY
> 环境变量**，代理必须写进 settings.yml 的 `outgoing.proxies`（国内网络必踩，否则所有引擎超时）。
>
> 启动日志里的 `wikidata 403` / `ahmia/torch loading failed` 是已禁用引擎的正常噪音，
> 判断健康以 `searxng.sh --health` 为准。浏览器可直接开 http://127.0.0.1:8888 当日常搜索引擎。

---

## 二.8、AnySearch 垂直域检索（可选渠道，v3.5 新增）

> 作用：带结构化标识符的查询直取权威数据库原始记录——CVE → OSV/NVD，DOI → Crossref/
> OpenCitations，医学文献 → PubMed（支持 MeSH 字段限定），代码 → 100 万+ GitHub 仓正则检索。
> 共 16 个垂直域，另具备其他渠道都没有的 `batch_search` 并行能力。
>
> ⚠️ **纯可选**：不装不影响任何现有路径。它**不是 Tavily 的替代品**（泛搜索无优势），
> 也**不能代替 Museon**（不支持小红书）。只在带标识符的查询上不可替代。

### 推荐安装方式：系统级统一目录 + 软链

多 harness 环境下（Codex + Claude + Proma 共存），每个目录各放一份副本会引发**版本漂移**：
升级时容易只改到一份，其他 harness 用的还是老版。推荐只维护一份权威副本，其余全用软链：

```bash
# 1. 下载 pinned release（勿用 main 分支；把 v3.1.1 换成最新 tag）
cd /tmp
curl -fsSL -o anysearch.tar.gz \
  https://github.com/anysearch-ai/anysearch-skill/archive/refs/tags/v3.1.1.tar.gz
tar -xzf anysearch.tar.gz && cd anysearch-skill-3.1.1

# 2. 校验完整性（应全部 OK；它会持有你的 API key，这步不要略）
shasum -a 256 -c SHA256SUMS.txt

# 3. 装到系统级统一目录
mkdir -p ~/.agents/skills/anysearch
cp -R ./* ~/.agents/skills/anysearch/

# 4. 各 harness 用软链指向（已验证可被正常加载）
for d in ~/.claude/skills ~/.codex/skills \
         ~/.proma-community/default-skills ~/.proma/default-skills; do
  [ -d "$d" ] && ln -sfn ~/.agents/skills/anysearch "$d/anysearch"
done
```

> 💡 同样的统一目录 + 软链方式也适用于本 Skill 自身，可以彻底避开多份副本版本不一致。

### 探测 runtime 并写入 runtime.conf

优先级 **Python（需 requests）> Node.js（零依赖）> shell（需 jq + curl）**。
写入 `runtime.conf` 后 Agent 就不用每次重探：

```bash
# 例：系统 python3 没有 requests、但有 Node 时，选 Node 最干净
cat > ~/.agents/skills/anysearch/runtime.conf <<'EOF'
Runtime=Node.js
Command=node /Users/<你的用户名>/.agents/skills/anysearch/scripts/anysearch_cli.js
EOF
```

### 验证

```bash
CLI="node ~/.agents/skills/anysearch/scripts/anysearch_cli.js"
$CLI search "hello world" --max_results 1      # 匹名即可，无需 API key
$CLI get_sub_domains --domain security          # 垂直搜索前必调
$CLI search "CVE-2024-3094" --tag security.vuln --params 'type=cve,value=CVE-2024-3094'
```

### API Key（可选，仅提升频限）

匹名访问已可用（实测 6 连发未触限）。需更高频限时去 https://anysearch.com/console/api-keys
注册，写入 `~/.agents/skills/anysearch/.env`：

```text
ANYSEARCH_API_KEY=<your_key>
```

> ⚠️ 搜索词、提取的 URL 和 API key 都会发往 `https://api.anysearch.com`。
> 官方声称 zero retention / no logging，但涉密查询请自行评估后使用。

### 实测坑

| 现象 | 原因 | 处理 |
|---|---|---|
| `Unknown flag: xxx` | `--params` 值含空格未加引号 | 整体加单引号 |
| 后端校验失败 | 漏传 `(required)` 参数 | 不适用也要传空值，如 `cn_code=` |
| 小红书搜不到 | **不支持小红书**，静默降级 | 改用 Museon |
| 输出刷爆上下文 | 垂直/社交模式本身很重 | 降 `--max_results`，批量查询走子 Agent |

---

## 三、渠道配置（按用户类型）

### 订阅制用户（有 ChatGPT/Claude 订阅）

你的内置搜索已是 Tier0（沉没成本，边际≈0）。只需补：

| 渠道 | 必要性 | 用途 |
|------|--------|------|
| **Museon** | ⭐ 必选 | W3 发现（社交口碑原生数据） |
| **Agent Reach** | 推荐 | W3 核验（读原帖/评论）+ 15 平台广度 |
| Kimi WebBridge（可选）| 免费 | 浏览器兜底/降级 |
| 智谱/Brave/Tavily（可选）| 按需 | 内置搜索不足时才需要 |

> 订阅模式：Skill 会先白嫖内置搜索，W3 才调 Museon，人民币边际成本≈0。

### API 按量付费用户（无订阅）

需要自配渠道，Skill 会按「免费优先 → 按量兜底」路由：

| 渠道 | 成本 | 用途 | 优先级 |
|------|------|------|--------|
| Tavily | 1000 credits/月免费 | 英文事实/通用 | 免费首选 |
| Brave | $5/月免费 | 英文/深度 | 免费次选 |
| 智谱 | 0.01-0.05元/次 | 中文事实/深度 | 中文首选 |
| **Museon** | $0 免费档 | **W3 社交口碑** | ⭐ 必选 |
| Kimi WebBridge | 免费 | 浏览器兜底 | 兜底 |

各渠道具体配置（mcp.json / chat-tools.json / 代理）见下节。

---

## 四、各渠道详细配置

### Tavily（Proma）
```json
// 新版 Proma 常见路径：~/.proma-community/chat-tools.json
// 旧版兼容路径：~/.proma/chat-tools.json
{ "toolCredentials": { "web-search": { "useCloud": "false", "apiKey": "tvly-你的Key" } } }
```
注册：https://app.tavily.com

### 智谱 Web Search（MCP，type 必须 http）
```json
// mcp.json
{ "servers": { "zhipu-web-search": {
  "type": "http",
  "url": "https://open.bigmodel.cn/api/mcp-broker/proxy/web-search/mcp?Authorization=你的智谱Key",
  "enabled": true } } }
```
注册：https://open.bigmodel.cn

### Brave Search（MCP，需代理）
```json
// mcp.json
{ "servers": { "brave-search": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@brave/brave-search-mcp-server", "--transport", "stdio"],
  "env": {
    "BRAVE_API_KEY": "BSA你的Key",
    "NODE_USE_ENV_PROXY": "1",
    "HTTPS_PROXY": "http://<你的代理地址>",
    "HTTP_PROXY": "http://<你的代理地址>",
    "ALL_PROXY": "http://<你的代理地址>" } } } }
```
注册：https://api-dashboard.search.brave.com/register
> 代理地址改成你自己的；海外直连可省略代理变量。

---

## 五、验证

新会话提问测试：
```text
帮我查一下 get笔记 的真实用户评价，重点看小红书上的避雷点和高频好评
```
预期：
- 首次触发 → Skill 探测环境
- 缺 Museon → 引导你安装（按上文第二节）
- 装好后 → 用 Museon 搜小红书/X 原生口碑 + 内置/免费渠道补充

再测一个事实类：
```text
2026 年最新 iPhone 发布了吗
```
预期：订阅模式走内置搜索；API 模式走 Tavily/Brave（免费）。

---

## 六、质量提升（主动做）

Skill 会在搜索后提示你的环境短板，常见优化：
1. **装 Museon** → W3 口碑质量大幅提升（必选，最优先）
2. **配智谱** → 中文深度报告质量提升
3. **配 Brave** → 英文深度质量提升
4. **复杂调研用子 Agent** → Skill 自动委派，减少主上下文占用

---

## 七、多工作区/多 harness

- Proma 新版全局目录：`~/.proma-community/default-skills/` → 所有工作区可见
- Proma 新版工作区目录：`~/.proma-community/agent-workspaces/<workspace>/skills/` → 仅该工作区可见
- `~/.proma/default-skills/` 仅作为旧版兼容；新装优先使用 `~/.proma-community/`
- channels.yaml 跟随 Skill 目录，一份配置随该安装副本生效
- MCP 配置（mcp.json）是工作区级：多工作区需复制

安装后可运行：

```bash
bash doctor.sh          # 人类可读体检报告
bash doctor.sh --json   # 机器可读 JSON
```

---

## 八、故障排查速查

| 症状 | 原因 | 处理 |
|------|------|------|
| 402 Insufficient quota | WebSearch 走云端共享池 | useCloud:false + Tavily key |
| Museon 未触发 | Skill 未重启 / channels.yaml 没标记 | 重启；确认 required:true |
| Museon 401 | OAuth 过期 | museoncli auth start 重授权 |
| Brave fetch failed | Node 不走代理 | NODE_USE_ENV_PROXY=1 + 代理 |
| 智谱 MCP 无工具 | type 配错 | type 必须 http（非 sse）|
