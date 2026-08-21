# 首次使用指南（5 分钟最小成功路径）

这份指南给第一次使用 `web-search-routing` 的用户。目标不是一次装完所有工具，而是先跑通一次真正有价值的 **W3 真实口碑搜索**。

> 最短路径：**安装 Skill → 让 Agent 自动安装 Museon（只有浏览器授权需要你点）→ 完成一次口碑查询**。Agent Reach 是第二阶段增强，用来读原帖和评论；轻量浏览器搜索只是最后兜底。

Proma 新版主路径是 `~/.proma-community/default-skills/` 和 `~/.proma-community/agent-workspaces/*/skills/`；旧 `~/.proma/default-skills/` 只作为兼容路径。

## 1. 这个 Skill 解决什么问题？

普通联网搜索常常会遇到三类问题：

1. **不知道该用哪个搜索渠道**：内置搜索、Tavily、Brave、智谱、Museon、Agent Reach 各有强弱。
2. **花钱和花上下文都不经济**：已有订阅时还调用按量 API；一次搜索塞回大量网页内容，冲淡后续推理。
3. **口碑问题搜不准**：用户真正关心的是小红书、X、Reddit 等平台上的真人体验、差评、避雷点和争议，但普通搜索引擎看到的多是 SEO 页面、聚合站或营销内容。

`web-search-routing` 是 Agent 的“搜索决策大脑”：它会先判断问题类型，再选择合适渠道组合。对于事实/时效问题，优先用低成本通用搜索；对于口碑/评测/避雷问题，启用 W3 社交口碑管线。

## 2. 为什么普通搜索不能替代 W3 口碑能力？

这里的 W3 指“真实性/口碑”维度，典型问题包括：

- “这个产品真实用户评价怎么样？”
- “有没有人提到避雷点、副作用、翻车、售后问题？”
- “小红书/X/Reddit 上大家怎么看？”
- “差评里哪些是个案，哪些是高频共识？”

普通搜索（包括 GPT/Claude 内置搜索和传统网页搜索）适合找官网、文档、新闻和公开网页，但通常不能稳定拿到社交平台原生结果，也缺少点赞、评论、收藏、作者、争议点等互动信号。

W3 管线的价值在于：

```text
Museon：高召回发现原生社交结果
  ↓ 挑出高互动、负面、争议帖
Agent Reach：读取原帖正文和评论，逐条核验
  ↓ 区分个案 / 误解 / 已修复 / 高频共识
官方文档/官网：确认价格、权益、功能事实
```

所以：

- **Museon 是 W3 核心**：没有它，就很难批量发现真实社交口碑。
- **Agent Reach 是 W3 增强**：没有它，仍能用 Museon 做发现，但核验评论和区分共识会更慢、更浅。
- **浏览器 fallback 不是同等体验**：它只能在用户拒绝安装或工具不可用时，提供低置信兜底。

## 3. 首次安装体验：你不需要复制一堆命令

### 3.1 安装 Skill

你可以直接对 Agent 说：

> 帮我安装一个 skill：web-search-routing。仓库地址 https://github.com/Shane0315/agent-web-search-routing

或手动运行：

```bash
curl -fsSL https://raw.githubusercontent.com/Shane0315/agent-web-search-routing/main/install.sh | bash
```

脚本会把 `SKILL.md`、`ONBOARDING.md`、`doctor.sh`、`install.sh`、安装辅助脚本和文档复制到正确的 Skill 目录。

### 3.2 第一次问口碑问题时会发生什么

新开会话，直接问：

```text
帮我查一下 get笔记 的真实用户评价，重点看小红书上的避雷点和高频好评。
```

Agent 应先输出简短体检报告，例如：

```text
┌ 渠道体检报告 ┐
│ 内置搜索:      ✅
│ 智谱/Brave/Tavily: ❌（可选，不阻塞口碑发现）
│ Museon:        ❌ ← W3 发现必需；我可以帮你自动安装
│ Agent Reach:   ❌ ← W3 核验增强，可后续再装
└─────────────┘
```

接着 Agent 不应直接甩给你一长串命令，而应问：

