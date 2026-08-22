# doctor.sh JSON 输出说明

`bash doctor.sh --json` 输出一份单行 JSON，供 Agent 或自动化脚本判断当前环境是否具备 W3 搜索能力。它不打印密钥值，只报告渠道、安装位置、缺失项、警告和建议。

## 运行方式

```bash
bash doctor.sh --json
```

人类可读版本：

```bash
bash doctor.sh
```

## 顶层字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `schema_version` | number | JSON schema 版本。当前为 `1`。 |
| `ok` | boolean | 没有 required missing 时为 `true`。注意：存在 warning 时仍可能为 `true`，必须同时读取 `status`、`warnings` 和具体渠道字段。 |
| `status` | string | 总体状态：`required_missing`、`optional_missing`、`warnings`、`w3_ready`、`ok`。 |
| `skill_version` | string | 当前 Skill 版本。 |
| `script_dir` | string | `doctor.sh` 所在目录。 |
| `harness` | array | Codex / Claude / Proma 相关目录探测结果。 |
| `install_locations` | array | 各 harness 的 Skill 安装位置探测结果。 |
| `museon` | object | Museon CLI 安装、授权和版本状态。 |
| `agent_reach` | object | Agent Reach 安装、doctor 和小红书 backend 状态。 |
| `config_clues` | object | Tavily / Brave / 智谱配置线索，只返回 boolean，不返回密钥值。 |
| `required_missing` | string[] | 影响核心 W3 能力的缺失项；当前最关键的是 `museoncli`。 |
| `optional_missing` | string[] | 可选增强渠道或普通 API 搜索配置缺失。 |
| `missing` | string[] | `required_missing + optional_missing` 的并集，便于调用方快速判断。 |
| `warnings` | string[] | 非致命但可能影响体验的问题，例如 Agent Reach 已安装但小红书 backend 未激活。 |
| `hints` | string[] | 给 Agent 的下一步建议。 |

## status 语义

| status | 含义 | Agent 应如何处理 |
|---|---|---|
| `required_missing` | 缺少 W3 必需渠道，通常是 Museon 未安装或未授权 | W3 问题必须先说明能力缺口；用户同意后自动安装/授权 |
| `optional_missing` | Museon 可用，但 Tavily/Brave/智谱/Agent Reach 等增强项缺失 | 可继续 W3 发现；按需要建议增强 |
| `warnings` | 没有缺失项，但存在登录态/配置 warning | 继续执行，但在结论中说明限制 |
| `w3_ready` | Museon 已安装且 whoami 成功，可做 W3 发现 | 直接进入 Museon 发现阶段 |
| `ok` | 未发现缺失和 warning | 正常执行 |

状态选择优先级：

1. `w3_ready`：Museon 已安装且已授权；
2. `required_missing`：有 required missing；
3. `optional_missing`：有 optional missing；
4. `warnings`：只有 warnings；
5. `ok`：全部正常。

因此，只要 Museon 可用，`status` 通常就是 `w3_ready`，即使 Brave/智谱/Agent Reach 缺失或存在 warning。

## museon 对象

示例：

```json
{
  "installed": true,
  "path": "/home/example/.local/bin/museoncli",
  "whoami_ok": true,
  "version": "0.5.19",
  "auth_hint": "signed in"
}
```

判断规则：

- `installed=true` 且 `whoami_ok=true`：W3 发现能力可用。
- `installed=false`：加入 `required_missing: ["museoncli"]`。
- `installed=true` 但 `whoami_ok=false`：加入 warning，Agent 应走 OAuth/授权复测流程。

## agent_reach 对象

示例：

```json
{
  "installed": true,
  "path": "/home/example/.local/bin/agent-reach",
  "version_ok": true,
  "version": "Agent Reach v1.5.0",
  "doctor_ok": true,
  "xiaohongshu_status": "active",
  "active_backend": "opencli"
}
```

`xiaohongshu_status` 可能为：

- `active`：检测到小红书 backend；
- `inactive`：backend 明确为空或 none；
- `unknown`：无法从 doctor JSON 中确认。

Agent 不应编造平台命令；下一步必须以 `agent-reach doctor --json` 和官方文档为准。

## config_clues 对象

```json
{
  "tavily": false,
  "brave": false,
  "zhipu": false
}
```

这些只是配置线索：

- 不读取或输出密钥值；
- 普通 API 渠道缺失不会导致 `ok=false`；
- 是否使用这些渠道由 `SKILL.md` 的 W1-W7 打分和成本路由决定。

## 最小调用示例

```bash
bash doctor.sh --json | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
print({
  'status': data['status'],
  'ok': data['ok'],
  'required_missing': data['required_missing'],
  'museon': data['museon'],
  'agent_reach_active_backend': data['agent_reach'].get('active_backend'),
})
PY
```

## 兼容性约定

- `schema_version=1` 内尽量保持字段向后兼容；
- 新增字段不会视为 breaking change；
- 修改或删除现有字段前，必须提升 `schema_version`；
- Agent 应优先根据 `status`、`required_missing`、`museon`、`agent_reach` 决策，不要依赖人类可读文本。
