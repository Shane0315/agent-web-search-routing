---
name: web-search-routing
description: |
  联网搜索路由决策 Skill。任何 Agent 在联网搜索前都应先读本 Skill：
  探测当前 harness 可用渠道（内置订阅搜索/免费/按量）→ 7 维打分判断信息需求 →
  成本自适应选择渠道组合 → W3 社交口碑两阶段管线（Museon 发现 + Agent Reach 核验）→
  新用户自动引导安装缺失渠道 → 复杂调研用子 Agent 搜索提升质量。
  触发词：搜索/查资料/联网/口碑/评测/最新/对比/调研/web search/research。
metadata:
  version: "3.2.1"
---

# Web Search Routing

## 定位

决定联网搜索时「选哪个渠道、如何组合、如何省成本、如何保质量」。
核心原则：**能力分层（W1-W7）决定需求，成本档位（Tier0/1/2）决定渠道，环境探测决定可用性。**

> 👋 **首次使用先读 [`ONBOARDING.md`](ONBOARDING.md)**：它面向第一次上手的用户，讲清 5 分钟最小成功路径、渠道体检报告、未装 Museon/Agent Reach 的质量损失和最短验证问题。本文件是 Agent 的决策大脑；首次安装与体验引导优先链接到 ONBOARDING.md。

## 用户路径（首次使用）

```text
用户安装 Skill → 首次提问（涉及搜索）→ 触发本 Skill
  → Step 0 环境探测（自动，输出「渠道体检报告」）
  → Step 0.5 缺失引导（按 W3 需求分级，新用户必经）
  → Step 1 判断复杂度（简单→快速路径；复杂→打分）
  → Step 1.5 歧义澄清（多义词先向用户确认一句）
  → Step 2 7 维打分（W1-W7）
  → Step 3 成本自适应选渠道
  → Step 4 W3 两阶段管线（Museon 发现 → Agent Reach 核验 → 官方验证）
  → Step 5 执行（复杂调研 → 子 Agent 搜索）
  → Step 6 质量提升提示（告知用户如何增强当前 harness）
```

---

## Step 0：环境探测（首次触发必做，结果缓存）

探测当前 harness 有哪些可用渠道，决定「订阅模式 or API 模式」：

1. **Tier0 检测**：工具列表是否有 `web_search`/`web_search_exa`（GPT 订阅）或 `WebSearch`（Claude 订阅）？
   - 有 → **订阅模式**：所有查询先试内置搜索（沉没成本）
   - 无 → **API 模式**：直接从 Tier1/Tier2 选渠道
2. **已配渠道清单**：列出当前可调的 MCP 工具、CLI（如 zhipu/brave/tavily/museoncli）。
3. **社交渠道检测**（W3 关键）：
   - `museoncli whoami` 可用？→ Museon 已装且已授权。
   - `agent-reach doctor --json` 可用？→ Agent Reach 已装；再以 JSON 中的 `active_backend`/通道状态为准。
4. **运行 `bash doctor.sh` 或 `bash doctor.sh --json`**（如果本 Skill 目录中存在）。JSON 状态语义：
   - `required_missing`：缺 W3 必需 Museon；需要用户同意后自动安装。
   - `optional_missing`：缺 Tavily/Brave/智谱/Agent Reach 等增强渠道；不是 `ok=false` 的原因。
   - `warnings`：已装但授权/登录态/版本可能有问题。
   - `w3_ready`：Museon 已可用，可执行 W3 发现。
   - `ok`：基础能力齐全且无警告。
5. **输出「渠道体检报告」**（简短表格，告知用户当前能力与缺口；**每个 ❌ 后跟一行白话解读**）。

```text
┌ 渠道体检报告 ┐
│ 内置搜索:  ✅/❌ (订阅/API 模式)         → 有订阅就优先用它，不用额外花钱
│ 智谱/Brave/Tavily: ✅/❌                 → 中文/英文普通网页搜索；缺失不阻塞 W3
│ Museon:    ✅/❌  ← W3 发现必需          → ❌=搜不到小红书真实评论，我可以帮你自动安装
│ Agent Reach: ✅/❌ ← W3 核验增强          → ❌=口碑只能看标题摘要，后续可增强
│            （小红书登录态: 已激活/未激活）
└─────────────┘
```

> **白话解读原则**：报告不是给工程师看的清单。每行 ❌ 都要跟一句「缺什么 → 装它有什么好处/我会代办什么」，避免 W3/Tier/harness 等术语轰炸。

