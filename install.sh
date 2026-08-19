#!/usr/bin/env bash
# ============================================================
# web-search-routing 一键安装脚本
# 自动探测当前 harness，复制 Skill 到正确的全局技能目录。
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/Shane0315/agent-web-search-routing/main/install.sh | bash
#   （或下载后执行：bash install.sh）
#
# 支持的 harness：
#   Codex        -> ~/.codex/skills/
#   Claude Code  -> ~/.claude/skills/
#   Proma        -> ~/.proma/default-skills/
#   其他/未识别  -> 交互式询问
# ============================================================
set -e

REPO="agent-web-search-routing"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEED_DOWNLOAD=0

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
  elif [ -d "$HOME/.proma/default-skills" ] || [ -d "$HOME/.proma-community/agent-workspaces" ]; then
    echo "proma"
  else
    echo "unknown"
  fi
}

install_to() {
  local dest="$1"
  mkdir -p "$dest/$REPO"
  cp -r "$SOURCE_DIR/SKILL.md" "$SOURCE_DIR/channels.yaml" "$SOURCE_DIR/INSTALL.md" "$dest/$REPO/" 2>/dev/null || true
  # 若仓库含 LICENSE/README 一并复制
  [ -f "$SOURCE_DIR/LICENSE" ] && cp "$SOURCE_DIR/LICENSE" "$dest/$REPO/" || true
  [ -f "$SOURCE_DIR/README.md" ] && cp "$SOURCE_DIR/README.md" "$dest/$REPO/" || true
  echo "✅ 已安装到 $dest/$REPO"
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
    install_to "$HOME/.proma/default-skills"
    echo "💡 Proma 提示：default-skills 为所有工作区共享，无需每个项目重复安装。"
    ;;
  unknown)
    echo "❓ 未识别 harness。请手动复制到你的 skills 目录："
    echo "   mkdir -p <你的skills目录>/$REPO"
    echo "   cp -r $SOURCE_DIR/* <你的skills目录>/$REPO/"
    ;;
esac

# 清理临时下载
if [ "$NEED_DOWNLOAD" = "1" ]; then
  rm -rf "${TMP_DIR}"
fi

echo ""
echo "🎉 安装完成！新开一个会话，问一个需要搜索的问题即可自动触发。"
echo "    首次触发会输出「渠道体检报告」，按提示补齐缺失渠道（Museon 必装 / Agent Reach 推荐）。"
