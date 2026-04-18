#!/bin/bash
#
# Skill Sync - 即时同步 skill 到 GitHub 并更新 README
# 在 skill 创建/测试成功后调用
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"
SYNC_MARKER_DIR="$CLAUDE_DIR/.sync-markers"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[SYNC]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERR]${NC} $1"; }

# 获取 skill 信息
get_skill_info() {
    local skill_dir="$1"
    local skill_name=$(basename "$skill_dir")
    local description=""

    if [ -f "$skill_dir/SKILL.md" ]; then
        # 从 SKILL.md 提取描述（第一行非空行）
        description=$(grep -v "^#" "$skill_dir/SKILL.md" | grep -v "^$" | head -1 | cut -c1-80)
    fi

    echo "$skill_name|$description"
}

# 检查是否需要同步
needs_sync() {
    local skill_name="$1"
    local marker_file="$SYNC_MARKER_DIR/$skill_name"
    local skill_dir="$SKILLS_DIR/$skill_name"

    # 检查标记文件是否存在且比 SKILL.md 新
    if [ -f "$marker_file" ] && [ "$marker_file" -nt "$skill_dir/SKILL.md" ]; then
        return 1  # 不需要同步
    fi

    return 0  # 需要同步
}

# 更新 README.md 中的技能列表
update_readme() {
    local generator="$REPO_DIR/tools/generate-readme.js"

    if [ ! -f "$generator" ]; then
        log_warn "README 生成器不存在，跳过更新"
        return
    fi

    node "$generator"
    log_ok "README.md 已更新"
}

# 同步单个 skill
sync_skill() {
    local skill_name="$1"
    local skill_dir="$SKILLS_DIR/$skill_name"
    local target="$REPO_DIR/skills/$skill_name"
    local marker_file="$SYNC_MARKER_DIR/$skill_name"

    # 检查是否需要同步
    if ! needs_sync "$skill_name"; then
        log_info "Skill '$skill_name' 已是最新，跳过同步"
        return 2
    fi

    # 复制 skill 到 repo
    rm -rf "$target"
    cp -r "$skill_dir" "$target"
    rm -rf "$target/.git"

    # 创建同步标记
    mkdir -p "$SYNC_MARKER_DIR"
    touch "$marker_file"

    log_ok "Skill '$skill_name' 已复制到 repo"
    return 0
}

# 主同步函数
sync_to_github() {
    local specific_skill="$1"  # 可选：指定同步某个 skill
    local changed=0
    local synced_skills=""

    # 检查 repo 目录
    if [ ! -d "$REPO_DIR" ]; then
        log_err "Repo 目录不存在: $REPO_DIR"
        return 1
    fi

    cd "$REPO_DIR"

    # 同步 skills
    if [ -n "$specific_skill" ]; then
        # 同步指定 skill
        if sync_skill "$specific_skill"; then
            changed=1
            synced_skills="$specific_skill"
        fi
    else
        # 同步所有 skills
        for skill_dir in "$SKILLS_DIR"/*/; do
            [ -L "$skill_dir" ] && continue
            [ -f "$skill_dir/SKILL.md" ] || continue

            local skill_name=$(basename "$skill_dir")
            if sync_skill "$skill_name"; then
                changed=1
                synced_skills="$synced_skills $skill_name"
            fi
        done
    fi

    # 如果没有变化，直接返回
    if [ $changed -eq 0 ]; then
        log_info "没有需要同步的更改"
        return 0
    fi

    # 更新 README
    update_readme

    # Git 操作
    git add skills/ README.md 2>/dev/null || true

    if git diff --cached --quiet 2>/dev/null; then
        log_info "没有新的更改需要提交"
        return 0
    fi

    # 提交并推送
    local commit_msg="chore: sync skills${synced_skills:+ ($synced_skills)}"
    git commit -m "$commit_msg" 2>/dev/null || true

    if git push 2>/dev/null; then
        log_ok "已成功推送到 GitHub"

        # 输出总结
        echo ""
        echo "========================================"
        echo "✅ Skill 同步完成"
        echo "========================================"
        echo "已同步技能: $synced_skills"
        echo "GitHub 仓库: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')"
        echo "更新时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"

        return 0
    else
        log_err "推送到 GitHub 失败"
        return 1
    fi
}

# 显示帮助
show_help() {
    cat << 'EOF'
Skill Sync - 即时同步 skill 到 GitHub

用法:
  skill-sync [skill-name]    同步指定 skill 或所有 skills
  skill-sync --status        查看同步状态
  skill-sync --force [name]  强制同步（忽略标记）
  skill-sync --help          显示帮助

示例:
  skill-sync                 # 同步所有 skills
  skill-sync auto-browser    # 只同步 auto-browser
  skill-sync --force         # 强制同步所有

EOF
}

# 显示同步状态
show_status() {
    log_info "同步状态检查..."
    echo ""

    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -L "$skill_dir" ] && continue
        [ -f "$skill_dir/SKILL.md" ] || continue

        local skill_name=$(basename "$skill_dir")
        local marker_file="$SYNC_MARKER_DIR/$skill_name"
        local status="⏳ 待同步"

        if [ -f "$marker_file" ] && [ "$marker_file" -nt "$skill_dir/SKILL.md" ]; then
            status="✅ 已同步"
        fi

        printf "%-20s %s\n" "$skill_name" "$status"
    done
}

# 主函数
main() {
    case "$1" in
        --help|-h)
            show_help
            ;;
        --status)
            show_status
            ;;
        --force)
            rm -rf "$SYNC_MARKER_DIR"
            sync_to_github "$2"
            ;;
        "")
            sync_to_github
            ;;
        *)
            sync_to_github "$1"
            ;;
    esac
}

main "$@"
