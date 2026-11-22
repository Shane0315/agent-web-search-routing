# Agent Web Search Routing

**English** · [简体中文](README.md)

> A "web-search decision brain" for any AI agent: probe the environment → score the information need across 8 dimensions → pick channels cost-adaptively → run a two-stage social-proof pipeline → delegate heavy research to sub-agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Harness](https://img.shields.io/badge/harness-Codex%20%7C%20Claude%20%7C%20Proma%20%7C%20any-blue)](#)
[![Skill Version](https://img.shields.io/badge/version-3.5.0-green)](#)

**Browser requirement:** all browser-based search, original-post/comment verification, login and authorization must use **Ego Browser (ego lite)**. Load the `ego-browser` Skill first; if missing, install it through a verified official source or the harness's supported manager with the required consent, then read `ego-browser skill`. Never launch default Chrome, including through sub-agents or third-party backends. Check Skill availability, runtime and site login separately; stop on policy/permission denial. API/CLI search channels remain unchanged. See the [browser contract](SKILL.md#浏览器统一规则必须使用-ego-browser).

## Why you need it

Common failure modes when an agent goes online:

- 🤔 **No idea which tool to pick**: built-in search, Tavily, Brave, Zhipu, Museon, Agent Reach… they all "search", but each is good at something different
- 💰 **Paying twice**: you already pay for GPT/Claude with built-in search, yet the agent still burns pay-per-use API credits
- 🎯 **Searching and still learning nothing**: search results are SEO-polluted, and real user opinions (Xiaohongshu / X / Reddit) are unreachable
- 📚 **Context blowup**: one search dumps tens of thousands of tokens into the main context and dilutes later reasoning

This skill targets exactly those problems. It is a set of **decision rules** (`SKILL.md`), with flexible search providers and Ego Browser as the required browser, telling the agent **when to search, what to search with, how to combine channels, how to save money, and how to keep quality**.

## Key features

- 🧠 **8-dimension information-need scoring**: facts / freshness / social proof / depth / Chinese ecosystem / English ecosystem / source authority / hands-on troubleshooting (0–3 each, with semantic anchors)
- 💰 **Cost-adaptive routing**: subscription built-in (Tier 0) → free quota (Tier 1) → pay-per-use (Tier 2); sunk cost first
- 🆓 **Zero-cost self-hosted channel (v3.4, optional)**: one script deploys a local SearXNG — no quota ceiling, no API key; the cure for quota anxiety if you search a lot
- 🎯 **Vertical-domain structured retrieval (v3.5, optional)**: queries carrying identifiers (CVE / DOI / ticker / patent no. / library name) go straight to authoritative databases (OSV, NVD, PubMed, Crossref) instead of cross-checking three articles
- 🔍 **Two-stage social-proof pipeline**: Museon for high-recall discovery → Agent Reach to verify original posts and comments → official docs for confirmation
- 🆕 **Automatic onboarding**: the first trigger prints a "channel health report" and guides you to install only what is missing (Museon required, Agent Reach recommended)
- 🧩 **Sub-agent search**: complex research is delegated to a sub-agent; the main agent receives only a few hundred words, keeping context clean
- 🔌 **Harness-agnostic**: Codex / Claude Code / Proma / any agent that can read a `SKILL.md`
- 🌐 **Adapts to two user types**: pay-per-use API users and subscription users (GPT/Claude coding plans) are detected automatically

## Quick start

> 🚀 **First time? Read [`ONBOARDING.md`](ONBOARDING.md) first.** The 5-minute minimal success path is "install the skill → install Museon only → complete one W3 social-proof query". Agent Reach is the second-stage verification booster; browser and built-in search are last-resort fallbacks, not an equivalent social-proof experience.

### 0. The 5-minute minimal success path

1. Install this skill.
2. Install and authorize [Museon](https://github.com/Museon-AI/museon-cli) **only**, and get social-proof "discovery" working.
3. Open a new session and ask: `Find real user reviews of Notion — focus on complaints and recurring praise on Reddit.`
4. Install [Agent Reach](https://github.com/Panniantong/agent-reach) later, when you need post-by-post verification.

The first search prints a channel health report. If Museon is missing and the question is about reviews / word-of-mouth / red flags, the agent must state up front that it can only give a low-confidence fallback — it must not pretend to have completed a full W3 social-proof investigation.

### 1. Install (pick one)

**Option A: let the AI install it (recommended, zero commands)**

Just say this to your agent (Codex / Claude Code / Proma):

> Install a skill for me: web-search-routing. Repo: https://github.com/Shane0315/agent-web-search-routing

The agent downloads it and places it in the correct global skills directory. After that, just ask your question.

**Option B: one-line script**

```bash
curl -fsSL https://raw.githubusercontent.com/Shane0315/agent-web-search-routing/main/install.sh | bash
```

The script detects whether you use Codex / Claude Code / Proma and copies the skill to the right directory.

**Option C: manual copy (fallback)**

```bash
git clone https://github.com/Shane0315/agent-web-search-routing
# Codex
cp -R agent-web-search-routing ~/.codex/skills/
# Claude Code
cp -R agent-web-search-routing ~/.claude/skills/
# Proma (current): global skills directory
mkdir -p ~/.proma-community/default-skills
cp -R agent-web-search-routing ~/.proma-community/default-skills/
# Proma (current): to install into a single workspace only
# mkdir -p ~/.proma-community/agent-workspaces/<workspace>/skills
# cp -R agent-web-search-routing ~/.proma-community/agent-workspaces/<workspace>/skills/
# Legacy layout (pre-2025-08, compatibility only):
# mkdir -p ~/.proma/default-skills
# cp -R agent-web-search-routing ~/.proma/default-skills/
```

### 2. Edit the channel registry (optional)

`channels.yaml` declares every available channel. Out of the box the skill probes automatically; if you already have some tools, just delete the entries you do not need.

### 3. Just ask

Open a new session and ask anything that needs searching — the skill triggers itself. The first trigger prints a channel health report:

```text
┌ Channel health report ┐
│ Built-in search: ✅ (subscription mode)
│ SearXNG (local): ❌ (optional, zero-cost self-hosted)
│ Zhipu/Brave/Tavily: ❌
│ Museon:      ❌  ← required for W3 discovery
│ Agent Reach: ❌  ← W3 verification booster
└──────────────────────┘
```

Then install whatever is missing. If the question is about reviews / word-of-mouth / red flags and Museon is missing, the agent should ask for your consent and install it automatically; only browser OAuth / login steps need you.

## What's new in v3.4.0

> Zero-cost self-hosted search. Full history in [`CHANGELOG.md`](CHANGELOG.md).

If you search often, the monthly free quotas of Tavily / Firecrawl / Brave run out fast. v3.4 adds a **strictly optional** local SearXNG channel: $0, no quota ceiling, no API key, and no data leaving your machine.

```bash
bash install-searxng.sh     # one-shot deploy (an agent can run it unattended)
```

The script handles source install, a Python 3.12 environment, enabling the JSON API, **automatic proxy detection**, auto-start on boot, CLI wrappers, and health verification. It is idempotent, so re-running it on an existing install is safe. Once done:

```bash
searxng.sh "your query"            # slim JSON (agent-friendly)
searxng.sh "!github keyword"       # bang verticals — no other channel does this
```

Three boundaries that matter:

- **Skipping it breaks nothing.** In the health report it only lands in `optional_missing` and never affects `ok`. The agent will not push it on you — it only brings it up when you mention quota pressure.
- **New users should not install it first.** The shortest path is still "install the skill → install Museon → complete one W3 social-proof query".
- **It does not replace Museon + Agent Reach.** SearXNG is general web search; it cannot reach native Xiaohongshu / X / Reddit content, so W3 social proof and W8 hands-on troubleshooting still belong to social channels.

## What's new in v3.5.0

> Vertical-domain structured retrieval. Full history in [`CHANGELOG.md`](CHANGELOG.md).

All eight existing general channels can only do "keywords → web links". But when a query carries a structured identifier, what you actually need is the database record, not an article. v3.5 adds [AnySearch](https://github.com/anysearch-ai/anysearch-skill) (**strictly optional**) to fill that gap, plus a new "vertical-first" routing rule: on a hit, skip the cost ordering and go straight to vertical retrieval.

**Measured comparison** (which versions does `CVE-2024-3094` affect?):

```text
General search (incl. Tavily)  → three articles mentioning 5.6.0 / 5.6.1 in prose
AnySearch vertical retrieval   → 411ms, structured OSV + NVD records:
                                 exact CPE version identifiers, CVSS:3.1 vector,
                                 full advisory reference chain
```

### How does it relate to Tavily? (not a replacement)

This is the easiest point to misread. After measuring, the division of labour is:

| | Tavily | AnySearch |
|---|---|---|
| Return shape | links + **extracted body text** + answer summary | links + short snippet (general) / structured record (vertical) |
| General search | ✅ the default choice; solid on Chinese too | no added edge (same top hit as SearXNG) |
| Identifier queries | only pages *about* the topic | ✅ **irreplaceable**, reads authoritative DBs |
| Parallel batch | — | ✅ `batch_search` |

Conclusion: **Tavily remains the Tier 1 default for general search**; AnySearch only takes over inside vertical domains. That is why it sits *after* Tavily in `tier1_order` yet jumps the queue entirely on a vertical hit.

### Three boundaries that matter

- **Skipping it breaks nothing.** It only lands in `optional_missing` and never affects `ok`.
- **It does not support Xiaohongshu.** Measured: `type=xiaohongshu` silently degrades to general search and returns vendor sites instead of user reviews. So **W3 social proof and W8 troubleshooting still start with Museon**; AnySearch only supplements discovery on Reddit / Zhihu / Weibo.
- **Routing authority stays here.** AnySearch's own SKILL.md calls itself "the recommended search tool" and defaults to the vertical path; when both skills are loaded it is a **channel being dispatched**, not a parallel decision-maker.

For installation (canonical directory + symlinks, to avoid per-harness version drift) see [`INSTALL.md`](INSTALL.md) § 2.8.

## How it works

### Two-level flow

```text
Simple task (single fact / single language) → fast path: one search on the default channel, no scoring
  ※ Exception: hands-on troubleshooting ("why doesn't X work / how do I configure / I'm not receiving")
    always gets scored, even when the question is short (W8)
Complex task (comparison / social proof / troubleshooting / YMYL / multilingual)
  → full 8-dimension scoring → channel combination
```

### The 8-dimension scoring model

| Dimension | Meaning | High-score signals |
|------|------|---------|
| W1 Factuality | Objective facts / figures | what is / how much / date / price |
| W2 Freshness | Latest / real-time | latest / recent / this week / trend |
| **W3 Authenticity / social proof** | Real human experience | experience / review / red flags / recommendation |
| W4 Depth / expertise | Analysis / documentation | how it works / report / comparison / evaluation |
| W5 Chinese ecosystem | Domestic (China) context | Chinese keywords / domestic products |
| W6 English ecosystem | International context | English keywords / overseas tech |
| W7 Source authority | Authoritative sources | official / government / papers / vendor site |
| **W8 Hands-on experience / troubleshooting** (added in v3.3) | Fixes verified by people who hit the same wall | why doesn't … work / not receiving / how to configure / anyone else seeing this |

> **Key change in v3.3**: for hands-on troubleshooting and everyday-experience questions (W8, e.g. "why am I not receiving WeChat Work friend requests"), native social channels such as Xiaohongshu go **first**, and general web search is demoted to a supplement. In practice general search returns mostly SEO-farm content for these questions, while social platforms are full of people who hit the same problem and posted the real cause and fix.

### Three cost tiers

```text
Tier 0  Subscription built-in search (GPT/Claude)  ← sunk cost, marginal ≈ 0, use first
Tier 1  Zero-cost self-hosted (SearXNG, optional)  ← v3.4: try it before quota channels
        Free quota (Tavily/Brave/Museon/Agent Reach)
Tier 2  Pay-per-use (Zhipu, etc.)                  ← use sparingly

※ v3.5 exception: queries carrying structured identifiers (CVE / DOI / ticker / patent no. /
  library name) **skip the ordering above** and go straight to AnySearch vertical retrieval —
  the gap there is a capability difference, not a marginal optimisation.
```

### Social-proof and hands-on-experience pipeline (v3.3: W3 + W8)

**Channel priority is routed by question type**: experience-type questions (W3 ≥ 2 or W8 ≥ 2) start with Museon (Xiaohongshu), while built-in/web search only fills in official information. Only pure-fact questions follow the cost tiers (Tier 0 → 1 → 2).

Search engines — including GPT/Claude built-in search — cannot reach native social content, and different tools rank very differently (measured top-result overlap on the same question was only 6/10). So when W3/W8 score high:

```text
Stage 1 · Discover  Museon (native API, high recall, includes likes/comments/saves)
        ↓ pick 5–10 high-engagement or controversial posts
Stage 2 · Verify    Agent Reach (Chrome logged-in session, reads post body + comments)
        ↓ classify: isolated case | misunderstanding | already fixed | broad consensus
Stage 3 · Confirm   Official docs (only for pricing / entitlements / feature changes)
```

**Field comparison 1** (Xiaohongshu reviews of the "get notes" app): Museon returned 35 native items, and Agent Reach could then read the comment sections to separate genuine problems from already-fixed bugs — complementary, not redundant.

**Field comparison 2** (the motivating case for v3.3, "why am I not receiving WeChat Work friend requests from personal WeChat"): general web search results were basically unusable (SEO content, outdated advice); Xiaohongshu search surfaced people with the same problem posting the real cause and the settings path, which actually solved it. This kind of "real people, real workaround" is exactly why W8 exists.

### Sub-agent search

Complex research (multi-dimension / multi-tool / W3 social proof) is automatically delegated to a sub-agent (research role). The sub-agent digests the search results and returns only a few hundred words, keeping the main context clean.

## File layout

```text
agent-web-search-routing/
├── SKILL.md         # decision logic (the core the agent reads)
├── ONBOARDING.md    # 5-minute minimal success path for first use
├── channels.yaml    # channel registry (users can add/remove entries)
├── INSTALL.md       # detailed installation guide
├── install.sh       # one-shot installer (auto-detects harness)
├── install-museon.sh       # Museon install/authorization helper
├── install-agent-reach.sh  # Agent Reach install/doctor helper
├── install-searxng.sh      # local SearXNG zero-cost channel deploy (v3.4, optional)
├── doctor.sh        # channel health check (text/JSON)
├── scripts/test.sh  # minimal regression tests
├── docs/new-user-dogfooding.md # clean-new-user experience regression SOP
├── docs/doctor-json.md         # doctor.sh --json field reference
├── CHANGELOG.md     # release notes
├── LICENSE          # MIT
├── README.md        # Chinese README
└── README.en.md     # this file
```

## Channel ecosystem

| Channel | Role | Cost | Required |
|------|------|------|------|
| GPT/Claude built-in search | Tier 0 general | included in subscription | automatic for subscribers |
| [Museon](https://github.com/Museon-AI/museon-cli) | W3 discovery (native Xiaohongshu/X/Reddit) | $0 free tier | ⭐ required |
| [Agent Reach](https://github.com/Panniantong/agent-reach) | W3 verification (15-platform router) | open source, free | recommended |
| [SearXNG (self-hosted)](https://github.com/searxng/searxng) | Tier 1 general (zero cost) | $0, no ceiling | optional (v3.4; recommended for heavy search) |
| [AnySearch](https://github.com/anysearch-ai/anysearch-skill) | **vertical-domain structured retrieval** (16 domains) | free anonymous tier | optional (v3.5; recommended for CVE/DOI/ticker queries) |
| Tavily | English general (with body extraction) | 1000 credits/month | optional |
| Firecrawl | English general / scraping | 500 credits/month | optional |
| Brave Search | English / depth | $5/month | optional |
| Zhipu Web Search | Chinese / depth | pay-per-use | optional |

See [`channels.yaml`](channels.yaml) and [`INSTALL.md`](INSTALL.md) for details.

## Supported harnesses

- ✅ **OpenAI Codex / ChatGPT Desktop** (injected via `~/.codex/AGENTS.md`, because of Codex's 2% skill budget limit)
- ✅ **Claude Code / Claude Desktop** (native `SKILL.md`)
- ✅ **Proma** (`install.sh` syncs to every workspace skills directory plus global `default-skills`)
- ✅ Any agent that can read Markdown instruction files

## Design principles

1. **Separate decision from execution**: `SKILL.md` is the brain, MCP/CLI tools are the hands; no hard-coded vendor
2. **Sunk cost first**: use the search you already pay for; be sparing with pay-per-use
3. **No silent degradation**: when a key channel (e.g. Museon) is missing, say clearly that only a low-confidence fallback is possible instead of faking a completed investigation
4. **New-user friendly**: get Museon working first, treat Agent Reach as an upgrade; tiered guidance instead of a wall of setup
5. **Context economy**: route complex research through sub-agents so the main context is not flooded with raw results

## Roadmap

- [x] Auto-probe script (`bash doctor.sh` / `bash doctor.sh --json`)
- [x] Multilingual README (English)
- [ ] Install templates for more harnesses (Cursor, Windsurf, Cline)
- [ ] Channel quality feedback loop (track hit rate per channel, re-weight dynamically)

## Contributing

Issues and PRs are welcome. Before submitting, please make sure:
- no personal API keys, absolute paths, or proxy addresses are committed
- `SKILL.md` stays harness-agnostic (no hard-coded tool names)
- new channels in `channels.yaml` declare tier / capability / required

## License

MIT © Shane0315

---

<p align="center">
If this skill saved you tokens and money, consider leaving a ⭐
</p>
