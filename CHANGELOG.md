# 更新日志

本项目版本号与 `SKILL.md` / `channels.yaml` / `doctor.sh` 中的 Skill 版本锚点保持一致，
由 `scripts/test.sh` 强制校验。

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

## v3.2.0 — 2026-08-22

- 新增 `ONBOARDING.md`（5 分钟最小成功路径）与 `doctor.sh`（渠道体检，支持 `--json`）。
- 强化 `install.sh` 与 doctor 自动化健壮性。

## v3.1.x — 2026-08-19 ~ 08-20

- 修复 Proma 安装目录不匹配（P0）与自定义路径选择（P1）。
- 改进安装体验与版权署名。

## v3.1.0 — 2026-08-19

- 首次发布：7 维打分模型、成本三档路由、社交口碑两阶段管线、子 Agent 搜索。
