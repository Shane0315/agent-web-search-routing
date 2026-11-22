# 更新日志

本项目版本号与 `SKILL.md` / `channels.yaml` / `doctor.sh` 中的 Skill 版本锚点保持一致，
由 `scripts/test.sh` 强制校验。

---

## 未发布 — 2026-11-22

**主题：统一使用 Ego Browser，不改变现有搜索渠道的 API/CLI 分工。**

- `SKILL.md`：浏览器搜索、精读、核验、登录与授权必须使用 Ego Browser；先加载 `ego-browser` Skill，缺失时核验来源、备份并通过正式入口安装，再读取 `ego-browser skill` 当前指南。
- 分开核验 Skill 可加载性、ego lite 运行时与站点登录态；被项目策略拒绝时不绕过，不让子 Agent、OpenCLI 或 OAuth 间接启动默认 Chrome。
- `channels.yaml`：用 `ego-browser` 替换 Kimi WebBridge 浏览器入口；Agent Reach 的浏览器后端不能确认兼容时改用 Ego Browser 核验并说明限制。
- `ONBOARDING.md`：补充相同前置要求；添加浏览器路由回归检查。
- 本次为未发布规则修订，保留 3.5.0 版本锚点；未修改 `doctor.sh` JSON schema，不声称它已检测 Ego Browser。

## v3.5.0 — 2026-09-05

**主题：垂直域结构化检索（可选增强），补上「带标识符查询」的能力空白。**

现有 8 个通用渠道都只能做「关键词 → 网页链接」。但 W4（深度）/W7（权威）遇到带标识符的
查询时，本质需要的是结构化数据源而非网页搜索。本版本不改变任何既有路径。

### 新增

