# Agent Web Search Routing

> 给任何 AI Agent 的「联网搜索决策大脑」：探测环境 → 7 维打分判断信息需求 → 成本自适应选渠道 → 社交口碑两阶段管线 → 复杂调研自动委派子 Agent。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Harness](https://img.shields.io/badge/harness-Codex%20%7C%20Claude%20%7C%20Proma%20%7C%20any-blue)](#)
[![Skill Version](https://img.shields.io/badge/version-3.1.0-green)](#)

## 为什么需要它？

当 Agent 需要联网搜索时，常见问题：

- 🤔 **不知道选哪个工具**：内置搜索、Tavily、Brave、智谱、Museon、Agent Reach……每个都能搜，但各有所长
- 💰 **重复付费**：明明有订阅（GPT/Claude）内置搜索，却还在调按量付费 API
- 🎯 **搜了也白搜**：搜索引擎结果被 SEO 污染，真人真实口碑（小红书/X/Reddit）搜不到
- 📚 **上下文爆炸**：一次搜索返回上万 token 塞进主上下文，稀释后续推理

这个 Skill 解决的就是这些问题——它是一份**决策规则**（SKILL.md），不绑定任何具体工具，告诉 Agent **什么时候搜、用什么搜、怎么组合、怎么省钱、怎么保质量**。

## 核心特性

- 🧠 **7 维信息需求打分**：事实/时效/真实口碑/深度/中文/英文/权威（0-3 分 + 语义锚点）
- 💰 **成本自适应路由**：订阅内置（Tier 0）→ 免费额度（Tier 1）→ 按量付费（Tier 2），沉没成本优先
- 🔍 **社交口碑两阶段管线**：Museon 高召回发现 → Agent Reach 原帖/评论核验 → 官方文档确认
- 🆕 **新用户自动引导**：首次触发输出「渠道体检报告」，缺什么引导装什么（Museon 必装 + Agent Reach 推荐）
- 🧩 **子 Agent 搜索**：复杂调研委派子 Agent 完成，主 Agent 只收几百字总结，上下文干净
- 🔌 **Harness 无关**：Codex / Claude Code / Proma / 任何支持 SKILL.md 的 Agent 都能用
- 🌐 **两类用户自适应**：API 按量用户 + 订阅制用户（GPT/Claude coding plan）自动识别

## 快速开始

### 1. 安装

复制 Skill 到你的 harness 全局技能目录：

```bash
# Codex
cp -r agent-web-search-routing ~/.codex/skills/

# Claude Code
cp -r agent-web-search-routing ~/.claude/skills/

# Proma
cp -r agent-web-search-routing ~/.proma/default-skills/

# 其他 harness：参照其 skills 目录
```

### 2. 编辑渠道表（可选）

`channels.yaml` 定义了所有可用渠道。开箱即用时 Skill 会自动探测；如果你已有某些工具，删除不需要的渠道条目即可。

### 3. 直接提问

新开会话，问一个需要搜索的问题，Skill 会自动触发。首次触发会输出「渠道体检报告」：

```
┌ 渠道体检报告 ┐
│ 内置搜索:  ✅ (订阅模式)
│ 智谱/Brave/Tavily: ❌
│ Museon:    ❌  ← W3 发现必需
│ Agent Reach: ❌ ← W3 核验增强
└─────────────┘
```

按引导安装缺失渠道即可。

## 工作原理

### 两级流程

```
简单任务（单事实/单语言）→ 快速路径：默认渠道搜一次，不打分
复杂任务（对比/口碑/YMYL/多语言）→ 完整 7 维打分 → 组合渠道
```

### 7 维打分模型

| 维度 | 含义 | 高分信号 |
|------|------|---------|
| W1 事实性 | 客观事实/数据 | 是什么/多少/日期/价格 |
| W2 时效性 | 最新/实时 | 最新/最近/本周/趋势 |
| **W3 真实性/口碑** | 真人体验 | 体验/评价/避雷/推荐 |
| W4 深度/专业 | 分析/文档 | 原理/报告/对比/评测 |
| W5 中文生态 | 国内语境 | 中文关键词/国内产品 |
| W6 英文生态 | 国际语境 | 英文关键词/海外技术 |
| W7 来源可信度 | 权威来源 | 官方/政府/论文/官网 |

### 成本三档路由

```
Tier 0  订阅内置搜索（GPT/Claude）  ← 沉没成本，边际≈0，优先用
Tier 1  免费额度（Tavily/Brave/Museon/Agent Reach）
Tier 2  按量付费（智谱等）          ← 克制使用
```

### 社交口碑两阶段管线（v3.1 核心）

搜索引擎（含 GPT/Claude 内置）抓不到社交平台原生内容，且不同工具排序差异大（实测同题前排重合率仅 6/10）。所以 W3 高分时：

```
第 1 阶段 · 发现    Museon（原生 API，高召回，含赞/评/藏数据）
        ↓ 挑 5-10 篇高互动/争议帖
第 2 阶段 · 核验    Agent Reach（Chrome 登录态，读原帖正文+评论）
        ↓ 区分：个案 | 误解 | 已修复 | 高频共识
第 3 阶段 · 确认    官方文档（仅价格/权益/功能变更时）
```

**实测对比**（「get笔记」小红书评价）：Museon 返回 35 条原生数据，Agent Reach 能继续读原帖评论区分真实问题与已修复 Bug——两者互补，不替代。

### 子 Agent 搜索

复杂调研（多维度/多工具/W3 口碑）自动委派子 Agent（research role），子 Agent 消化搜索结果后只返回几百字总结，主上下文保持干净。

## 文件结构

```
agent-web-search-routing/
├── SKILL.md         # 决策逻辑（Agent 读取的核心）
├── channels.yaml    # 渠道注册表（用户可编辑增删）
├── INSTALL.md       # 详细安装指南
├── LICENSE          # MIT
└── README.md        # 本文件
```

## 渠道生态

| 渠道 | 角色 | 成本 | 必装 |
|------|------|------|------|
| GPT/Claude 内置搜索 | Tier 0 通用 | 订阅内 | 订阅用户自动 |
| [Museon](https://github.com/Museon-AI/museon-cli) | W3 发现（小红书/X/Reddit 原生） | $0 免费档 | ⭐ 必装 |
| [Agent Reach](https://github.com/Panniantong/agent-reach) | W3 核验（15 平台路由器） | 开源免费 | 推荐 |
| Tavily | 英文通用 | 1000 credits/月 | 可选 |
| Brave Search | 英文/深度 | $5/月 | 可选 |
| 智谱 Web Search | 中文/深度 | 按量 | 可选 |

详见 [`channels.yaml`](channels.yaml) 和 [`INSTALL.md`](INSTALL.md)。

## 兼容的 Harness

- ✅ **OpenAI Codex / ChatGPT Desktop**（通过 `~/.codex/AGENTS.md` 注入，因 Codex 的 2% Skill 预算限制）
- ✅ **Claude Code / Claude Desktop**（原生 SKILL.md）
- ✅ **Proma**（`default-skills/` 全局）
- ✅ 任何支持 Markdown 指令文件的 Agent

## 设计原则

1. **决策与执行分离**：SKILL.md 是大脑，MCP/CLI 是手脚，不绑定具体工具
2. **沉没成本优先**：已付费的订阅搜索先用，按量付费克制
3. **不静默降级**：缺关键渠道（如 Museon）时明确告知质量影响，不假装搜了
4. **新用户友好**：Museon 必装 + Agent Reach 推荐，分级引导不劝退
5. **上下文经济**：复杂调研走子 Agent，主上下文不被搜索结果淹没

## Roadmap

- [ ] 自动探测脚本（`doctor` 命令一键输出渠道体检）
- [ ] 更多 harness 的安装模板（Cursor、Windsurf、Cline）
- [ ] 渠道质量反馈闭环（记录各渠道命中率，动态调权）
- [ ] 多语言 README（English）

## Contributing

Issues 和 PR 欢迎。提交前请确保：
- 不提交个人 API key、绝对路径、代理地址
- SKILL.md 保持 harness 无关（不写死具体工具名）
- channels.yaml 的新增渠道标注 tier/capability/required

## License

MIT © Harvey (Thor1992)

---

<p align="center">
如果这个 Skill 帮你省了 token 和钱，给个 ⭐ 吧
</p>
