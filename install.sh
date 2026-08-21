#!/usr/bin/env bash
# ============================================================
# web-search-routing 一键安装脚本
# 自动探测当前 harness，复制 Skill 到正确的全局技能目录。
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/Shane0315/agent-web-search-routing/main/install.sh | bash
#   （或下载后执行：bash install.sh）
#
# 非交互模式（CI / 自动化 / 脚本）：
#   INSTALL_HARNESS=codex|claude|proma bash install.sh   # 跳过询问，直接安装到对应目录
#   INSTALL_HARNESS=/自定义/skills目录  bash install.sh   # 装到指定目录（绝对路径）
#
# 支持的 harness：
#   Codex        -> ~/.codex/skills/
#   Claude Code  -> ~/.claude/skills/
#   Proma        -> ~/.proma-community/agent-workspaces/*/skills/ + ~/.proma-community/default-skills/（全部工作区）
#   其他/未识别  -> 交互式询问（列出选项让用户选择）
# ============================================================
set -euo pipefail

REPO="agent-web-search-routing"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEED_DOWNLOAD=0
TMP_DIR=""
INSTALLED=0

# ---- 若从 curl 管道执行（无本地目录），先克隆到临时目录 ----
if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  NEED_DOWNLOAD=1
  TMP_DIR="$(mktemp -d)"
  echo "📦 下载 skill 到临时目录..."
  git clone --depth 1 "https://github.com/Shane0315/$REPO.git" "$TMP_DIR/$REPO" 2>/dev/null \
    || curl -fsSL "https://github.com/Shane0315/$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP_DIR"
  SOURCE_DIR="$TMP_DIR/${REPO}-main"
  # 兼容 tar 解包目录名
  [ -d "$SOURCE_DIR" ] || SOURCE_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name '*agent-web-search-routing*' | head -1)"
fi

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "❌ 未找到 SKILL.md，安装中止。"
  exit 1
fi

detect_harness() {
  if [ -d "$HOME/.codex/skills" ] || [ -n "$CODEX_HOME" ]; then
    echo "codex"
  elif [ -d "$HOME/.claude/skills" ]; then
    echo "claude"
  elif [ -d "$HOME/.proma-community" ] || [ -d "$HOME/.proma/default-skills" ]; then
    echo "proma"
  else
    echo "unknown"
  fi
}

