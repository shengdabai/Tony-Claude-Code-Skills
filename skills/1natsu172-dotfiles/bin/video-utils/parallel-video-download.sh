#!/usr/bin/env bash
#
# Parallel Video Download Script
#
# This script downloads videos from URLs in parallel using yt-dlp and aria2c.
# It provides robust error handling, progress tracking, and failed URL recovery.
#
# Dependencies: yt-dlp, aria2c
#
# Author: Generated with Claude Code
#

set -euo pipefail

# =============================================================================
# Configuration Constants
# =============================================================================

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly DEFAULT_MAX_CONCURRENT=4
readonly DEFAULT_ARIA2_CONNECTIONS=16
DEFAULT_OUTPUT_DIR="$HOME/Movies/$(date +%Y_%m_%d)"
readonly DEFAULT_OUTPUT_DIR

# Global Variables
MAX_CONCURRENT="$DEFAULT_MAX_CONCURRENT"
ARIA2_CONNECTIONS="$DEFAULT_ARIA2_CONNECTIONS"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
URL_FILE=""
FAILED_URLS_FILE=""
DRY_RUN=false

# =============================================================================
# Helper Functions
# =============================================================================

# Display usage information
show_help() {
	cat <<EOF
使用方法: $SCRIPT_NAME [オプション] <URL_FILE>

オプション:
    -c, --concurrent NUM    同時ダウンロード数 (デフォルト: $DEFAULT_MAX_CONCURRENT)
    -x, --connections NUM   aria2cの接続数 (デフォルト: $DEFAULT_ARIA2_CONNECTIONS)
    -o, --output DIR        出力ディレクトリ (デフォルト: $DEFAULT_OUTPUT_DIR)
    -d, --dry-run          ダウンロード実行せず、処理内容のみ表示
    -h, --help             このヘルプを表示

URL_FILE: ダウンロードするURLを1行ずつ記載したファイル(.txt, .md, etc.)
         # で始まる行はコメントとして無視されます

例:
    $SCRIPT_NAME urls.txt
    $SCRIPT_NAME -x 2 urls.txt  # aria2cの接続数を2に設定
    $SCRIPT_NAME -c 8 -x 32 -o ~/Videos urls.txt  # 同時ダウンロード数を8、aria2cの接続数を32、出力ディレクトリを~/Videosに設定
    $SCRIPT_NAME --dry-run urls.txt  # 実行内容の確認
EOF
}

# Log messages with timestamp
log_info() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_error() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_success() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*"
}

log_warning() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2
}

# Validate numeric input
validate_numeric() {
	local value="$1"
	local name="$2"

	if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
		log_error "$name は正の整数である必要があります: '$value'"
		exit 1
	fi
}

# Parse command line arguments
parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		-c | --concurrent)
			[[ -z "${2:-}" ]] && {
				log_error "--concurrent オプションには値が必要です"
				exit 1
			}
			validate_numeric "$2" "同時ダウンロード数"
			MAX_CONCURRENT="$2"
			shift 2
			;;
		-x | --connections)
			[[ -z "${2:-}" ]] && {
				log_error "--connections オプションには値が必要です"
				exit 1
			}
			validate_numeric "$2" "aria2c接続数"
			ARIA2_CONNECTIONS="$2"
			shift 2
			;;
		-o | --output)
			[[ -z "${2:-}" ]] && {
				log_error "--output オプションには値が必要です"
				exit 1
			}
			OUTPUT_DIR="$2"
			shift 2
			;;
		-d | --dry-run)
			DRY_RUN=true
			shift
			;;
		-h | --help)
			show_help
			exit 0
			;;
		-*)
			log_error "不明なオプション: $1"
			show_help
			exit 1
			;;
		*)
			[[ -n "$URL_FILE" ]] && {
				log_error "複数のURLファイルが指定されました"
				exit 1
			}
			URL_FILE="$1"
			shift
			;;
		esac
	done
}

