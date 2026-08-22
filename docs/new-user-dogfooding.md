# 纯新用户 Dogfooding 验证 SOP

本文档沉淀“模拟一个刚安装 `web-search-routing`、但未配置任何搜索渠道的新用户，首次触发 W3 口碑问题时会经历什么”的验证流程。它用于每次修改 `SKILL.md`、`ONBOARDING.md`、`install*.sh`、`doctor.sh` 或渠道配置后回归。

## 目标

验证新用户在以下状态下能否顺利继续：

- 已安装 Agent 客户端和本 Skill；
- 没有 Museon；
- 没有 Agent Reach；
- 可能没有 Tavily/Brave/智谱 API；
- 第一次就提出真实口碑类问题，例如：
  `帮我查一下 get笔记 的真实用户评价，重点看小红书上的避雷点和高频好评。`

核心验收标准：

1. 用户不能只看到“缺工具/质量下降”几句话；必须知道下一步是什么。
2. 用户同意安装后，Agent 应自动完成环境检查、安装、setup、whoami/doctor 校验。
3. 只有浏览器 OAuth、网页登录、Chrome 登录态、系统权限或用户个人凭据需要用户操作。
4. 用户拒绝安装时，可以低置信兜底，但结论必须明确边界，不能伪装成完整口碑调研。
5. 文档、脚本、体检报告的说法必须一致。

## 验证前检查

在仓库根目录执行：

```bash
bash -n install.sh doctor.sh install-museon.sh install-agent-reach.sh scripts/test.sh
bash scripts/test.sh
bash doctor.sh
bash doctor.sh --json | python3 -m json.tool
git diff --check
```

同时检查：

```bash
见 `scripts/test.sh`：它会用版本锚点检查本 Skill 版本一致性。发布前还应人工确认没有第三方旧版本、未经核实的 harness setup 或占位命令。
```

期望：

- 所有测试通过；
- `bash doctor.sh` 在 UTF-8 终端不崩溃；
- `--json` 是合法 JSON；
- 不残留旧 Museon 版本、未经核实的 `proma` setup；`agent-reach web` 只能作为“不要编造”的负面警示出现。

## 场景 A：零渠道新用户首次提出 W3 问题

### 输入

```text
帮我查一下 get笔记 的真实用户评价，重点看小红书上的避雷点和高频好评。
```

### Agent 应做的事

1. 识别该问题包含 W3（真实评价/避雷点），不是普通事实查询。
2. 输出渠道体检报告，且每个缺失项都有白话解释。
3. 明确说明：
   - Museon 是 W3 发现的必需项；
   - Agent Reach 是第二阶段核验增强；
   - 不安装时只能做低置信兜底。
4. 询问是否让 Agent 自动安装 Museon。

### 用户应看到的话术骨架

```text
这个问题需要真实社交口碑数据。当前缺少 Museon；没有它，我无法批量获取小红书/X/Reddit 的原生帖子、点赞、评论、收藏等数据。

如果你同意，我会自动检查 python3/uv/curl，安装官方 Museon CLI，并执行 setup 和 whoami；只有浏览器登录授权需要你操作。是否现在开始？
```

不合格表现：

- 直接丢给用户一串安装命令；
- 只说“质量下降”，不说如何继续；
- 直接用普通搜索回答“用户普遍认为……”；
- 把浏览器 fallback 说成和 Museon 同等体验。

## 场景 B：用户同意安装 Museon

### Agent 应自动完成

```text
检查 python3 >= 3.11
检查 uv；缺失则用官方脚本安装到用户目录
安装官方 Museon CLI（当前核实版本见 install-museon.sh / ONBOARDING.md）
museoncli setup --agent auto
museoncli auth status / whoami
```

可以直接调用：

```bash
bash install-museon.sh
```

### 唯一允许打断用户的步骤

当 `museoncli whoami` 失败、需要 OAuth 时，Agent 应：

1. 运行/展示 `museoncli auth start` 的验证 URL 或提示；
2. 明确告诉用户只需在浏览器登录并批准；
3. 不要求用户复制 device code、token、API key；
4. 用户回来后自动执行：
   ```bash
   museoncli auth finish --wait --timeout 60 --poll-interval 2
   museoncli whoami
   ```
5. 成功后继续原始搜索任务。

### 验收点

- 用户没有手动复制安装命令；
- 用户只在浏览器授权时被打断；
- 授权后 Agent 自动复测，不把“你自己运行 whoami”作为默认要求。

