---
name: web-search-routing
description: |
  联网搜索路由决策 Skill。任何 Agent 在联网搜索前都应先读本 Skill：
  探测当前 harness 可用渠道（内置订阅搜索/免费/按量）→ 7 维打分判断信息需求 →
  成本自适应选择渠道组合 → W3 社交口碑两阶段管线（Museon 发现 + Agent Reach 核验）→
  新用户自动引导安装缺失渠道 → 复杂调研用子 Agent 搜索提升质量。
  触发词：搜索/查资料/联网/口碑/评测/最新/对比/调研/web search/research。
metadata:
  version: "3.5.0"
---

# Web Search Routing

## 定位

决定联网搜索时「选哪个渠道、如何组合、如何省成本、如何保质量」。
核心原则：**能力分层（W1-W8）决定需求，成本档位（Tier0/1/2）决定渠道，环境探测决定可用性。**

> 👋 **首次使用先读 [`ONBOARDING.md`](ONBOARDING.md)**：它面向第一次上手的用户，讲清 5 分钟最小成功路径、渠道体检报告、未装 Museon/Agent Reach 的质量损失和最短验证问题。本文件是 Agent 的决策大脑；首次安装与体验引导优先链接到 ONBOARDING.md。

## 用户路径（首次使用）

```text
用户安装 Skill → 首次提问（涉及搜索）→ 触发本 Skill
  → Step 0 环境探测（自动，输出「渠道体检报告」）
  → Step 0.5 缺失引导（按 W3 需求分级，新用户必经）
  → Step 1 判断复杂度（简单→快速路径；复杂→打分）
  → Step 1.5 歧义澄清（多义词先向用户确认一句）
  → Step 2 8 维打分（W1-W8）
  → Step 3 成本自适应选渠道（v3.4：searxng-local 可用时 Tier1 首选；经验类：社交原生首发）
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
4. **零成本自建渠道检测**（v3.4，可选增强，不阻塞任何路径）：
   - `~/.local/bin/searxng.sh --health` 输出 ✅，或 `curl -m 5 --noproxy '*' 'http://127.0.0.1:8888/search?q=ping&format=json'` 返回 200？→ SearXNG 本地实例可用，进入 Tier1 首选。
   - 不可用 → 记为 `optional_missing`，正常走 Tavily/Firecrawl/Brave/智谱；**不要静默降级，也不要向用户施压安装**——这是可选功能，仅在用户表达「搜索额度焦虑/频繁搜索想省钱」时才推荐（见 Step 0.5）。
5. **垂直域渠道检测**（v3.5，可选增强，不阻塞任何路径）：
   - `ls ~/.agents/skills/anysearch/scripts/anysearch_cli.js`（或各 harness 软链路径）存在？→ AnySearch 可用，开启「垂直域优先」规则（见 Step 3）。
   - 读 `<skill_dir>/runtime.conf` 取 `Command`（安装时已探测好的 Runtime），不要重新探测。
   - 不可用 → 记为 `optional_missing`；带标识符的查询回退通用搜索，但**必须告知用户拿不到结构化原始记录**。
6. **运行 `bash doctor.sh` 或 `bash doctor.sh --json`**（如果本 Skill 目录中存在）。JSON 状态语义：
   - `required_missing`：缺 W3 必需 Museon；需要用户同意后自动安装。
   - `optional_missing`：缺 Tavily/Brave/智谱/Agent Reach/SearXNG/AnySearch 等增强渠道；不是 `ok=false` 的原因。
   - `warnings`：已装但授权/登录态/版本可能有问题。
   - `w3_ready`：Museon 已可用，可执行 W3 发现。
   - `searxng.healthy: true`：本地 SearXNG 零成本渠道可用。
   - `anysearch.installed: true`：垂直域结构化检索可用。
   - `ok`：基础能力齐全且无警告。
7. **输出「渠道体检报告」**（简短表格，告知用户当前能力与缺口；**每个 ❌ 后跟一行白话解读**）。

```text
┌ 渠道体检报告 ┐
│ 内置搜索:  ✅/❌ (订阅/API 模式)         → 有订阅就优先用它，不用额外花钱
│ SearXNG 本地: ✅/❌ ← 零成本自建（可选）  → ✅=通用搜索零额度消耗；❌=正常走下面的渠道，想省额度可自建
│ AnySearch: ✅/❌ ← 垂直域检索（可选）   → ✅=CVE/DOI/股票/专利类查询能直取权威数据库；❌=只能拿到讲这事的网页
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