install_proma() {
  # Proma 全局机制：每个工作区有自己的 skills 目录，且存在全局 default-skills。
  # 最稳妥做法是全部安装（各工作区 + 全局 + 旧架构兼容），确保任何工作区都能加载。
  local installed_any=0
  # 1) 新版：所有 agent-workspaces 下的工作区 skills 目录
  if [ -d "$HOME/.proma-community/agent-workspaces" ]; then
    for ws in "$HOME"/.proma-community/agent-workspaces/*/; do
      [ -d "$ws" ] || continue
      if install_to "${ws}skills"; then
        installed_any=1
      fi
    done
  fi
  # 2) 新版：全局 default-skills（跨工作区共享）
  if [ -d "$HOME/.proma-community/default-skills" ] || [ -d "$HOME/.proma-community" ]; then
    mkdir -p "$HOME/.proma-community/default-skills" 2>/dev/null || true
    if install_to "$HOME/.proma-community/default-skills"; then
      installed_any=1
    fi
  fi
  # 3) 旧架构兼容（8 月前版本用 ~/.proma/default-skills）
  if [ -d "$HOME/.proma/default-skills" ] || [ -d "$HOME/.proma" ]; then
    mkdir -p "$HOME/.proma/default-skills" 2>/dev/null || true
    if install_to "$HOME/.proma/default-skills"; then
      installed_any=1
    fi
  fi
  if [ "$installed_any" = "1" ]; then
    echo "💡 Proma 提示：已同步到所有工作区 skills 目录 + 全局 default-skills，任一工作区均可加载。"
  else
    echo "❌ 未找到可用的 Proma skills 目录，安装中止。"
    exit 1
  fi
}

install_to() {
  local dest="$1"
  local required_files=(SKILL.md channels.yaml INSTALL.md ONBOARDING.md doctor.sh install.sh README.md LICENSE)
  local optional_assets=(install-museon.sh install-agent-reach.sh scripts docs)
  if ! mkdir -p "$dest/$REPO"; then
    echo "❌ 无法创建目录 $dest/$REPO，安装中止。"
    return 1
  fi
  local file
  local file
  for file in "${required_files[@]}"; do
    if [ ! -e "$SOURCE_DIR/$file" ]; then
      echo "❌ 缺少运行时文件 $file，安装中止。"
      return 1
    fi
    if ! cp -R "$SOURCE_DIR/$file" "$dest/$REPO/"; then
      echo "❌ 复制文件 $file 失败，安装中止。"
      if [ -n "$TMP_DIR" ]; then
        echo "   已下载的临时文件保留在 $TMP_DIR（修复网络/权限问题后可重试）。"
      fi
      return 1
    fi
  done
  local asset
  for asset in "${optional_assets[@]}"; do
    if [ -e "$SOURCE_DIR/$asset" ]; then
      local target_parent="$dest/$REPO/$(dirname "$asset")"
      mkdir -p "$target_parent" 2>/dev/null || true
      cp -R "$SOURCE_DIR/$asset" "$target_parent/" 2>/dev/null || true
    fi
  done
  echo "✅ 已安装到 $dest/$REPO"
  INSTALLED=1
}

HARNESS="$(detect_harness)"
echo "🔍 检测到 harness: $HARNESS"

case "$HARNESS" in
  codex)
    install_to "$HOME/.codex/skills"
    echo "💡 Codex 提示：Skill 描述超 2% 预算可能被截断，建议把核心规则同步到 ~/.codex/AGENTS.md（见 README 兼容章节）。"
    ;;
  claude)
    install_to "$HOME/.claude/skills"
    ;;
  proma)
    install_proma
    ;;
  unknown)
    echo ""
    echo "❓ 未检测到你已安装的 Agent 客户端（未发现 ~/.codex、~/.claude、~/.proma 任一目录）。"
    echo ""
    echo "   web-search-routing 是一个 Agent skill，需要配合 Agent 客户端使用。"
    echo "   请选择你要安装到的客户端（脚本会自动装到其全局 skills 目录）："
    echo ""
    echo "   [1] Codex (OpenAI)           -> ~/.codex/skills/"
    echo "   [2] Claude Code (Anthropic)  -> ~/.claude/skills/"
    echo "   [3] Proma                    -> 所有工作区 skills 目录 + 全局 default-skills"
    echo "   [4] 其他（我自己输入 skills 目录的完整路径）"
    echo "   [0] 我还没有安装任何 Agent 客户端"
    echo ""
    install_choice=""
    if [ -n "$INSTALL_HARNESS" ]; then
      # 非交互模式：由环境变量指定（CI/自动化）
      case "$INSTALL_HARNESS" in
        codex)  install_choice="1" ;;
        claude) install_choice="2" ;;
        proma)  install_choice="3" ;;
        /*)     install_choice="custom:$INSTALL_HARNESS" ;;
        *)
          echo "❌ 无效的 INSTALL_HARNESS: $INSTALL_HARNESS（可选 codex / claude / proma / 绝对路径）"
          exit 1
          ;;
      esac
    elif [ -t 0 ]; then
      # 交互模式：标准终端
      read -r -p "请输入编号 [0-4]: " install_choice
    elif read -r -p "请输入编号 [0-4]: " install_choice < /dev/tty 2>/dev/null; then
      # 交互模式：curl 管道执行时改从终端读取
      :
    else
      echo "⚠️  当前为非交互环境，无法询问安装目标。"
      echo "   请重新运行并指定客户端：INSTALL_HARNESS=codex|claude|proma bash install.sh"
      exit 1
    fi
    case "$install_choice" in
      1) install_to "$HOME/.codex/skills" ;;
      2) install_to "$HOME/.claude/skills" ;;
      3) install_proma ;;
      4)
        # 交互式自定义路径：提示用户输入完整目录
        custom_dir=""
        if [ -t 0 ]; then
          read -r -p "请输入 skills 目录的完整路径（例如 /path/to/skills）: " custom_dir
        elif read -r -p "请输入 skills 目录的完整路径: " custom_dir < /dev/tty 2>/dev/null; then
          :
        fi
        if [ -n "$custom_dir" ]; then
          install_to "$custom_dir"
        else
          echo "❌ 未输入有效路径，安装已取消。"
        fi
        ;;
      custom:*) install_to "${install_choice#custom:}" ;;
      0|"")
        echo ""
        echo "👋 你选择了「还没有安装任何 Agent 客户端」。"
        echo ""
        echo "   web-search-routing 是一个 skill，需要配合 Agent 客户端才能使用。"
        echo "   请先安装其中一个客户端："
        echo "     - Codex (OpenAI)：         https://openai.com/codex"
        echo "     - Claude Code (Anthropic)：https://docs.anthropic.com/en/docs/claude-code"
        echo "     - Proma：                  https://proma.cool"
        echo ""
        echo "   装好客户端后，重新运行本脚本即可自动完成安装。"
        echo "   （本次未安装任何文件。）"
        ;;
      *)
        echo "❌ 无效输入（请输入 0-4 的数字），安装已取消。"
        echo "   可重新运行：bash install.sh；或指定客户端：INSTALL_HARNESS=codex|claude|proma bash install.sh"
        ;;
    esac
    ;;
esac

# 清理临时下载：仅在上游复制成功后清理；
# 复制失败时 set -e 已提前退出，TMP_DIR 会保留（便于排查，见 install_to 内提示）。
if [ "$NEED_DOWNLOAD" = "1" ] && [ "$INSTALLED" = "1" ]; then
  rm -rf "${TMP_DIR}"
fi

# 仅在真实安装成功后才提示完成；unknown 场景未安装时不误报「安装完成」
if [ "$INSTALLED" = "1" ]; then
  echo ""
  echo "🎉 安装完成！新开一个会话，问一个需要搜索的问题即可自动触发。"
  echo "    首次触发会输出「渠道体检报告」；若缺少 Museon，Agent 会优先尝试自动检查和安装，只有浏览器 OAuth/登录步骤需要你操作。"
fi