## 场景 C：Museon 已装但 Agent Reach 未装

### Agent 应做的事

1. 先用 Museon 完成 W3 发现；
2. 明确当前结论“尚未逐条核验原帖评论”；
3. 如果用户要深挖，再询问是否自动安装 Agent Reach。

用户同意后，Agent 自动执行：

```bash
bash install-agent-reach.sh
agent-reach doctor --json
```

### 唯一允许打断用户的步骤

- `--system` 系统级安装或权限确认；
- Chrome/OpenCLI 扩展安装；
- 小红书/Reddit/X 等平台网页登录或 Chrome profile 登录态；
- doctor 输出要求用户手动确认的其他凭据。

用户完成后，Agent 必须再次运行 `agent-reach doctor --json`，确认目标通道 `active_backend`，再继续核验。

## 场景 D：用户拒绝安装 Museon/Agent Reach

Agent 可以继续，但必须：

1. 先声明这是低置信兜底；
2. 使用内置搜索、普通网页搜索或浏览器公开页面；
3. 输出“初步线索”，不要写成“用户普遍认为”；
4. 明确无法确认：
   - 高频问题还是个案；
   - 问题是否已修复；
   - 评论区是否有反例；
   - 原生互动数据如何。

推荐结论结构：

```text
以下是低置信兜底结果，不代表完整小红书/X/Reddit 口碑。

公开网页线索：
1. ...
2. ...

无法确认：
- ...

若需要高置信口碑结论，建议安装 Museon；若还要逐条核验评论，再安装 Agent Reach。
```

## 场景 E：安装失败或命令不可用

Agent 不应把失败原样甩给用户。应：

1. 保留错误中的关键原因；
2. 隐藏 token/API key；
3. 判断是哪一步失败：python/uv、网络下载、setup、OAuth、PATH、doctor；
4. 只把必须由用户处理的动作说清楚；
5. 修复后自动从失败步骤继续，而不是让用户从头重装。

## 每次发布前的最小回归清单

- [ ] `scripts/test.sh` 通过。
- [ ] `bash doctor.sh` 文本模式通过。
- [ ] `bash doctor.sh --json` 合法且包含 `w3_ready`、`required_missing`、`optional_missing`、`warnings`。
- [ ] `install.sh` 会复制 `SKILL.md`、`channels.yaml`、`ONBOARDING.md`、`INSTALL.md`、`README.md`、`LICENSE`、`doctor.sh`、安装辅助脚本。
- [ ] 新用户问 W3 问题时，Agent 先给出能力缺口和“是否自动安装 Museon”的选择。
- [ ] 用户同意后，Agent 自动安装；只有 OAuth/登录打断。
- [ ] 用户拒绝后，结果标注低置信，不伪装成完整口碑调研。
- [ ] Agent Reach 命令以 `doctor --json` 为准，不编造平台子命令。
- [ ] README、INSTALL、SKILL、ONBOARDING、channels.yaml 中版本和产品立场一致。

## 建议的模拟方式

如果当前本机已经安装 Museon/Agent Reach，不要直接在真实环境观察“缺失体验”。可用临时 HOME 或独立测试用户模拟：

```bash
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" PATH="$HOME/.local/bin:$PATH" bash doctor.sh
HOME="$TEST_HOME" PATH="$HOME/.local/bin:$PATH" bash doctor.sh --json
```

注意：OAuth 和真实 CLI 安装仍会写入测试 HOME，不会污染真实用户目录。模拟时不要使用用户真实凭据；需要验证 OAuth 成功路径时，再在明确授权下使用真实账号。

## 演练记录：假 HOME 零渠道环境

以下命令用于模拟一个没有 Museon、没有 Agent Reach、没有 Tavily/Brave/智谱配置的新用户：

```bash
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash doctor.sh
HOME="$TEST_HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash doctor.sh --json | python3 -m json.tool
```

在本次回归中，关键输出如下（绝对路径是临时目录，不同机器会不同）：