```text
这个问题需要真实社交口碑数据。当前缺少 Museon；如果不用它，我只能用普通网页搜索做低置信兜底。
如果你同意，我会自动检查 python3/uv/curl，安装官方 Museon CLI，并执行 setup/whoami；只有浏览器登录授权需要你操作。是否现在开始？
```

你回复“开始/同意”后，Agent 自动执行：

1. 检查 `python3`、`uv`、`curl` 等运行条件；缺 `uv` 时用官方脚本安装到用户目录。
2. 下载安装官方最新版 Museon CLI（当前已核实 v0.5.19）。
3. 执行 `museoncli setup --agent auto`。
4. 执行 `museoncli auth status` / `museoncli whoami`。
5. 如果需要授权，暂停并给你浏览器验证链接；**不会让你复制 device code/token/API key**。
6. 你在浏览器登录/批准后，回来告诉 Agent “继续”。
7. Agent 自动复测 `museoncli whoami`；成功后继续搜索小红书原生结果。

成功后，Agent 再说明：

```text
Museon 已可用，我可以先完成口碑发现。
如果你后续希望逐条打开原帖和评论核验，可以再安装 Agent Reach；我也会尽量自动安装，只有 Chrome 登录态/系统权限需要你操作。
```

## 4. Museon 自动安装流程

用户同意后，Agent 默认应自动执行以下流程，而不是让用户手敲：

```text
检查 python3 >= 3.11
  ↓
检查 uv；缺失则用 astral 官方脚本安装到用户目录
  ↓
uv tool install 官方 Museon wheel
  ↓
museoncli setup --agent auto
  ↓
museoncli auth status / whoami
  ↓
未授权：提示用户打开浏览器授权，然后 auth finish --wait
  ↓
用户完成后复测 whoami
```

已核实的上游信息：

- 最新 release：v0.5.19（GitHub API，发布时间 2026-08-19）。
- wheel：`https://github.com/Museon-AI/museon-cli/releases/download/v0.5.19/museoncli-0.5.19-py3-none-any.whl`。
- 官方 README 支持 `museoncli setup --agent auto`；自动检测失败时可显式使用 `codex`、`claude-code`、`cursor`，不要未经核实写死 `proma`。
- 授权状态可用 `museoncli auth status` 和 `museoncli whoami` 检查。

本 Skill 附带可重复运行的辅助脚本：

```bash
bash install-museon.sh
```

脚本会在需要 OAuth 时暂停。默认情况下，Agent 应直接调用脚本或按上述步骤执行；手动命令只作为附录。

## 5. Agent Reach：第二阶段增强

当你已经跑通 Museon，并希望进一步核验原帖评论时，再安装 Agent Reach。它负责 W3 的“核验”阶段。

用户同意后，Agent 应：

1. 检查 `agent-reach` 是否存在。
2. 未安装则按官方文档尝试用户态自动安装：
   ```text
   pipx install https://github.com/Panniantong/agent-reach/archive/main.zip
   ```
3. 自动运行只读检查：`agent-reach install --env=auto`。
4. 自动运行：`agent-reach doctor --json`。
5. 以 JSON 中的 `active_backend` 和通道状态判断可用性。
6. 只有需要 `--system` 系统级安装、Chrome/OpenCLI 扩展、Chrome 登录态、网页登录/Cookie/凭据时才暂停并明确提示用户。
7. 用户完成后自动复测 doctor，确认目标通道 `active_backend`。

本 Skill 附带：

```bash
bash install-agent-reach.sh
```

它默认只做安装和只读检查；系统级变更需要用户明确同意后再通过环境变量或命令参数启用。

官方文档确认：

- `agent-reach install --env=auto` 是默认只读依赖/通道检查。
- `--system` 会安装/配置核心外部工具，必须得到用户明确同意。
- `agent-reach doctor --json` 用于查看 active backend。
- 不存在 `agent-reach web` 这样的平台读取命令；网页/官方文档确认应使用浏览器、WebFetch 或内置网页读取工具。

## 6. 如果暂时不装 Museon / Agent Reach，会发生什么？

### 不装 Museon

对于 W3 高分问题，Agent 可以尝试用内置搜索、免费网页搜索或浏览器打开公开页面兜底，但必须明确标注：

