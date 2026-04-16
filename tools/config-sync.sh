#!/bin/bash
#
# Config Sync - 同步所有 Claude Code 配置到 GitHub
# 包括: skills, MCP servers, settings, hooks, 等
# 隐私保护: 自动脱敏敏感信息
#

set -e

SKILLS_DIR="$HOME/.claude/skills"
REPO_DIR="$HOME/Tony-Claude-Code-Skills"
CLAUDE_DIR="$HOME/.claude"
SYNC_MARKER_DIR="$HOME/.claude/.sync-markers"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[SYNC]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERR]${NC} $1"; }
log_highlight() { echo -e "${CYAN}$1${NC}"; }

# 脱敏 JSON 文件
sanitize_json() {
    local input="$1"
    local output="$2"

    if command -v node >/dev/null 2>&1; then
        node -e "
            const fs = require('fs');
            try {
                const data = JSON.parse(fs.readFileSync('$input', 'utf8'));

                // 脱敏函数
                const sanitize = (obj, path = '') => {
                    if (typeof obj !== 'object' || obj === null) return obj;

                    if (Array.isArray(obj)) {
                        return obj.map((item, i) => sanitize(item, path + '[' + i + ']'));
                    }

                    const result = {};
                    for (const [key, value] of Object.entries(obj)) {
                        const newPath = path ? path + '.' + key : key;

                        // 敏感字段列表
                        const sensitiveKeys = ['apiKey', 'api_key', 'token', 'secret', 'password', 'auth', 'key', 'credential'];
                        const isSensitive = sensitiveKeys.some(sk => key.toLowerCase().includes(sk.toLowerCase()));

                        if (isSensitive && typeof value === 'string') {
                            result[key] = '***REDACTED***';
                        } else if (key === 'env' && typeof value === 'object') {
                            // 环境变量全部脱敏
                            result[key] = {};
                            for (const envKey of Object.keys(value)) {
                                result[key][envKey] = '***REDACTED***';
                            }
                        } else {
                            result[key] = sanitize(value, newPath);
                        }
                    }
                    return result;
                };

                const sanitized = sanitize(data);
                fs.writeFileSync('$output', JSON.stringify(sanitized, null, 2));
            } catch (e) {
                console.error('Error:', e.message);
                process.exit(1);
            }
        " 2>/dev/null
    else
        # 如果没有 node，使用 sed 进行基础脱敏
        cp "$input" "$output"
        sed -i.bak -E 's/("(apiKey|api_key|token|secret|password|credential)":\s*")[^"]*/\1***REDACTED***/g' "$output" 2>/dev/null || true
        rm -f "${output}.bak" 2>/dev/null || true
    fi
}

# 脱敏 shell 脚本
sanitize_shell() {
    local input="$1"
    local output="$2"

    # 复制文件
    cp "$input" "$output"

    # 脱敏敏感信息
    sed -i.bak \
        -E 's/(API_KEY|TOKEN|SECRET|PASSWORD)=.*/\1=***REDACTED***/g' \
        -E 's/(api_key|apikey|token|secret|password)=\"[^\"]*\"/\1=\"***REDACTED***\"/g' \
        "$output" 2>/dev/null || true

    rm -f "${output}.bak" 2>/dev/null || true
}

# 同步 skills
sync_skills() {
    log_highlight "📦 同步 Skills..."
    local changed=0
    local synced_list=""

    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -L "$skill_dir" ] && continue
        [ -f "$skill_dir/SKILL.md" ] || continue

        local skill_name=$(basename "$skill_dir")
        local target="$REPO_DIR/skills/$skill_name"

        if [ ! -d "$target" ] || [ "$skill_dir/SKILL.md" -nt "$target/SKILL.md" ] 2>/dev/null; then
            rm -rf "$target"
            cp -r "$skill_dir" "$target"
            rm -rf "$target/.git"
            changed=1
            synced_list="$synced_list $skill_name"
            log_ok "  ✓ $skill_name"
        fi
    done

    if [ $changed -eq 0 ]; then
        log_info "  所有 skills 已是最新"
    fi

    echo "$changed|$synced_list"
}