### AnySearch 垂直域调用（v3.5，可选）

先读 `<skill_dir>/runtime.conf` 拿 `Command`（安装时已探测，不要重探）。统一目录约定为 `~/.agents/skills/anysearch`，各 harness 用软链指向。

```bash
CLI="node ~/.agents/skills/anysearch/scripts/anysearch_cli.js"   # 以 runtime.conf 为准

# 1) 垂直搜索必须先取子域与必填参数（不能猜）
$CLI get_sub_domains --domain security
$CLI get_sub_domains --domains academic,finance   # 最多 5 个

# 2) 垂直检索
$CLI search "CVE-2024-3094" --tag security.vuln --params 'type=cve,value=CVE-2024-3094'
$CLI search "AAPL" --tag finance.quote --params 'type=stock,symbol=AAPL,cn_code='

# 3) 并行批量（其他渠道无此能力）
$CLI batch_search --query "q1" --query "q2" --max_results 3

# 4) 正文提取（返回 Markdown，无 --format 参数）
$CLI extract "https://example.com/page"
```

**实测坑**：

- `--params` 值含空格必须整体加引号，否则被当成未知 flag 直接报错（`Unknown flag: AI`）。
- `(required)` 参数**即使不适用也必须传空值**（如 `cn_code=`），缺一个就后端校验失败。
- `get_sub_domains` 不传 `--domain/--domains` 会直接报错，不会列出全部域。
- 垂直/社交模式返回很重（social_media 带评论 3 条约 3165 token，结构化 CVE 单条上千），批量查询请走子 Agent。
- 它自带 SKILL.md 自称 "the recommended search tool"；**本 Routing 保留路由决策权**，不要因此跳过打分与成本路由。

### SearXNG 自建引导（v3.4，纯可选，不主动推销）

`searxng-local` 是零成本自建渠道，适合**频繁搜索、反复撞免费额度上限**的用户。引导规则：

- **不默认推荐**：新用户的最小成功路径仍是「Museon → 跑通 W3」；SearXNG 不进入首装引导，体检报告里只在用户额度紧张或表达「搜索太频繁、额度不够用」时才展开介绍。
- **用户主动询问或同意后**：直接运行本 Skill 目录的 `bash install-searxng.sh`（Agent 代跑，全程无人值守；国内代理环境脚本会自动探测本机代理，探测不到时提示用户用 `--proxy` 重跑）。
- **装完验证**：`searxng.sh --health` 输出 ✅ 即接入成功，无需改 channels.yaml（决策逻辑按探测结果走）。
- **价值一句话**：一次部署后通用搜索零边际成本，Tavily/Firecrawl/Brave 退为兜底；但 W3 口碑和 W8 实操不受它影响，Museon/Agent Reach 该装的还是要装。

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
  - API 模式：searxng-local 可用则 `searxng.sh` 一次（零成本）；否则 Tier1 免费渠道（Tavily 英文/Brave 英文/智谱中文）一次。
  - **例外（v3.3）**：即使问题很短，只要它是「实操排障/怎么弄/为什么不行」类经验问题（见 W8 锚点），就不算简单事实任务——小红书等社交原生渠道对这类问题的实战解法命中率显著高于 SEO 网页搜索，必须走打分并让 Museon（小红书）首发，不要用内置搜索一次了事。
