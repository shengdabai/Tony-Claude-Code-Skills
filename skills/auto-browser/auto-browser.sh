#!/bin/bash
#
# Smart Browser - 自动组合 gstack browse 和 bb-browser
# 根据URL智能选择最佳工具获取网页内容
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 工具路径
BROWSE_BIN="${BROWSE_BIN:-$HOME/.claude/skills/gstack/browse/dist/browse}"
BB_BROWSER="${BB_BROWSER:-bb-browser}"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助
show_help() {
    cat << 'EOF'
Smart Browser - 智能网页内容获取工具

用法:
  smart-browser <URL> [选项]

选项:
  --method <auto|bb|browse|both>  指定使用的方法 (默认: auto)
  --output <path>                 输出文件路径
  --format <text|json|markdown>   输出格式 (默认: markdown)
  --depth <n>                     内容获取深度 (默认: 3)
  --screenshot                    同时获取截图
  --full-page                     获取完整页面内容
  --help                          显示帮助

示例:
  smart-browser https://example.com
  smart-browser https://example.com --method both --output result.md
  smart-browser https://github.com/user/repo --method bb

EOF
}

# 解析URL获取域名
get_domain() {
    local url="$1"
    echo "$url" | sed -E 's|https?://||' | sed -E 's|/.*||' | sed -E 's|:.*||'
}

# 检查是否有bb-browser的site adapter
has_bb_adapter() {
    local domain="$1"
    local adapters

    adapters=$($BB_BROWSER site list 2>/dev/null | grep -i "^$domain" || true)

    if [ -n "$adapters" ]; then
        echo "$adapters"
        return 0
    fi
    return 1
}

# 使用bb-browser获取内容
use_bb_browser() {
    local url="$1"
    local output="$2"
    local domain
    local adapter

    domain=$(get_domain "$url")
    log_info "尝试使用 bb-browser 获取内容..."

    # 检查是否有site adapter
    if adapters=$(has_bb_adapter "$domain"); then
        log_success "发现可用的 site adapter:"
        echo "$adapters" | head -5

        # 尝试使用第一个adapter
        adapter=$(echo "$adapters" | head -1 | awk '{print $1}')
        log_info "使用 adapter: $adapter"

        if $BB_BROWSER site "$adapter" 2>/dev/null > "$output"; then
            log_success "bb-browser 获取成功"
            return 0
        fi
    fi

    # 没有adapter或失败，使用浏览器模式
    log_warn "没有合适的adapter，使用浏览器模式..."

    $BB_BROWSER open "$url" --tab current 2>/dev/null
    sleep 3

    if $BB_BROWSER snapshot -d 5 2>/dev/null > "$output"; then
        log_success "bb-browser 快照获取成功"
        return 0
    fi

    return 1
}

# 使用gstack browse获取内容
use_browse() {
    local url="$1"
    local output="$2"
    local screenshot="$3"

    log_info "尝试使用 gstack browse 获取内容..."

    if [ ! -x "$BROWSE_BIN" ]; then
        log_error "gstack browse 未安装或未找到: $BROWSE_BIN"
        return 1
    fi

    local B="$BROWSE_BIN"

    # 导航到页面
    $B goto "$url" 2>/dev/null
    sleep 2

    # 获取文本内容
    $B text 2>/dev/null > "$output"

    # 如果需要截图
    if [ "$screenshot" = "true" ]; then
        local screenshot_path="${output%.txt}.png"
        $B screenshot "$screenshot_path" 2>/dev/null
        log_success "截图已保存: $screenshot_path"
    fi

    if [ -s "$output" ]; then
        log_success "gstack browse 获取成功"
        return 0
    fi

    return 1
}

# 组合使用两个工具
use_both() {
    local url="$1"
    local output="$2"
    local screenshot="$3"

    log_info "组合使用 bb-browser + gstack browse..."

    local temp_bb="${output}.bb.tmp"
    local temp_browse="${output}.browse.tmp"

    # 先用bb-browser尝试
    local bb_success=false
    if use_bb_browser "$url" "$temp_bb"; then
        bb_success=true
    fi

    # 再用browse尝试
    local browse_success=false
    if use_browse "$url" "$temp_browse" "$screenshot"; then
        browse_success=true
    fi

    # 合并结果
    {
        echo "# 网页内容获取报告"
        echo ""
        echo "**URL:** $url"
        echo ""
        echo "**时间:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "---"
        echo ""

        if [ "$bb_success" = true ]; then
            echo "## bb-browser 获取结果"
            echo ""
            cat "$temp_bb"
            echo ""
            echo "---"
            echo ""
        fi

        if [ "$browse_success" = true ]; then
            echo "## gstack browse 获取结果"
            echo ""
            cat "$temp_browse"
            echo ""
        fi

        if [ "$bb_success" != true ] && [ "$browse_success" != true ]; then
            echo "❌ 所有方法都失败了"
        fi
    } > "$output"

    # 清理临时文件
    rm -f "$temp_bb" "$temp_browse"

    if [ "$bb_success" = true ] || [ "$browse_success" = true ]; then
        log_success "组合获取完成: $output"
        return 0
    fi

    return 1
}

# 主函数
main() {
    local url=""
    local method="auto"
    local output=""
    local format="markdown"
    local depth="3"
    local screenshot="false"
    local full_page="false"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --method)
                method="$2"
                shift 2
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --depth)
                depth="$2"
                shift 2
                ;;
            --screenshot)
                screenshot="true"
                shift
                ;;
            --full-page)
                full_page="true"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$url" ]; then
                    url="$1"
                fi
                shift
                ;;
        esac
    done

    # 验证URL
    if [ -z "$url" ]; then
        log_error "请提供URL"
        show_help
        exit 1
    fi

    # 设置默认输出
    if [ -z "$output" ]; then
        local domain
        domain=$(get_domain "$url")
        output="${domain}_$(date +%Y%m%d_%H%M%S).md"
    fi

    log_info "目标URL: $url"
    log_info "使用方法: $method"
    log_info "输出文件: $output"

    # 根据方法执行
    case $method in
        bb)
            use_bb_browser "$url" "$output"
            ;;
        browse)
            use_browse "$url" "$output" "$screenshot"
            ;;
        both)
            use_both "$url" "$output" "$screenshot"
            ;;
        auto|*)
            # 自动判断
            local domain
            domain=$(get_domain "$url")

            if adapters=$(has_bb_adapter "$domain" 2>/dev/null); then
                log_info "检测到 bb-browser 有该站点的 adapter"
                use_bb_browser "$url" "$output"
            else
                log_info "使用 gstack browse 获取内容"
                use_browse "$url" "$output" "$screenshot"
            fi
            ;;
    esac

    # 显示结果
    if [ -f "$output" ]; then
        log_success "内容已保存到: $output"
        echo ""
        echo "文件大小: $(du -h "$output" | cut -f1)"
        echo "前500字符预览:"
        echo "---"
        head -c 500 "$output"
        echo "..."
    fi
}

main "$@"