- **`anysearch` 渠道**（tier 1，`required: false`）：[AnySearch](https://github.com/anysearch-ai/anysearch-skill)
  Skill 形态（自带跳平台 CLI，无需 MCP server）。覆盖 16 个垂直域：finance/academic/
  security/code/legal/health/ip/travel/gaming/film/business/energy/environment/agriculture/
  resource/social_media。另具备 `batch_search` 并行与 `extract` 正文提取。
- **`vertical_first` 路由规则**（channels.yaml 新配置节）：查询含结构化标识符
  （CVE/DOI/PMID/股票代码/专利号/库名/IATA）或属 16 垂直域时，**跳过 tier1_order**
  直接走垂直检索。实测依据：`CVE-2024-3094` 查询下，AnySearch 411ms 返回 OSV+NVD
  结构化记录（精确 CPE 版本、CVSS:3.1 向量、完整 advisory 引用链），而通用搜索
  （含 Tavily）只能给「文章里写着受影响版本是 5.6.0/5.6.1」。这是能力差，不是边际优化。
- **`doctor.sh`**：新增 AnySearch 探测（逐个候选目录检查，含软链）。JSON 新增 `anysearch`
  对象（`installed`/`dir`/`runtime`），文本报告新增「垂直域检索」一行；缺失只进
  `optional_missing`，不影响 `ok`；已装但缺 `runtime.conf` 时出 warning。
- **`SKILL.md`**：Step 0 新增第 5 步垂直域探测；Step 3 新增第 0 条「垂直域优先」（先于
  所有其他规则判断）；附录 A 新增两行（垂直模式 W1/W4/W7=3，通用模式与 Tavily 同级）；
  附录 B 新增调用速查；故障排查表新增 4 行。

### 关于与 Tavily 的关系（最易误解点）

两者**不是替代关系**，实测后的分工：

- Tavily 返回「链接 + 正文摘录 + answer 概要」，适合需要直接读内容的泛搜索；实测中文表现
  也不弱（能抽出教程正文段落）。**仍为 Tier1 泛搜索默认选项。**
- AnySearch 通用搜索只给短摘要，且同题与 SearXNG 首条命中一致——**泛搜索无优势**，
  所以在 `tier1_order` 里排在 Tavily 之后，只在命中垂直域时跳出该序列。

### 关键缺口（已写入渠道 note 与 SKILL.md）

- **AnySearch 不支持小红书**：实测 `type=xiaohongshu` 会静默降级为通用搜索，返回官网/
  应用商店而非用户评价；通用搜索也只能抓到「关于小红书的报道」。因此 **W3 口碑与
  W8 实操排障仍由 Museon 首发**，它只作 reddit/知乎/微博 的补充发现
  （优势：reddit 结果直接内联评论区，一步完成发现+核验）。
- **决策权冲突**：AnySearch 自带 SKILL.md 写着自己是 "the recommended search tool"
  且默认走 vertical path。已在本 Skill 明确声明：两个 Skill 同时加载时，本 Routing 是
  调度方，AnySearch 是被调度的渠道，不是并行决策者。
- **token 成本**：通用 3 条约 262 token（比 SearXNG 省）；但 social_media 带评论区 3 条
  约 3165 token、结构化 CVE 单条上千 token——垂直/社交模式很重，批量查询请走子 Agent。

### 文档

- `INSTALL.md` 新增「二.8、AnySearch 垂直域检索」，推荐**系统级统一目录 + 软链**安装
  （`~/.agents/skills/<skill>` 作权威副本，各 harness 软链指向），避免多副本版本漂移。
- README 中英两版新增 v3.5 说明，含与 Tavily 的分工对比表。

### 安全

安装前已审计 AnySearch v3.1.1：四个 CLI 的 SHA256 与官方 `SHA256SUMS.txt` 逐一匹配；
出网域名只有 `api.anysearch.com`；无 eval/subprocess/child_process；不读取
`.ssh`/`.aws`/keychain/history。

### 验证

- `scripts/test.sh` 全量通过（版本锚点、YAML 解析、doctor JSON 语义、零渠道 fake-home、
  安装打包、文档锚点）。
- 本机实测：anysearch 经四个 harness 软链路径均可调用；doctor.sh 正确报
  `installed: true` 与 `runtime: Node.js`。

---

## v3.4.0 — 2026-09-01

**主题：零成本自建搜索渠道（可选增强），解决频繁搜索用户的免费额度焦虑。**

本版本不改变任何既有决策路径。新用户的最短成功路径依然是「安装 Skill → 装 Museon →
完成一次 W3 口碑查询」，SearXNG 是额度紧张时才需要考虑的可选升级项。

### 新增

- **`install-searxng.sh`（新脚本）**：本地 SearXNG 一键部署，面向从未装过 SearXNG 的用户，
  全程无人值守、幂等可重跑。自动完成：
  - clone 源码 → `uv` 创建 Python 3.12 venv（无 uv 时回退 `python3 -m venv`）
  - 安装依赖（先装 `requirements.txt` 再 `--no-build-isolation` 可编辑安装，规避构建期依赖缺失）
  - 生成 `settings.yml`：**开启 JSON API**、关闭 limiter、随机 secret key、禁用易触发验证码的引擎
  - **代理自动探测**：环境变量 → 直连测试 → 常见本地端口（7890/7897/10809/1087/8118），
    支持 `--no-proxy` / `--proxy=<url>` 显式指定
  - 注册开机自启：macOS launchd（RunAtLoad + KeepAlive）/ Linux systemd --user
  - 安装 `searxng.sh`（精简 JSON / `--md` / bang 检索 / `--health`）与
    `websearch-free.sh`（搜索 + 全文抓取）两个封装
  - 90 秒健康轮询 + 实测一次搜索验证引擎链路
  - 测试/手动管理用途可加 `SEARXNG_SKIP_SERVICE=1`、`SEARXNG_KEEP_CONFIG=1`、`SEARXNG_SKIP_DEPS=1`
- **`channels.yaml`**：新增 `searxng-local` 渠道（`required: false`，Tier 1 零成本）与
  `firecrawl` 渠道；新增 `tier1_order`（searxng-local → tavily → firecrawl → brave → zhipu）
  与 `free_pipeline`（SearXNG 发现 + Jina Reader 全文提取 + 降级说明）两个配置节。
- **`doctor.sh`**：新增本地 SearXNG 健康探测（优先 `searxng.sh --health`，回退直接探测
  `127.0.0.1:8888` JSON API）。JSON 输出新增 `searxng` 对象（`healthy` / `endpoint`），
  文本报告新增「零成本自建渠道（可选）」一行。
- **`SKILL.md`**：Step 0 渠道探测新增 SearXNG 检查项（缺失只进 `optional_missing`）；
  Step 0.5 新增自建引导（明确「纯可选、不主动推销」）；Step 1 简单任务优先走本地渠道；
  Step 3 引入 `tier1_order` 与零成本链路；附录 A 能力矩阵新增 SearXNG 行；
  附录 B 新增调用速查；省成本原则 +1 条；故障排查表新增 4 行 SearXNG 症状。

### 修复

- **README 顶部描述与实际能力不一致**：标语和核心特性仍写「7 维打分」，实际 v3.3.0 起
  已是 8 维（新增 W8 实操经验/排障），本版本统一更正为 8 维。
- `install.sh` 未将 `install-searxng.sh` 纳入分发清单，导致脚本无法随 Skill 安装。

### 文档

- `INSTALL.md` 新增「二.7、SearXNG 本地自建（可选渠道）」完整章节，含网络环境差异处理、
  日常命令、以及三个上游文档未记录的坑。
- `ONBOARDING.md` 在能力对照表与「下一步」中说明 SearXNG 为可选项，不进最短路径。
- `docs/doctor-json.md` 新增 `searxng` 对象字段说明与 Agent 决策约定。

### 已知坑（脚本已自动处理，手动部署者需注意）

1. 上游默认 `search.formats` 只有 `html`，**必须显式加 `json`**，否则 API 返回 403。
2. `server.limiter` 必须为 `false`，否则程序化调用被 403/429 拦截。
3. SearXNG 内部使用 httpx，**不读 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量**，
   代理必须写进 `settings.yml` 的 `outgoing.proxies`，否则国内网络下所有海外引擎超时。

### 验证

- `scripts/test.sh` 全量通过（版本锚点、YAML 解析、doctor JSON 语义、零渠道 fake-home、
  安装打包、文档锚点）。
- `install-searxng.sh` 在隔离 HOME 的全新环境端到端实测：安装 → 启动 → 中文搜索返回结果。
- 已有实例重跑验证幂等，服务无中断。

---

## v3.3.0 — 2026-08-28

- 新增 **W8 实操经验/排障维度**：「为什么…不行 / 收不到 / 怎么设置」类问题由小红书等
  社交原生渠道首发，通用网页搜索退为补充（实测通用搜索对这类问题基本不可用）。
- 合并本地版工具实测矩阵（同题前排结果重合率等实测数据）。
- 修复 `doctor.sh` JSON 空数组序列化 bug。

## v3.2.1 — 2026-08-22

- 强化 `install.sh` 与 `doctor.sh` 自动化健壮性。

## v3.2.0 — 2026-08-20 ~ 08-22

- 修复 Proma 安装目录不匹配（P0）与自定义路径选择（P1）。
- 新增 `ONBOARDING.md`（5 分钟最小成功路径）与 `doctor.sh`（渠道体检，支持 `--json`）。

## v3.1.0 — 2026-08-19

- 首次发布：7 维打分模型、成本三档路由、社交口碑两阶段管线、子 Agent 搜索。
- 改进安装体验与版权署名。