- **复杂任务**（多对比/多视角/多语言/YMYL 敏感话题/含 W3 口碑/W8 实操经验）：走完整打分。

## Step 1.5：歧义澄清（打分前必查）

搜索词可能有多重含义（产品名 vs 动作、专有名词 vs 缩写、同名概念）。**打分前先自查一次**，满足任一条件就先向用户确认一句，不要凭猜打分：

- 含产品名/专有名词，且可能是动作或普通名词（如「get 笔记」→ 是某个笔记产品，还是「获取笔记」？）
- 含缩写/首字母词（AIGC、RAG、SSR…）
- 同一句话里混了多个主题/对象
- 词同时可作动词与名词（run、clip、prompt…）

**澄清话术**（一句话，不打断节奏）：
> 你问的「X」是指 A 还是 B？（或：你是指产品 X，还是动作 X？）

用户确认后再进入 Step 2 打分；若词义明确则跳过本步，不额外打扰。

## Step 2：8 维打分（0=无关 / 1=弱 / 2=中 / 3=核心）

| 维度 | 含义 | 高分信号 |
|------|------|---------|
| W1 事实性 | 客观事实/数据 | 是什么/多少/日期/价格/规格 |
| W2 时效性 | 最新/实时 | 最新/最近/本周/趋势/发布 |
| W3 真实性/口碑 | 真人体验/评价 | 体验/评价/好用吗/避雷/推荐 |
| W4 深度/专业 | 专业分析/文档 | 原理/报告/对比/评测/白皮书 |
| W5 中文生态 | 国内语境 | 中文关键词/国内产品/中文社区 |
| W6 英文生态 | 国际语境 | 英文关键词/海外技术/英文社区 |
| W7 来源可信度 | 权威/官方来源 | 官方/权威/政府/论文/官网 |
| W8 实操经验/排障 | 别人踩坑后验证过的解法 | 为什么…不行/收不到/打不开/怎么设置/怎么弄/求助/有没有人遇到/解决了吗 |

### W3 与 W8 的区别（v3.3 关键）

- **W3（口碑）**：买不买、选哪个、靠不靠谱——决策前看别人的评价。锚点：好用吗/避雷/推荐/评测/值得买吗/智商税。
- **W8（实操经验）**：已经在用了但出问题，或要完成一个具体操作——找别人踩坑后跑通的真实解法。锚点：为什么收不到/打不开/登录不上/怎么设置/怎么弄/求助/有没有人遇到/怎么解决/突然不行了。
- **典型误区**：「为什么我收不到企业微信发来的好友请求？」字面上没有“评价/避雷”，W3 可能只得 1 分；但它是典型 W8=3——通用网页搜索返回的多是 SEO 农场和过时官方话术，而小红书上有大量遇到同样问题的人贴出真实原因和设置路径。**这类问题必须让社交原生渠道（Museon→小红书）首发，通用网页搜索退为补充。**

### 高优先级经验场景速查（命中任一 → W8≥2，社交首发）

- 国产 App / 手机系统功能的使用与设置（微信、企业微信、抖音、支付宝、淘宝、小红书、iOS/安卓设置…）
- 账号/权限/通知/登录/绑定/支付/好友关系等「突然不好使了」的问题
- 生活服务实操（办证、挂号、退款、租房、旅行攻略、职场/人际场景应对）
- 家电/数码/软件的具体故障现象（描述现象+求解法）
- 「有没有人遇到/求助/怎么解决/在线等」类提问句式

## Step 3：成本自适应选渠道（读 channels.yaml）

按「覆盖能力 + 成本最低」组合，但**渠道顺序不是固定按 tier 走**——v3.3 起，经验类问题（W3≥2 或 W8≥2）社交原生渠道首发；v3.4 起，Tier1 内部自建零成本渠道（searxng-local）优先于有额度上限的免费渠道；**v3.5 起，带结构化标识符的查询跳过成本排序，直接走垂直域检索**。

