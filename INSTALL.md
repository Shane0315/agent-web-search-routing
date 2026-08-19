# web-search-routing 安装指南（v3.1）

让 Skill 在任何 harness（ChatGPT/Codex、Claude Code、Proma 等）里**开箱即用**。
核心：Skill 会自动探测环境并选择渠道；**Museon 必装 + Agent Reach 推荐装**，
首次 W3 查询时自动引导安装。

> 💡 **新用户最简路径**：只装 Museon 就能跑（W3 发现），Agent Reach 是核验增强（选装）。
> 完整 W3 体验（发现+核验）推荐两者都装。详见下方「新用户引导」。

---

## 一、快速开始（2 分钟）

```bash
# 1. 复制 Skill 到你的 harness 全局技能目录
#    Proma:      ~/.proma/default-skills/web-search-routing/
#    Codex:      ~/.codex/skills/web-search-routing/
#    Claude Code: ~/.claude/skills/web-search-routing/
#    （其他 harness 参照其 skills 目录）

# 2. 编辑 channels.yaml，删除你没装的渠道
```

装好后直接提问即可。Skill 首次触发会**自动探测**你的环境：
- 有 GPT/Claude 内置搜索 → 进入**订阅模式**（优先内置，0 额外成本）
- 没有 → 进入 **API 模式**（用你配置的免费/按量渠道）

---

## 一.5、新用户引导（第一次用，看这里）

Skill 会在你**首次提问涉及口碑/评测**时自动检测并引导。这里提前给你全景：

| 你的需求 | 最少要装 | 推荐体验 |
|---------|---------|---------|
| 只看网页/事实信息 | 什么都不用装 | +智谱/Brave（可选）|
| 要看小红书/X 真实口碑 | **Museon（必装）** | +Agent Reach（推荐）|
| 要深挖原帖评论、逐条核验 | **Museon + Agent Reach** | 完整两阶段 |

**Skill 会自动判断你缺什么，并在问答中给你对应安装命令。** 无需提前研究。

---

## 二、Museon（必选渠道）安装

> 为什么必选：搜索引擎（含 GPT/Claude 内置搜索）**抓不到小红书/X/Reddit 的原生内容**。
> W3 真实口碑（评测/体验/避雷）只有 Museon 能高质量覆盖。缺失时 Skill 会在 W3 查询时引导你安装。

```bash
# 1. 安装（需 Python 3.11+ 和 uv）
uv tool install "https://github.com/Museon-AI/museon-cli/releases/download/v0.5.3/museoncli-0.5.3-py3-none-any.whl"

# 2. 安装 Agent Skill（按你的 harness 选一个）
museoncli setup --agent claude-code   # 或 codex / proma

# 3. 授权（浏览器 OAuth，一次性）
museoncli auth start
museoncli auth finish --wait

# 4. 验证 + 保存凭证
museoncli whoami                      # 看到你的账号信息即成功
# 把返回的 API key 存到环境变量：export MUSEON_API_KEY=xxx
# 或存入 ~/.museon 配置文件
```

> 最新版本号查看：https://github.com/Museon-AI/museon-cli/releases

---

## 二.5、Agent Reach（推荐渠道，核验增强）安装

> 作用：W3 第 2 阶段「核验」——打开原帖、读取完整正文和评论、逐条区分
> 「个案 | 误解 | 已修复 | 高频共识」。与 Museon 互补：Museon 发现，Agent Reach 取证。
> 覆盖 15 平台（小红书/Reddit/X/IG/B站/YouTube/GitHub/V2EX/RSS…）。

```bash
# 1. 安装 agent-reach（15 平台多后端路由器）
#    安装指南（按官方文档执行）：
#    https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md
#    或参考 skills-manager: skillhub install agent-reach

# 2. 小红书等平台需要 Chrome 登录态（OpenCLI 桥接）
#    - 安装系统 Chrome 扩展
#    - 指定已登录小红书/Reddit 等平台的 Chrome profile

# 3. 验证
agent-reach --version
agent-reach doctor --json    # 看 xiaohongshu 的 active_backend 是否激活

# 4. 保持更新
agent-reach check-update
```

> ⚠️ 小红书通道状态为 `warn`（登录态未验证）时，核验能力受限；
> 需激活 Chrome 登录态后才能读原帖/评论。

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

### Tavily（仅 Proma）
```json
// ~/.proma/chat-tools.json
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
帮我查一下「xxx 产品真实用户评价」（评测类 → 应触发 Museon）
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

- Skill 放全局目录（如 Proma `default-skills/`）→ 所有工作区可见
- channels.yaml 跟随 Skill 目录，一份配置全 harness 生效
- MCP 配置（mcp.json）是工作区级：多工作区需复制

---

## 八、故障排查速查

| 症状 | 原因 | 处理 |
|------|------|------|
| 402 Insufficient quota | WebSearch 走云端共享池 | useCloud:false + Tavily key |
| Museon 未触发 | Skill 未重启 / channels.yaml 没标记 | 重启；确认 required:true |
| Museon 401 | OAuth 过期 | museoncli auth start 重授权 |
| Brave fetch failed | Node 不走代理 | NODE_USE_ENV_PROXY=1 + 代理 |
| 智谱 MCP 无工具 | type 配错 | type 必须 http（非 sse）|