## Step 0.5：缺失引导与自动安装（新用户必经）

**给新用户的安装引导原则：Museon 先跑通，Agent Reach 作为第二阶段增强；不硬性要求一次全装，避免劝退。**

最小成功路径是：**安装 Skill → Agent 自动安装并授权 Museon → 完成一次 W3 查询**。Museon 负责高召回发现原生社交结果，是 W3 口碑能力的最小必要集；Agent Reach 负责继续读原帖/评论做核验，属于增强层。

### 自动安装原则（必须遵守）

用户同意安装 Museon 或 Agent Reach 后，**不要把一串命令丢给用户让用户自己一步步执行**。Agent 应自动执行可静默完成的检查/下载/安装/校验；只有浏览器 OAuth、网页登录、Chrome 登录态、用户填写个人凭据/权限确认时才暂停提示。

### Museon 自动安装流程

当问题含 W3 且 Museon 缺失或未授权时：

1. 先告知能力缺口并征求同意：“是否让我自动安装 Museon？只有浏览器授权需要你点一下。”
2. 用户同意后，Agent 自动检查 `python3`、`uv`、`git`、`curl` 是否存在：
   - 缺 `uv` 且可用户态安装：运行官方安装脚本 `curl -LsSf https://astral.sh/uv/install.sh | sh`（或 wget 等价方式）。
   - 缺 `python3`、版本低于 3.11、缺网络工具或需要系统权限：暂停并说明需要用户安装/授权什么，不要编造替代命令。
3. 自动安装官方最新版 Museon CLI。当前已核实最新 release 为 **v0.5.19**（发布时间 2026-08-19），wheel：
   ```text
   https://github.com/Museon-AI/museon-cli/releases/download/v0.5.19/museoncli-0.5.19-py3-none-any.whl
   ```
   也可直接运行本 Skill 目录中的 `bash install-museon.sh`。它会使用 `uv tool install <wheel>`，可重复运行。
4. 自动执行 `museoncli setup --agent auto`。不要未经核实写死 `proma`：官方支持 `auto`、`codex`、`claude-code`、`cursor`、`all`；如果 `auto` 未识别当前 Agent，再按输出说明显式选择或提示该 harness 的持久 Skill 安装限制。
5. 自动执行 `museoncli auth status` / `museoncli whoami` 判断授权状态。
6. 只有未授权时暂停，并把 `museoncli auth start` 返回的验证 URL/提示清晰展示给用户；不要暴露 device code、token、API key。然后运行 `museoncli auth finish --wait --timeout 60 --poll-interval 2` 等待批准。
7. 用户完成浏览器登录/批准并回来说“继续”后，Agent 自动复测 `museoncli whoami`；成功后继续搜索。
8. 如果授权超时，不要重新开始，除非当前授权已过期/拒绝/已使用；继续等待同一轮授权即可。

### Agent Reach 自动安装流程

当用户需要原帖/评论核验且同意增强时：

1. Agent 先检查 `agent-reach` 是否存在。
2. 未安装时，按官方文档优先使用用户态安装：
   ```text
   pipx install https://github.com/Panniantong/agent-reach/archive/main.zip
   ```
   也可运行本 Skill 目录中的 `bash install-agent-reach.sh`。若遇到 Homebrew/PEP 688 externally-managed 环境，脚本会优先用 pipx/uvx；不要使用 sudo。
3. 自动运行只读检查 `agent-reach install --env=auto`。
4. 自动运行 `agent-reach doctor --json`，以输出中的 `active_backend`/状态为准。
5. **只有以下情况才打断用户**：需要 `--system` 系统级安装、Chrome/OpenCLI 扩展、Chrome 登录态、网页登录/Cookie/凭据、或 doctor 明确要求权限。系统级命令 `agent-reach install --env=auto --system` 必须在用户明确同意后才运行；可选通道通过 `--channels=<官方文档确认的通道名>` 指定。
6. 用户完成后，Agent 自动复测 `agent-reach doctor --json`，确认目标通道 `active_backend`。

### 引导强度