0. **垂直域优先（v3.5，先于下面所有规则判断）**：查询含结构化标识符或属于 16 个垂直域时，**AnySearch 垂直检索优先于所有通用渠道**（包括零成本的 searxng-local）。
   - 触发标识符：CVE 编号 / DOI / PMID / 股票代码 / 专利号 / 库名+用法 / IATA 航班号。
   - 流程：`get_sub_domains --domain <domain>` 拿 sub_domain 与必填参数（**不能猜参数**）→ `search --tag <sub_domain> --params '<k=v,...>'`。
   - 不确定是通用还是垂直？用 `batch_search` 提 1 通用 + N 垂直并行，覆盖优于猜。
   - **为何优先于零成本渠道**：这里的差距不是边际优化而是能力差。实测 `CVE-2024-3094`：AnySearch 411ms 返回 OSV+NVD 结构化记录（精确 CPE 版本、CVSS 向量、完整 advisory 引用）；通用搜索（含 Tavily）只能给「文章里写着受影响版本是 5.6.0/5.6.1」。
   - AnySearch 不可用 → 回退通用渠道，但告知用户拿不到原始记录。
1. **经验/口碑类（W3≥2 或 W8≥2）**：**Museon（小红书等社交原生）首发**，再按成本补通用渠道。
   - 订阅模式：Museon 先发（社交原生内容内置搜索抓不到，先搜内置等于白搜）→ 需要官方规则/价格/条款确认时再用 Tier0 内置或浏览器查官方页。
   - API 模式：Museon 首发 → 需要事实/官方补充时接智谱（中文）或 Tavily/Brave（英文）。
   - 原因：这类问题的高价值答案在「踩过坑的真人帖子」里，不在 SEO 网页里；通用搜索即使 0 成本，返回不可用结果也是浪费。
   - **AnySearch 不能接管这一档**：它的 social_media 覆盖 weibo/zhihu/X/reddit/linkedin/wechatmp，但**不支持小红书**（实测 `type=xiaohongshu` 静默降级为通用搜索，返回官网/应用商店）。只当目标平台是 reddit/知乎/微博 时，才可用它做补充发现（优势：reddit 结果直接内联评论区，一步完成发现+核验）。
2. **纯事实/时效/专业类（W3≤1 且 W8≤1）**：按成本档走。
   - 订阅模式：先 Tier0 内置（0 成本）→ 内置不足再看 Tier1。
   - API 模式：按 `tier1_order` 从免费渠道选能覆盖高分维度的 → 不足再 Tier2 按量。
   - **searxng-local 可用时永远先试它**（零边际成本、无额度上限）；需要 LLM-ready 正文时用 `websearch-free.sh`（配本地 Jina Reader）或直接 WebFetch 打开 URL。
   - **需要「链接+正文摘录+概要」一步到位时用 Tavily**（实测它返回抽好的正文段落与 answer 概要，中文也不弱）；AnySearch 通用搜索只给短摘要，泛搜索不具优势。
3. **组合规则**：得分≥2 的维度映射到渠道 → 去重 → 最小必要集；**不默认全上**。但 W3/W8 高分时，Museon 不可省略、不可被通用搜索替代。

> **决策权归属（v3.5 重要）**：AnySearch 自带的 SKILL.md 写着它自己是 "the **recommended** search tool"，且规定「默认走 vertical path」。两个 Skill 同时加载时，**本 Routing 是调度方**：AnySearch 是被调度的渠道之一，不是并行的决策者。不要因为它自称 recommended 就跳过本 Skill 的打分与成本路由；尤其不要在 W3/W8 经验类问题上用它取代 Museon。