- 这是**低置信结果**；
- 可能只覆盖 SEO 可见内容，不代表社交平台真实口碑；
- 缺少原生互动信号，无法可靠判断高频问题；
- 结论只能作为“初步线索”，不能当成完整口碑调研。

### 装了 Museon，但不装 Agent Reach

可以完成第一阶段发现：批量找到原生社交结果、互动信号和主要讨论点。限制是：

- 重点原帖的评论核验会变慢；
- 更容易把个案夸大成共识；
- 对“问题是否已修复”的判断不够稳。

### 两者都不装

只能用普通搜索或轻量浏览器 fallback。它适合事实查询，不适合核心口碑调研。Agent 必须在结论中写明局限，而不是把兜底结果包装成 W3 完整结论。

## 7. 渠道体检报告怎么读

第一次搜索时，Skill 会检查当前环境有哪些渠道可用：

```text
┌ 渠道体检报告 ┐
│ 内置搜索:  ✅/❌
│ 智谱/Brave/Tavily: ✅/❌
│ Museon:    ✅/❌  ← W3 发现必需
│ Agent Reach: ✅/❌ ← W3 核验增强
└─────────────┘
```

| 状态 | 意味着什么 | 质量影响 |
|---|---|---|
| Museon ✅ + whoami ✅ | 可以高召回发现小红书/X/Reddit 等原生社交结果 | W3 口碑搜索的基础能力已具备 |
| Museon ❌ | 无法稳定批量发现社交原生素材 | 对口碑/评测问题只能低置信兜底 |
| Agent Reach ✅ | 可以打开重点原帖、读取正文和评论 | 能区分个案、误解、已修复问题和高频共识 |
| Agent Reach ❌ | 只能依赖 Museon 摘要或手动打开少量页面 | 发现能力还在，但核验深度不足 |
| 智谱/Brave/Tavily ❌ | 普通 API 搜索渠道未配置 | 可选；不影响 Museon W3 发现 |

`bash doctor.sh --json` 的 `ok` 只在必需项缺失时为 false；可选 API 渠道和 Agent Reach 缺失会进入 `optional_missing`，不会伪装成致命错误。注意：有 warning（例如 Agent Reach 已装但小红书登录态未激活、仅检测到 npx 但 Brave key 未配置）时，`status` 可能是 `warnings` 或 `w3_ready`，但 `ok` 仍可能为 true；是否影响当前任务要看 `warnings` 和目标通道状态。

## 8. 最短验证问题

安装 Skill 后，用这个问题验证：

```text
帮我查一下 get笔记 的真实用户评价，重点看小红书上的避雷点和高频好评，并说明哪些结论置信度高。
```

通过标准：

1. 新会话触发 `web-search-routing`。
2. 首次搜索前输出渠道体检报告。
3. 若 Museon 缺失，Agent 先征求同意并尝试自动安装；只有 OAuth 步骤暂停。
4. Museon 可用后，使用 Museon 搜索原生社交结果。
5. 输出结论时区分“高置信共识 / 待核验线索 / 未覆盖内容”。
6. 如果 Agent Reach 未装，明确说明评论核验不足，而不是假装完整核验。

## 9. 手动命令参考（默认不需要）

<details>
<summary>展开手动命令</summary>

```bash
# Skill 安装
curl -fsSL https://raw.githubusercontent.com/Shane0315/agent-web-search-routing/main/install.sh | bash

# Museon（已核实 v0.5.19）
uv tool install "https://github.com/Museon-AI/museon-cli/releases/download/v0.5.19/museoncli-0.5.19-py3-none-any.whl"
museoncli setup --agent auto
museoncli auth status
museoncli auth start
museoncli auth finish --wait --timeout 60 --poll-interval 2
museoncli whoami

# Agent Reach：官方用户态路径
pipx install https://github.com/Panniantong/agent-reach/archive/main.zip
agent-reach install --env=auto
agent-reach doctor --json
# 用户明确同意系统级安装/配置后，才运行：
# agent-reach install --env=auto --system
```

</details>

## 10. 下一步

- 想了解完整安装细节：看 [`INSTALL.md`](INSTALL.md)
- 想理解 Agent 如何路由和打分：看 [`SKILL.md`](SKILL.md)
- 想调整渠道：编辑 [`channels.yaml`](channels.yaml)