| 场景 | 引导内容 |
|------|---------|
| 含 W3（口碑/评测/避雷）且 **Museon 未装/未授权** | 🔴 **先告知能力缺口，再请求同意自动安装**：明确说明没有 Museon 时只能做低置信兜底，不能假装完成口碑调研；用户同意后 Agent 自动检查/安装/校验，只有 OAuth 暂停 |
| 含 W3 且 Museon 已装、**Agent Reach 未装** | 🟡 **可先跑通，再推荐增强**：先用 Museon 完成发现；说明需要逐条核验原帖评论时，Agent 可继续自动安装 Agent Reach，系统/登录步骤才提示 |
| 含 W3 且两者都装 | 🟢 无需安装引导，直接走 Step 4 完整管线；必要时处理登录态 warning |
| 不含 W3 | ⚪ 无需社交渠道引导，正常走 Step 1-3 |

**引导话术模板**（Agent 向用户输出）：

```text
此问题需要「真实社交口碑」数据。当前体检结果：
  - Museon（发现）: 已装/未装/未授权
  - Agent Reach（核验）: 已装/未装，小红书登录态: 已激活/未激活

如果 Museon 未装：我现在只能用内置搜索/普通网页搜索/浏览器做低置信兜底，结果可能只覆盖 SEO 页面和少量公开摘要，不能代表小红书/X/Reddit 的真实口碑。
如果你同意，我会自动检查 python3/uv/curl，下载安装官方 Museon CLI，并执行 setup 和 whoami；只有浏览器登录授权需要你操作。是否现在开始？

如果 Museon 已装、Agent Reach 未装：我可以先用 Museon 跑通口碑发现；若需要逐条核验原帖评论，我再自动安装 Agent Reach，只有 Chrome 登录态/系统权限需要你确认。
```

**用户拒绝安装时的执行规则**：可以继续用内置搜索、免费网页搜索或轻量浏览器 fallback，但必须在开头和结论中写明这是**低置信兜底**，不是完整 W3 口碑调研。

<details>
<summary>手动命令参考（默认不需要用户复制；仅在自动脚本不可用或调试时使用）</summary>

```bash
# Museon：已核实 v0.5.19 为 2026-08-19 最新 release
uv tool install "https://github.com/Museon-AI/museon-cli/releases/download/v0.5.19/museoncli-0.5.19-py3-none-any.whl"
museoncli setup --agent auto
museoncli auth status
museoncli auth start
museoncli auth finish --wait --timeout 60 --poll-interval 2
museoncli whoami

# Agent Reach：官方文档路径；agent-reach install --env=auto 默认只读
pipx install https://github.com/Panniantong/agent-reach/archive/main.zip
agent-reach install --env=auto
agent-reach doctor --json
# 用户明确同意系统级变更后，才运行：
# agent-reach install --env=auto --system
# 可选通道名以官方文档为准，例如 opencli,xiaohongshu。
```

</details>

---

## Step 1：两级流程

- **简单任务**（单事实/单语言/单维度主导）：直接用默认渠道搜一次，**不打分**。
  - 订阅模式：GPT/Claude 内置搜索一次。
  - API 模式：Tier1 免费渠道（Tavily 英文/Brave 英文/智谱中文）一次。
- **复杂任务**（多对比/多视角/多语言/YMYL 敏感话题/含 W3 口碑）：走完整打分。

## Step 1.5：歧义澄清（打分前必查）

搜索词可能有多重含义（产品名 vs 动作、专有名词 vs 缩写、同名概念）。**打分前先自查一次**，满足任一条件就先向用户确认一句，不要凭猜打分：

- 含产品名/专有名词，且可能是动作或普通名词（如「get 笔记」→ 是某个笔记产品，还是「获取笔记」？）
- 含缩写/首字母词（AIGC、RAG、SSR…）
- 同一句话里混了多个主题/对象
- 词同时可作动词与名词（run、clip、prompt…）

**澄清话术**（一句话，不打断节奏）：
> 你问的「X」是指 A 还是 B？（或：你是指产品 X，还是动作 X？）

用户确认后再进入 Step 2 打分；若词义明确则跳过本步，不额外打扰。

## Step 2：7 维打分（0=无关 / 1=弱 / 2=中 / 3=核心）

| 维度 | 含义 | 高分信号 |
|------|------|---------|
| W1 事实性 | 客观事实/数据 | 是什么/多少/日期/价格/规格 |
| W2 时效性 | 最新/实时 | 最新/最近/本周/趋势/发布 |
| W3 真实性/口碑 | 真人体验/评价 | 体验/评价/好用吗/避雷/推荐 |
| W4 深度/专业 | 专业分析/文档 | 原理/报告/对比/评测/白皮书 |
| W5 中文生态 | 国内语境 | 中文关键词/国内产品/中文社区 |
| W6 英文生态 | 国际语境 | 英文关键词/海外技术/英文社区 |
| W7 来源可信度 | 权威/官方来源 | 官方/权威/政府/论文/官网 |