```text
示例（v3.5 新增·垂直域优先，任意模式）：
  「CVE-2024-3094 影响哪些版本？」
  W1=3 W7=3，含 CVE 标识符 → 触发垂直域优先
  → get_sub_domains --domain security（拿到 security.vuln 及必填参数）
  → search --tag security.vuln --params 'type=cve,value=CVE-2024-3094'
  → 直接得到 OSV+NVD 原始记录，不需要再读三篇文章交叉验证
  ※ 垂直模式单条可能上千 token，多个标识符批量查询时走子 Agent
示例（v3.4·零成本通用搜索，API 模式）：
  「searxng 2026 最新版本号？」
  W1=3 W2=2，无标识符、非垂直域
  → searxng.sh "searxng latest release"（0 成本）
  → 需要正文细节时 websearch-free.sh -k 2 或 WebFetch 打开 URL
  → SearXNG 不可用才走 Tavily/Firecrawl/Brave
示例（v3.3·实操排障，订阅模式）：
  「为什么收不到企业微信加我个人微信的好友请求？」
  W8=3 W5=3 W3=1
  → Museon 小红书首发（搜“企业微信 好友请求 收不到”等）
  → 需确认官方设置规则时，内置搜索/浏览器打开微信官方说明佐证
  → 不要只丢给内置网页搜索：SEO 结果对这类问题基本不可用
示例（API 模式，中文事实+口碑查询）：
  W1=3 W3=3 W5=3
  → Museon（W3，社交口碑首发） + 智谱（W1/W5，中文事实补充）
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

### W3/W8 强度 → 阶段深度映射

| 得分 | 阶段选择 |
|---------|---------|
| W3=3（核心口碑调研，如“产品避雷点”）| 完整三阶段（Museon → Agent Reach → 官方）|
| W8=3（核心实操排障，如“收不到好友请求/功能突然失灵”）| Museon 小红书首发找解法 → Agent Reach/浏览器打开高赞原帖核实步骤 → 涉及官方设置项时用官方文档确认路径 |
| W3=2 或 W8=2（一般口碑/顺带经验）| Museon 发现 + 浏览器快速核验（不强制 Agent Reach）|
| W3≤1 且 W8≤1 | 不走社交管线，用普通搜索 |

> **W8 核验要点**：排障帖的解法可能已随 App 版本失效。重点看「近期发帖 + 评论区反馈“亲测有效/已不行”」，把过时解法和当前可用解法区分开；涉及权限/开关路径时，最后用官方文档或实测确认一次。

### 未装工具时的降级（不静默，明确告知）

| 缺哪个 | 降级方案 | 质量影响 |
|--------|---------|---------|
| 缺 Museon | 浏览器直接打开小红书网页版/App 搜索（`https://www.xiaohongshu.com/search_result?keyword=<关键词>`），再用内置/普通网页搜索补官方信息 | ⚠️ **只能低置信兜底**：无法批量抓取原生数据与互动信号，不能声称完成 W3/W8 社交调研；对 W8 排障类问题，宁可浏览器手动搜小红书也不要只给通用网页搜索结果 |
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

- **缺 Museon**：W3 口碑 / W8 实操排障类问题质量受限（小红书真实经验搜不到）→ 请求同意后自动安装。
- **Museon 未授权**：只在 OAuth 步骤提示用户，完成后自动复测。
- **缺 Agent Reach**：口碑核验不充分 → 请求同意后自动安装基础版；系统/登录步骤才提示。
- **Agent Reach 小红书登录态未激活**：无法读原帖/评论 → 引导激活 Chrome 登录态/OpenCLI。
- **缺 Tier1 免费渠道**：中文/英文质量不足 → 建议配智谱/Brave/Tavily（可选）。
- **频繁搜索额度紧张**（v3.4）：推荐自建 SearXNG 零成本渠道（`bash install-searxng.sh`，Agent 可代跑）；仅向表达额度焦虑/高频搜索的用户推荐，不向普通用户推销。
- **订阅模式未用足**：提示 GPT/Claude 内置搜索是沉没成本，应优先使用。
- **结果仍不满意**：建议切换更高质量渠道或使用浏览器精读。