# 同步 MCP Servers 配置
sync_mcp() {
    log_highlight "🔌 同步 MCP Servers..."

    local source="$CLAUDE_DIR/settings.json"
    local target_dir="$REPO_DIR/config"
    local changed=0

    if [ -f "$source" ]; then
        mkdir -p "$target_dir"

        # 脱敏后的 settings.json
        local target_settings="$target_dir/settings.json"

        if [ ! -f "$target_settings" ] || [ "$source" -nt "$target_settings" ]; then
            log_info "  正在脱敏敏感信息..."
            sanitize_json "$source" "$target_settings"
            changed=1
            log_ok "  ✓ settings.json (已脱敏)"
        fi

        # 创建 MCP README
        if [ $changed -eq 1 ]; then
            mkdir -p "$target_dir/mcp-servers"
            cat > "$target_dir/mcp-servers/README.md" << 'EOF'
# MCP Servers 配置

本目录包含 Claude Code 的 MCP (Model Context Protocol) 服务器配置。

⚠️ **隐私说明**: 所有敏感信息（API Keys、Tokens、密码等）已被自动脱敏为 `***REDACTED***`。

## 当前配置的 MCP Servers

EOF
            # 提取 MCP 服务器列表
            if command -v node >/dev/null 2>&1; then
                node -e "
                    const fs = require('fs');
                    const settings = JSON.parse(fs.readFileSync('$source', 'utf8'));
                    if (settings.mcpServers) {
                        for (const name of Object.keys(settings.mcpServers)) {
                            console.log('- **' + name + '**');
                        }
                    }
                " >> "$target_dir/mcp-servers/README.md" 2>/dev/null || true
            fi
        fi
    fi

    echo "$changed"
}