## Step 3：成本自适应选渠道（读 channels.yaml）

按「覆盖能力 + 成本最低」组合：

1. **订阅模式**：先 Tier0 内置（0 成本）→ 缺 W3 才看 Museon → 内置不足再看 Tier1。
2. **API 模式**：从 Tier1 免费渠道选能覆盖高分维度的 → 不足再 Tier2 按量。
3. **组合规则**：得分≥2 的维度映射到渠道 → 去重 → 最小必要集；**不默认全上**。

```text
示例（API 模式，中文事实+口碑查询）：
  W1=3 W3=3 W5=3
  → 智谱（W1/W5，中文事实） + Museon（W3，社交口碑）
示例（订阅模式，英文对比查询）：
  W1=2 W4=2 W6=3
  → GPT 内置搜索（一次）→ 不足再 Brave（Tier1）
```

## Step 4：W3 社交口碑 —— 两阶段管线（v3.2 核心）

**W3 不是单一工具能完成的，需要「发现 + 核验 + 确认」三阶段。** 社交搜索排序差异大，不能只看排名——需要先广搜（发现候选），再深读（核验真伪），最后确认（区分个案与事实）。

### 第 1 阶段：发现（Museon 主搜，高召回）

**作用**：原生 API/CLI，首轮信息密度高（标题/摘要/赞/评/藏/作者/链接）。
**产出**：候选列表 + 互动信号，快速判断“大家在讨论什么、有哪些风险信号”。

```bash
# 命令以本机 museoncli 的实时帮助/schema 为准；这是常见入口示例。
museoncli research +social-media-search --platform xhs --intent keyword-search \
  --query "<关键词>" --limit 10
```

**选篇标准**：按「高互动（赞/评/藏）+ 负面主题 + 争议点」挑 5-10 篇进入第 2 阶段。

### 第 2 阶段：核验（Agent Reach 取证，读原帖/评论）

**作用**：Agent Reach 是选择器/健康检查/路由器，不是平台命令包装器。先运行：

```bash
agent-reach doctor --json
```

然后根据 JSON 中目标平台的 `active_backend` 调用对应上游工具（如 `opencli`、`twitter`、`bili`、`yt-dlp`、`gh`、`mcporter` 等）。**不要编造 `agent-reach web` 或平台子命令**；平台命令必须来自 `agent-reach doctor --json`、官方文档或上游工具自身帮助。

**核验要点**：每条差评要判断是真实问题、用户误解、还是已修复——避免把用户体验线索当成已证实事实。

### 第 3 阶段：确认（官方文档/产品实测）

涉及价格、权益、条款、功能是否变更时，用浏览器/WebFetch/内置网页读取工具打开官方文档或官网确认；不要编造 `agent-reach web`。

### W3 强度 → 阶段深度映射

| W3 得分 | 阶段选择 |
|---------|---------|
| W3=3（核心口碑调研，如“产品避雷点”）| 完整三阶段（Museon → Agent Reach → 官方）|
| W3=2（一般口碑，如“顺带看评价”）| Museon 发现 + 浏览器快速核验（不强制 Agent Reach）|
| W3≤1 | 不走社交管线，用普通搜索 |

### 未装工具时的降级（不静默，明确告知）

| 缺哪个 | 降级方案 | 质量影响 |
|--------|---------|---------|
| 缺 Museon | 先用内置搜索/普通网页搜索；必要时浏览器打开公开搜索页 | ⚠️ **只能低置信兜底**：无法批量抓取原生数据，不能声称完成 W3 口碑调研 |
| 缺 Agent Reach | Museon 发现 + 浏览器手动打开重点原帖，或只输出发现结论 | ⚠️ 核验变慢，评论读取受限；结论需标注“未完成原帖/评论核验” |
| 两者都缺 | 内置搜索/浏览器直接搜 | ❌ 仅 SEO 可见内容，口碑质量低；只能给初步线索 |

**价值论证**：

> 你自己打开小红书/浏览器搜索：只能看到前几页、无法批量分析、看不到点赞/评论/收藏/作者等互动数据。
> 装 Museon 后：一次能搜 10+ 条原生结果，带完整互动信号，可批量分析「大家在讨论什么、有没有避雷点」。
> Agent Reach 同理：装后能打开原帖逐条核验，把「个案」和「高频共识」分清楚。