---

## 渠道注册表

所有渠道定义、能力覆盖、成本档位、安装方式见 **`channels.yaml`**（本 Skill 同目录）。用户编辑此文件即可增删渠道，无需改 SKILL.md 逻辑。

## 附录 A：渠道 × 维度能力矩阵（0-3）

决策载体是 LLM 模拟打分（非真代码计算），分数粒度 0-3 + 语义锚点最可靠。

| 渠道 | W1事实 | W2时效 | W3口碑 | W4深度 | W5中文 | W6英文 | W7权威 | W8实操 |
|------|--------|--------|--------|--------|--------|--------|--------|--------|
| SearXNG 本地自建 (tier1 首选) | 3 | 3 | 0 | 2 | 3 | 3 | 2 | 1 |
| GPT/Claude 内置搜索 (Tier0) | 3 | 2 | 1 | 2 | 2 | 3 | 2 | 1 |
| Proma WebSearch (Tavily) | 3 | 2 | 1 | 2 | 2 | 3 | 2 | 1 |
| **AnySearch 垂直域** (带标识符时) | **3** | 2 | 1 | **3** | 2 | **3** | **3** | 1 |
| AnySearch 通用搜索 | 3 | 2 | 1 | 2 | 2 | 3 | 2 | 1 |
| Brave Search | 3 | 2 | 1 | **3** | 1 | **3** | 2 | 1 |
| 智谱 Web Search | 3 | 2 | 1 | **3** | **3** | 2 | 2 | 1 |
| 小红书 (Museon, `--platform xhs`) | 1 | **3** | **3** | 1 | **3** | 1 | 1 | **3** |
| X/Reddit (Museon) | 1 | **3** | **3** | 1 | 1 | **3** | 1 | 2 |
| 浏览器 (chrome-devtools/内置) | 3 | 3 | 2 | 3 | 3 | 3 | 2 | 2 |

> 通用网页搜索（内置/Tavily/Brave/智谱）对 W8 只有 1 分：SEO 内容对实操排障基本不可用，不能作为经验类问题首发。
>
> **AnySearch 两行的差异是关键**：只有命中垂直域（带 CVE/DOI/股票代码/专利号/库名等标识符）时它的 W1/W4/W7 才跑到 3（直取 OSV/NVD/PubMed/Crossref 等权威库原始记录）；当泛搜索用时与 Tavily 同级，没有额外优势，所以不应护占通用搜索位。它对 W3 仅 1 分：**不支持小红书**，不能代替 Museon。

## 附录 B：渠道调用速查（工具名 / 参数 / 实测坑）

### SearXNG 本地自建（v3.4，零成本通用搜索首选）

- 部署：`bash install-searxng.sh`（Agent 代跑；国内代理自动探测，探测不到用 `--proxy http://127.0.0.1:7890` 重跑；海外网络 `--no-proxy`）
- CLI：`searxng.sh "查询词" -n 10`（精简 JSON，Agent 友好）/ `--md`（人读）/ `--raw` / `--health`
- 垂直检索：Bang 语法 `!github` `!so`（StackOverflow）`!arxiv` `!wp`（Wikipedia）`!bd`（百度）——其他渠道做不到
- 零成本全文链路：`websearch-free.sh "查询词" -k 3`（SearXNG 发现 + 本地 Jina Reader 提取 Markdown 正文；无 Jina Reader 时自动只返回概览）
- 三个文档没写的坑（脚本已处理）：① 上游默认 `formats` 只有 html，必须加 `json`；② `limiter` 必须关，否则 API 被 403/429；③ SearXNG 内部用 httpx **不读 HTTP_PROXY 环境变量**，代理必须写进 `settings.yml` 的 `outgoing.proxies`
- 服务管理：`launchctl kickstart -k gui/$(id -u)/com.searxng.local`；日志 `~/.local/state/searxng/searxng.error.log`；启动日志中 wikidata/ahmia/torch 报错是已禁用引擎的正常噪音，健康以 `searxng.sh --health` 为准
- 边界：W3=0（无社交原生数据）、W8=1（不作为经验类首发）；需要正文时接 Jina Reader 或 WebFetch