```text
📋 web-search-routing 渠道体检（v3.2.1）
状态：required_missing

渠道工具：
  Museon CLI: ❌ 未找到
    whoami: ❌
  Agent Reach: ❌ 未找到
    --version: ❌
    doctor --json: ❌
    小红书 active_backend: unknown

配置线索（不显示密钥值）：
  Tavily: ⚠️
  Brave:  ⚠️
  智谱:   ⚠️

必需缺失：
  - museoncli

可选缺失：
  - agent-reach
  - tavily_config
  - brave_config
  - zhipu_config

建议：
  - Museon 是 W3 社交口碑发现的必需渠道。用户同意安装后，Agent 应先检查 python3/uv/git/curl，再安装官方最新版 Museon CLI，并优先运行 museoncli setup --agent auto；只有浏览器 OAuth 需要用户操作。
  - Agent Reach 是 W3 原帖/评论核验增强渠道（可选但推荐）。用户同意后，Agent 可按官方文档用 pipx install https://github.com/Panniantong/agent-reach/archive/main.zip 安装，再运行 agent-reach install --env=auto 和 agent-reach doctor --json。
```

JSON 语义应为：

```text
status = required_missing
ok = false
required_missing = ["museoncli"]
optional_missing = ["agent-reach", "tavily_config", "brave_config", "zhipu_config"]
```

### 基于该输出的完整模拟对话

**用户**：

```text
帮我查一下 get笔记 的真实用户评价，重点看小红书上的避雷点和高频好评。
```

**Agent 应回应**：

```text
┌ 渠道体检报告 ┐
│ 内置搜索: ✅（当前 Agent 可用）
│ 智谱/Brave/Tavily: ⚠️ 未配置（可选；不阻塞口碑发现）
│ Museon: ❌ 未安装 ← W3 发现必需
│ Agent Reach: ❌ 未安装 ← W3 核验增强，可后续再装
│ 小红书登录态: 未检测（需 Agent Reach 后判断）
└─────────────┘

这个问题需要小红书/X/Reddit 等平台上的真实帖子、互动和评价数据。当前缺少 Museon：没有它，我无法批量获取原生社交结果，也看不到点赞、评论、收藏、作者等互动信号。

我可以继续用内置搜索或浏览器公开页面兜底，但那只能给你低置信线索，可能主要是 SEO 页面、营销内容或少量公开摘要，不能代表真实用户口碑，也不能可靠判断“避雷点是不是高频共识”。

如果你同意，我会自动完成下面这些步骤：
1. 检查 python3、uv、curl/wget 等运行条件；
2. 缺 uv 时安装到用户目录；
3. 下载安装官方 Museon CLI；
4. 运行 museoncli setup --agent auto；
5. 运行 museoncli auth status / whoami；
6. 只有浏览器登录授权需要你操作；授权完成后我会自动复测并继续搜索。

是否现在开始自动安装 Museon？
```

**用户：开始。**

**Agent 应执行并汇报进度**：

```text
我开始自动安装。

✅ 已检查 python3：版本满足要求
✅ 已检查 uv：可用
✅ 正在安装官方 Museon CLI
✅ museoncli 可执行
✅ 已运行 museoncli setup --agent auto
⚠️ 当前未完成 Museon 授权。

接下来需要你操作一次浏览器授权：请打开下面的验证地址并登录/批准。
<此处展示 CLI 返回的验证 URL；不要展示 device code、token、API key>

你完成后回来告诉我“继续”，我会自动运行授权完成检查并复测 whoami。
```

**用户完成 OAuth 后说：继续。**

**Agent 应继续**：

```text
✅ 授权完成，museoncli whoami 成功。
我现在先用 Museon 搜索小红书原生结果，按点赞、评论、收藏和负面信号筛选高互动帖子。

说明：当前还没有 Agent Reach，所以我可以完成第一轮“发现”，但还不能逐条打开所有原帖和评论做深核验。结论会区分：
- 高置信：Museon 多帖重复出现且互动信号明显；
- 待核验：只在个别帖子出现、还需要评论区验证；
- 未覆盖：需要登录态或原帖评论才能确认的内容。
```

### 用户拒绝安装时的回应

如果用户说“先不装，你直接查”，Agent 应回应：

```text
可以，但我先明确边界：以下是低置信兜底结果，不是完整小红书/X/Reddit 口碑调研。我会用内置搜索和公开网页找线索，但无法批量获取原生帖子、评论和互动数据。

我会把结论分成：
1. 公开网页可见线索；
2. 无法确认的点；
3. 若要高置信口碑结论，建议安装 Museon；若还要逐条核验评论，再安装 Agent Reach。
```

这个演练的关键不是让 Agent 背诵固定文案，而是保证：

- 先体检，再解释能力缺口；
- 自动安装，不甩命令；
- OAuth 才打断；
- 拒绝安装时明确低置信边界；
- 有 Museon 但无 Agent Reach 时，先跑通发现，不夸大核验深度。