---

## Step 5：执行策略 —— 子 Agent 搜索（省上下文 + 提质量）

搜索结果全文会占用主 Agent 上下文（一次搜索可能 10k+ tokens），稀释后续推理。**复杂调研必须用子 Agent 搜索**：

| 场景 | 主 Agent 直接搜 | 子 Agent 搜+总结 |
|------|---------------|-----------------|
| 简单查询（单工具一次） | ✅ 快 | ❌ 没必要 |
| 复杂调研（多维度/多工具/多语言） | ❌ 上下文爆炸 | ✅ **必须** |
| W3 口碑调研（Museon 返回大量原生数据） | ❌ 数据过多 | ✅ **强烈建议** |

**子 Agent 用法**：

```text
主 Agent 委派子 Agent（role: research）
  子 Agent 任务说明（自包含）：
    - 搜索意图 + 7 维打分结果
    - 指定渠道（按 Step 3 决策）与阶段（Step 4 两阶段管线）
    - 总结要求：结论 + 关键来源 + 置信度 + 数据要点
  子 Agent 自己完成：探测→打分→选渠道→搜索→提炼
  子 Agent 返回：仅总结（几百 token）
主 Agent 用总结继续推理（上下文干净）
```

---

## Step 6：质量提升提示（主动告知用户）

完成搜索后，若发现当前 harness 有提质空间，主动告知：

- **缺 Museon**：W3 类问题质量受限 → 请求同意后自动安装。
- **Museon 未授权**：只在 OAuth 步骤提示用户，完成后自动复测。
- **缺 Agent Reach**：口碑核验不充分 → 请求同意后自动安装基础版；系统/登录步骤才提示。
- **Agent Reach 小红书登录态未激活**：无法读原帖/评论 → 引导激活 Chrome 登录态/OpenCLI。
- **缺 Tier1 免费渠道**：中文/英文质量不足 → 建议配智谱/Brave/Tavily（可选）。
- **订阅模式未用足**：提示 GPT/Claude 内置搜索是沉没成本，应优先使用。
- **结果仍不满意**：建议切换更高质量渠道或使用浏览器精读。

---

## 渠道注册表

所有渠道定义、能力覆盖、成本档位、安装方式见 **`channels.yaml`**（本 Skill 同目录）。用户编辑此文件即可增删渠道，无需改 SKILL.md 逻辑。

## Proma 路径说明

- Proma 新版主路径：`~/.proma-community/default-skills/` 和 `~/.proma-community/agent-workspaces/*/skills/`。
- 旧路径 `~/.proma/default-skills/` 仅作为历史兼容，不作为新装主路径。

## 省成本原则

1. 订阅模式：Tier0 内置优先（沉没成本，边际≈0）。
2. API 模式：Tier1 免费优先，Tier2 按量兜底。
3. 组合克制：只调覆盖高分维度的渠道，不做“全上”。
4. 控制结果量：限制返回数量、优先摘要、避免整页抓取。
5. 子 Agent 搜索：复杂调研让子 Agent 消化，主 Agent 只收总结。
6. 两阶段按需：W3=2 不强制 Agent Reach（省时）；W3=3 才完整三阶段。

## 故障排查速查

| 症状 | 原因 | 处理 |
|------|------|------|
| 402 Insufficient quota | WebSearch 走了云端共享池 | useCloud:false + Tavily key |
| 智谱 MCP 无工具 | 未重启 / type 配错 | 重启；type 必须 http |
| Brave fetch failed | Node 不走代理或仅有 npx 但未配置 key/MCP | 配置 BRAVE_API_KEY + Brave MCP；必要时 NODE_USE_ENV_PROXY=1 |
| Museon 401 / whoami 失败 | OAuth 过期或未授权 | `museoncli auth status/start/finish --wait`，授权后复测 whoami |
| Agent Reach command not found | CLI 未装 | 经用户同意后按官方 pipx/zip 自动安装 |
| Agent Reach 小红书 warn | 登录态/OpenCLI 未激活 | 以 `doctor --json` 输出为准，完成 Chrome/OpenCLI 登录后复测 |
| 子 Agent 搜索无结果 | 渠道缺失或命令过期 | 检查 doctor、官方文档和 CLI 实时帮助，不要猜命令 |