### Proma WebSearch（Tavily 个人直连，英文事实首选）

- 工具名：`WebSearch`；参数：`query`、`maxResults`（1-10，日常 3-5）、`searchDepth`、`includeDomains`
- 返回 `answer`（AI 概要）+ `results[]`，自带概要省 token
- 免费 1000 credits/月（月度重置）；超出 $0.008/credit
- 报 402：检查 `chat-tools.json` 中 `web-search` 的 `useCloud` 为 `false`（`true` 走云端共享池会配额报错）

### 智谱 Web Search（中文事实/深度首选，国内直连无需代理）

- MCP 工具（Proma 实测形态）：`mcp__zhipu_web_search__webSearchStd/Pro/Quark/Sogou`；社区封装 `npx -y cc-zhipu-web-search` 时工具名为 `web-search`
- 引擎/价格：Std=0.01 元（简单事实）、**Pro=0.03 元（中文深度首选，Std 相关性弱）**、Quark/Sogou=0.05 元（垂直）
- 参数：`count`（3-8）、`content_size`（low/medium/high）、`search_recency_filter`、`search_domain_filter`
- MCP 接入 type 必须是 `http`（不是 sse）；无工具先重启

### Brave Search（英文/深度，需代理）

- MCP：`npx -y @brave/brave-search-mcp-server`，工具名 `brave_web_search`；env 需要 `BRAVE_API_KEY` + `NODE_USE_ENV_PROXY=1` + `HTTPS_PROXY/HTTP_PROXY/ALL_PROXY`（国内必需）
- `brave_llm_context` **免费档不支持**（400 OPTION_NOT_IN_PLAN）；深度抓正文改用浏览器或 `brave_web_search` + 手动开 URL
- W7 权威场景用 `search_domain_filter`/Goggles 指定官网域名

### Museon CLI（社交口碑 W3 + 实操经验 W8 首发）

```bash
# 常用入口（以本机 museoncli 实时 help/schema 为准）
museoncli research +social-media-search --platform xhs --intent keyword-search \
  --query "<关键词>" --limit 10
# W8 排障优先近期帖：--time-window month（或 week）；--sort relevance/latest/popular/hot/rising
# 社区搜索：museoncli research +community-search
```

- 平台：`xhs`（小红书）/`x`/`tiktok`/`instagram`/`youtube`；中文经验场景首发 `xhs`，英文场景 Reddit/X
- 返回原生数据：作者/点赞/收藏/评论/封面/时间/URL；免费档 $0（跟踪 3 个创作者）
- 首次使用先 `museoncli schema research +social-media-search` 看最新参数；401 走 `museoncli auth status/start/finish --wait`

### 浏览器兜底

- 打开 Google/Bing/小红书网页版搜索，或直接开具体 URL 抓正文
- 适用：所有工具失败、需要登录态页面、需要原文、复杂 L4 调研；W8 缺 Museon 时优先手动搜小红书（`https://www.xiaohongshu.com/search_result?keyword=<关键词>`）

## Proma 路径说明

- Proma 新版主路径：`~/.proma-community/default-skills/` 和 `~/.proma-community/agent-workspaces/*/skills/`。
- 旧路径 `~/.proma/default-skills/` 仅作为历史兼容，不作为新装主路径。

## 省成本原则