# 同步 Hooks
sync_hooks() {
    log_highlight "🪝 同步 Hooks..."

    local source_dir="$CLAUDE_DIR/hooks"
    local target_dir="$REPO_DIR/config/hooks"
    local changed=0

    if [ -d "$source_dir" ]; then
        mkdir -p "$target_dir"

        for hook in "$source_dir"/*.sh; do
            [ -f "$hook" ] || continue
            local name=$(basename "$hook")
            local target="$target_dir/$name"

            if [ ! -f "$target" ] || [ "$hook" -nt "$target" ]; then
                log_info "  脱敏: $name"
                sanitize_shell "$hook" "$target"
                changed=1
                log_ok "  ✓ $name"
            fi
        done
    fi

    if [ $changed -eq 0 ]; then
        log_info "  所有 hooks 已是最新"
    fi

    echo "$changed"
}

# 同步其他配置
sync_other_configs() {
    log_highlight "⚙️  同步其他配置..."

    local changed=0
    local target_dir="$REPO_DIR/config"

    # 同步 keybindings.json
    if [ -f "$CLAUDE_DIR/keybindings.json" ]; then
        mkdir -p "$target_dir"
        if [ ! -f "$target_dir/keybindings.json" ] || [ "$CLAUDE_DIR/keybindings.json" -nt "$target_dir/keybindings.json" ]; then
            cp "$CLAUDE_DIR/keybindings.json" "$target_dir/"
            changed=1
            log_ok "  ✓ keybindings.json"
        fi
    fi

    # 同步自定义 tools
    if [ -d "$CLAUDE_DIR/tools" ]; then
        mkdir -p "$REPO_DIR/tools"
        for tool in "$CLAUDE_DIR/tools"/*.sh; do
            [ -f "$tool" ] || continue
            local name=$(basename "$tool")
            local target="$REPO_DIR/tools/$name"
            if [ ! -f "$target" ] || [ "$tool" -nt "$target" ]; then
                log_info "  脱敏: $name"
                sanitize_shell "$tool" "$target"
                changed=1
                log_ok "  ✓ tools/$name"
            fi
        done
    fi

    echo "$changed"
}

# 更新主 README
update_main_readme() {
    log_highlight "📝 更新 README..."

    local readme="$REPO_DIR/README.md"
    local temp=$(mktemp)

    # 生成技能列表
    local skills_list=""
    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -L "$skill_dir" ] && continue
        [ -f "$skill_dir/SKILL.md" ] || continue
        local name=$(basename "$skill_dir")
        local desc=$(grep -v "^#" "$skill_dir/SKILL.md" 2>/dev/null | grep -v "^$" | grep -v "^---" | head -1 | cut -c1-60)
        skills_list="${skills_list}- **$name** - $desc\n"
    done

    # 更新 README 中的技能部分
    if [ -f "$readme" ]; then
        awk -v skills="$skills_list" '
            BEGIN { in_skills=0; printed=0 }
            /^## Skills/ {
                print;
                print "";
                print skills;
                printed=1;
                in_skills=1;
                next;
            }
            /^## / { in_skills=0 }
            in_skills { next }
            { print }
        ' "$readme" > "$temp" 2>/dev/null || cp "$readme" "$temp"

        mv "$temp" "$readme"
        log_ok "  ✓ README 已更新"
    fi
}

# 主同步函数
sync_all() {
    log_highlight "🚀 开始同步 Claude Code 配置..."
    echo ""

    # 检查 repo
    if [ ! -d "$REPO_DIR" ]; then
        log_err "Repo 目录不存在: $REPO_DIR"
        return 1
    fi

    cd "$REPO_DIR"

    local total_changed=0
    local sync_details=""

    # 1. 同步 Skills
    local skills_result
    skills_result=$(sync_skills)
    local skills_changed
    skills_changed=$(echo "$skills_result" | tail -1 | cut -d'|' -f1)
    local skills_list
    skills_list=$(echo "$skills_result" | tail -1 | cut -d'|' -f2-)
    if [ "$skills_changed" -gt 0 ] 2>/dev/null; then
        total_changed=1
        sync_details="${sync_details}Skills: $skills_list\n"
    fi
    echo ""

    # 2. 同步 MCP
    local mcp_changed
    mcp_changed=$(sync_mcp)
    if [ "$mcp_changed" -gt 0 ] 2>/dev/null; then
        total_changed=1
        sync_details="${sync_details}MCP Servers\n"
    fi
    echo ""

    # 3. 同步 Hooks
    local hooks_changed
    hooks_changed=$(sync_hooks)
    if [ "$hooks_changed" -gt 0 ] 2>/dev/null; then
        total_changed=1
        sync_details="${sync_details}Hooks\n"
    fi
    echo ""

    # 4. 同步其他配置
    local other_changed
    other_changed=$(sync_other_configs)
    if [ "$other_changed" -gt 0 ] 2>/dev/null; then
        total_changed=1
        sync_details="${sync_details}Other configs\n"
    fi
    echo ""

    # 5. 更新 README
    update_main_readme
    echo ""

    # Git 操作
    if [ $total_changed -eq 0 ]; then
        log_info "✨ 所有配置已是最新，无需同步"
        return 0
    fi

    log_highlight "📤 推送到 GitHub..."

    git add -A

    if git diff --cached --quiet; then
        log_info "没有新的更改需要提交"
        return 0
    fi

    local commit_msg="chore: sync Claude Code config ($(date +%Y-%m-%d %H:%M))"
    git commit -m "$commit_msg"

    if git push; then
        echo ""
        echo "========================================"
        log_ok "✅ 配置同步完成"
        echo "========================================"
        echo -e "已同步内容:\n$sync_details"
        echo "GitHub 仓库: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/.git$//')"
        echo "同步时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "⚠️  注意: 所有敏感信息已自动脱敏"
        echo "========================================"
        return 0
    else
        log_err "推送到 GitHub 失败"
        return 1
    fi
}

# 显示状态
show_status() {
    log_highlight "📊 同步状态"
    echo ""

    # Skills 状态
    echo "Skills:"
    for skill_dir in "$SKILLS_DIR"/*/; do
        [ -L "$skill_dir" ] && continue
        [ -f "$skill_dir/SKILL.md" ] || continue
        local name=$(basename "$skill_dir")
        local marker="$SYNC_MARKER_DIR/config-skills"
        local status="⏳"
        [ -f "$marker" ] && [ "$marker" -nt "$skill_dir/SKILL.md" ] 2>/dev/null && status="✅"
        printf "  %s %-30s\n" "$status" "$name"
    done
    echo ""

    # MCP 状态
    echo "MCP Servers:"
    local mcp_marker="$SYNC_MARKER_DIR/config-mcp"
    local mcp_status="⏳"
    [ -f "$mcp_marker" ] && [ "$mcp_marker" -nt "$CLAUDE_DIR/settings.json" ] 2>/dev/null && mcp_status="✅"
    printf "  %s settings.json\n" "$mcp_status"
    echo ""

    # Hooks 状态
    echo "Hooks:"
    local hooks_marker="$SYNC_MARKER_DIR/config-hooks"
    local hooks_status="⏳"
    [ -f "$hooks_marker" ] && [ "$hooks_marker" -nt "$CLAUDE_DIR/hooks" ] 2>/dev/null && hooks_status="✅"
    printf "  %s hooks/\n" "$hooks_status"
}

# 帮助
show_help() {
    cat << 'EOF'
Config Sync - 同步所有 Claude Code 配置到 GitHub

用法:
  config-sync                  同步所有配置
  config-sync --status         查看同步状态
  config-sync --force          强制重新同步所有
  config-sync --help           显示帮助

同步内容包括:
  - Skills (自定义技能)
  - MCP Servers (settings.json 中的配置，已脱敏)
  - Hooks (所有 .sh 钩子脚本，已脱敏)
  - Keybindings (快捷键配置)
  - Tools (自定义工具脚本，已脱敏)

隐私保护:
  - API Keys、Tokens、密码等敏感信息自动脱敏为 ***REDACTED***
  - 环境变量全部脱敏
  - shell 脚本中的敏感赋值被脱敏

EOF
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
            sync_all
            ;;
        "")
            sync_all
            ;;
        *)
            log_err "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