# Check if required dependencies are available
check_dependencies() {
	local missing_deps=()

	if ! command -v yt-dlp &>/dev/null; then
		missing_deps+=("yt-dlp")
	fi

	if ! command -v aria2c &>/dev/null; then
		missing_deps+=("aria2c")
	fi

	if [[ ${#missing_deps[@]} -gt 0 ]]; then
		log_error "以下の依存関係が不足しています: ${missing_deps[*]}"
		log_error "必要なツールをインストールしてから再実行してください"
		exit 1
	fi

	log_info "依存関係チェック完了"
}

# Validate input file and setup directories
validate_and_setup() {
	# Validate URL file
	if [[ -z "$URL_FILE" ]]; then
		log_error "URLファイルを指定してください"
		show_help
		exit 1
	fi

	if [[ ! -f "$URL_FILE" ]]; then
		log_error "ファイル '$URL_FILE' が見つかりません"
		exit 1
	fi

	if [[ ! -r "$URL_FILE" ]]; then
		log_error "ファイル '$URL_FILE' を読み取れません（権限を確認してください）"
		exit 1
	fi

	# Create output directory (skip in dry-run mode)
	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "[DRY RUN] 出力ディレクトリ作成をスキップ: $OUTPUT_DIR"
	else
		if ! mkdir -p "$OUTPUT_DIR"; then
			log_error "出力ディレクトリ '$OUTPUT_DIR' を作成できません"
			exit 1
		fi
	fi

	# Setup failed URLs file (only define, don't initialize)
	FAILED_URLS_FILE="$OUTPUT_DIR/failed_urls_$(date +%Y%m%d_%H%M%S).txt"

	log_info "入力ファイルと出力ディレクトリの検証完了"
}

# Download a single video with robust error handling
download_video() {
	local url="$1"
	local temp_log
	temp_log=$(mktemp) || {
		log_error "一時ファイルを作成できません"
		return 1
	}

	# Cleanup function for temp file
	# shellcheck disable=SC2329  # Function is invoked via trap
	cleanup() {
		[[ -f "$temp_log" ]] && rm -f "$temp_log"
	}
	trap cleanup RETURN

	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "[DRY RUN] $url → HD/best[ext=mp4]/best"
		return 0
	fi

	log_info "ダウンロード開始: $url"

	# Execute yt-dlp with comprehensive options
	if yt-dlp \
		--external-downloader aria2c \
		--external-downloader-args "aria2c:-x $ARIA2_CONNECTIONS -s $ARIA2_CONNECTIONS -j $ARIA2_CONNECTIONS" \
		--output "$OUTPUT_DIR/%(title)s [%(id)s].%(ext)s" \
		--no-overwrites \
		--format 'HD/best[ext=mp4]/best' \
		--no-check-certificate \
		"$url" 2>"$temp_log"; then

		log_success "ダウンロード完了: $url"
		return 0
	else
		local exit_code=$?
		local error_msg
		error_msg=$(tail -5 "$temp_log" 2>/dev/null | tr '\n' ' ' || echo "ログを読み取れません")

		log_error "ダウンロード失敗: $url (終了コード: $exit_code)"
		log_error "エラー詳細: $error_msg"

		# Record failed URL safely with file locking
		record_failed_url "$url"
		return 1
	fi
}

# Safely record failed URL with file locking
record_failed_url() {
	local url="$1"
	local lock_file="$FAILED_URLS_FILE.lock"

	(
		# Acquire exclusive lock and append URL
		if flock -x -w 10 200; then
			echo "$url" >>"$FAILED_URLS_FILE"
		else
			log_warning "ロック取得に失敗しました。失敗URL記録をスキップ: $url"
		fi
	) 200>"$lock_file"
}

# Count valid URLs in file (excluding comments and empty lines)
count_valid_urls() {
	local file="$1"
	grep -c "^[^#[:space:]]" "$file" 2>/dev/null || echo "0"
}

# Display configuration and statistics
show_configuration() {
	local url_count
	url_count=$(count_valid_urls "$URL_FILE")

	local mode_prefix=""
	[[ "$DRY_RUN" == "true" ]] && mode_prefix="[DRY RUN] "
	
	log_info "${mode_prefix}=== 設定情報 ==="
	log_info "${mode_prefix}出力ディレクトリ: $OUTPUT_DIR"
	log_info "${mode_prefix}同時ダウンロード数: $MAX_CONCURRENT"
	log_info "${mode_prefix}aria2c接続数: $ARIA2_CONNECTIONS"
	log_info "${mode_prefix}URLファイル: $URL_FILE"
	log_info "${mode_prefix}処理予定URL数: $url_count"
	[[ "$DRY_RUN" == "true" ]] && log_info "${mode_prefix}実行モード: DRY RUN (実際のダウンロードは行いません)"
	log_info "${mode_prefix}==============="

	if [[ "$url_count" -eq 0 ]]; then
		log_warning "処理可能なURLが見つかりません"
		return 1
	fi

	return 0
}

# Execute parallel downloads
execute_parallel_downloads() {
	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "[DRY RUN] 実行内容の確認を開始します..."
		
		# Export functions and variables for xargs subprocesses
		export -f download_video record_failed_url log_info log_error log_success log_warning
		export OUTPUT_DIR ARIA2_CONNECTIONS FAILED_URLS_FILE DRY_RUN

		# Execute dry-run checks using xargs
		grep "^[^#[:space:]]" "$URL_FILE" |
			xargs -n 1 -P "$MAX_CONCURRENT" -I {} bash -c 'download_video "$@"' _ {}
		
		log_info "[DRY RUN] 実行内容の確認が完了しました"
		return 0
	fi

	log_info "並列ダウンロードを開始します..."

	# Export functions and variables for xargs subprocesses
	export -f download_video record_failed_url log_info log_error log_success log_warning
	export OUTPUT_DIR ARIA2_CONNECTIONS FAILED_URLS_FILE DRY_RUN

	# Execute parallel downloads using xargs
	if grep "^[^#[:space:]]" "$URL_FILE" |
		xargs -n 1 -P "$MAX_CONCURRENT" -I {} bash -c 'download_video "$@"' _ {}; then
		log_info "並列ダウンロード処理が完了しました"
	else
		log_warning "一部のダウンロードで問題が発生しました"
	fi
}

# Generate download summary and cleanup
generate_summary() {
	if [[ "$DRY_RUN" == "true" ]]; then
		log_success "[DRY RUN] 実行内容の確認が完了しました"
		return 0
	fi

	log_info "ダウンロード結果を集計中..."

	# Check if there were any failures
	if [[ -f "$FAILED_URLS_FILE" ]] && [[ -s "$FAILED_URLS_FILE" ]]; then
		local failed_count
		failed_count=$(wc -l <"$FAILED_URLS_FILE" 2>/dev/null || echo "0")

		log_warning "失敗したURL: $failed_count 件"
		log_info "失敗URLファイル: $FAILED_URLS_FILE"
		echo ""
		echo "失敗したURL一覧:"
		sed 's/^/  - /' "$FAILED_URLS_FILE" 2>/dev/null || echo "  ファイル読み取りエラー"
		echo ""
		log_info "リトライしたい場合は以下のコマンドを実行してください:"
		echo "  $SCRIPT_NAME \"$FAILED_URLS_FILE\""

		return 1
	else
		log_success "すべてのダウンロードが成功しました！"

		# Clean up empty failed URLs file and lock file
		rm -f "$FAILED_URLS_FILE" "$FAILED_URLS_FILE.lock" 2>/dev/null || true

		return 0
	fi
}

# =============================================================================
# Main Function
# =============================================================================

main() {
	log_info "Parallel Video Download Script を開始します"

	parse_arguments "$@"
	check_dependencies
	validate_and_setup

	if ! show_configuration; then
		exit 1
	fi

	execute_parallel_downloads

	if generate_summary; then
		log_success "すべての処理が正常に完了しました"
		exit 0
	else
		log_warning "一部のダウンロードに失敗がありました"
		exit 1
	fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