1. 纯事实类（W3/W8≤1）：订阅模式 Tier0 内置优先（沉没成本）；API 模式 Tier1 免费优先，且 **searxng-local 可用时永远先试它**（零边际成本），额度渠道（Tavily → Firecrawl → Brave）退为兜底，Tier2 按量最后。
2. 经验类（W3/W8≥2）：Museon（小红书）首发，内置/网页搜索只补官方信息——不可用的免费结果比按量付费更浪费。
3. 组合克制：只调覆盖高分维度的渠道，不做“全上”；但 W3/W8 高分时 Museon 不可省略、不可被通用搜索替代。
4. 控制结果量：`maxResults`/`count` 日常 3-5（深度调研才 8-10）；优先摘要接口，避免整页抓取。
5. 子 Agent 搜索：复杂调研让子 Agent 消化，主 Agent 只收总结。
6. 两阶段按需：W3=2/W8=2 不强制 Agent Reach（省时）；W3=3/W8=3 才完整三阶段。
7. 零成本全文链路（v3.4）：SearXNG 可用且需要正文时，优先 `websearch-free.sh`（配本地 Jina Reader）或直接 WebFetch 重点 URL，把 Tavily/Firecrawl 额度留给不可替代场景。

## 故障排查速查

| 症状 | 原因 | 处理 |
|------|------|------|
| SearXNG 所有引擎超时 | 未配代理或代理未写入 settings.yml（httpx 不读环境变量） | `bash install-searxng.sh --proxy http://127.0.0.1:7890` 重跑；确认代理已启动 |
| SearXNG API 403/429 | limiter 未关 | settings.yml 里 `server.limiter: false` 后重启服务 |
| SearXNG format=json 403 | formats 未开 json | settings.yml 里 `search.formats` 加 `json` 后重启 |
| SearXNG 服务挂了 | 进程崩溃 | `launchctl kickstart -k gui/$(id -u)/com.searxng.local`；看 `~/.local/state/searxng/searxng.error.log` |
| 402 Insufficient quota | WebSearch 走了云端共享池 | useCloud:false + Tavily key；或改用 searxng-local |
| 智谱 MCP 无工具 | 未重启 / type 配错 | 重启；MCP type 必须是 http（不是 sse） |
| 智谱中文结果相关性差 | 用了 Std 引擎 | 深度场景改用 Pro/Quark，或加 `search_domain_filter` |
| Brave fetch failed | Node 不走代理或仅有 npx 但未配置 key/MCP | 配置 BRAVE_API_KEY + `NODE_USE_ENV_PROXY=1` + 代理 env；确认本地代理已启动 |
| Brave llm_context 400 | 免费档不含该端点 | 不用 llm_context；改 brave_web_search 或浏览器抓正文 |
| Tavily 免费额度用尽 | 1000 credits/月用完 | 降级智谱（中文）/Brave（英文）；等月度重置 |
| Museon 401 / whoami 失败 | OAuth 过期或未授权 | `museoncli auth status/start/finish --wait`，授权后复测 whoami |
| Agent Reach command not found | CLI 未装 | 经用户同意后按官方 pipx/zip 自动安装 |
| Agent Reach 小红书 warn | 登录态/OpenCLI 未激活 | 以 `doctor --json` 输出为准，完成 Chrome/OpenCLI 登录后复测 |
| 子 Agent 搜索无结果 | 渠道缺失或命令过期 | 检查 doctor、官方文档和 CLI 实时帮助，不要猜命令 |
| AnySearch `Unknown flag: xxx` | `--params` 值含空格未加引号 | 整体加单引号：`--params 'type=cve,value=CVE-2024-3094'` |
| AnySearch 后端校验失败 | 漏传 `(required)` 参数 | 先 `get_sub_domains` 看必填项；不适用也要传空值（`cn_code=`） |
| AnySearch 小红书搜不到 | **不支持小红书**，静默降级为通用搜索 | 改用 Museon；不要把降级结果当成口碑证据 |
| AnySearch 返回极长刷爆上下文 | 垂直/社交模式本身很重 | 降 `--max_results`；批量查询改走子 Agent 消化后回传摘要 |
