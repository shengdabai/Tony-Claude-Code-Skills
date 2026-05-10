#!/usr/bin/env bash
# opc-to-gbrain.sh — 把当前项目的 opc-doc/ 同步到 gbrain
#
# 用法:
#   cd <你的项目目录>
#   ~/.claude/scripts/opc-to-gbrain.sh [项目代号] [--dry-run]
#
# 示例:
#   cd ~/Desktop/项目开发/zturns-go
#   ~/.claude/scripts/opc-to-gbrain.sh zturnsgo
#   ~/.claude/scripts/opc-to-gbrain.sh zturnsgo --dry-run
#
# 行为:
#   1. opc-doc/ 下所有 .md 和 .json 同步到 gbrain
#   2. slug 格式: opc-<项目代号>-<相对路径>(/ 替换为 -)
#   3. frontmatter: tags=[opc, <项目代号>], page_kind=opc
#   4. 跳过空文件 / >1MB 单文件
#   5. 单文件出错不终止,统计后退出码反映成功/失败

set -uo pipefail

DRY_RUN=0
PROJ_TAG=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) [[ -z "$PROJ_TAG" ]] && PROJ_TAG="$arg" ;;
  esac
done

PROJ_TAG="${PROJ_TAG:-$(basename "$PWD")}"
OPC_DIR="${PWD}/opc-doc"

if [[ ! -d "$OPC_DIR" ]]; then
  echo "❌ 当前目录没有 opc-doc/: $PWD" >&2
  echo "提示: 先在该项目里跑 /opc-orchestrator 生成 opc-doc/" >&2
  exit 1
fi

if ! command -v gbrain >/dev/null; then
  echo "❌ gbrain CLI 未安装" >&2
  exit 1
fi

count=0
skipped=0
errors=0
prefix="📦 同步"
[[ $DRY_RUN -eq 1 ]] && prefix="🧪 DRY-RUN"
echo "${prefix} opc-doc/ → gbrain, 项目标签: ${PROJ_TAG}"

while IFS= read -r -d '' f; do
  rel="${f#${OPC_DIR}/}"
  size=$(wc -c <"$f" | tr -d ' ')

  if [[ "$size" -eq 0 ]]; then
    skipped=$((skipped+1))
    [[ $DRY_RUN -eq 1 ]] && echo "  ⊘ ${rel} (空文件)"
    continue
  fi

  if [[ "$size" -gt 1048576 ]]; then
    skipped=$((skipped+1))
    echo "  ⊘ ${rel} (>1MB, $((size/1024))KB)"
    continue
  fi

  slug="opc-${PROJ_TAG}-$(echo "$rel" | sed 's|/|-|g; s|\.md$||; s|\.json$|-json|')"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  → ${slug} ($((size/1024))KB)"
    count=$((count+1))
    continue
  fi

  if {
    echo "---"
    echo "tags: [opc, ${PROJ_TAG}]"
    echo "page_kind: opc"
    echo "source_path: ${rel}"
    echo "synced_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "---"
    echo
    if [[ "$f" == *.json ]]; then
      echo "## ${rel}"
      echo
      echo '```json'
      cat "$f"
      echo '```'
    else
      cat "$f"
    fi
  } | gbrain put "$slug" >/dev/null 2>&1; then
    echo "  ✓ ${slug}"
    count=$((count+1))
  else
    echo "  ✗ ${slug} (写入失败)" >&2
    errors=$((errors+1))
  fi
done < <(find "$OPC_DIR" \( -name "*.md" -o -name "*.json" \) -type f -print0)

if [[ $DRY_RUN -eq 1 ]]; then
  echo
  echo "🧪 DRY-RUN 完成: 将同步 ${count} 个文件 (跳过 ${skipped})"
  exit 0
fi

echo
echo "✅ 已同步 ${count} 个文件 (跳过 ${skipped}, 错误 ${errors})"

if [[ $count -gt 0 ]]; then
  echo
  echo "试试:"
  echo "  gbrain query \"${PROJ_TAG} 的利基定位是什么?\""
  echo "  gbrain list --tag ${PROJ_TAG}"
fi

[[ $errors -gt 0 ]] && exit 2
exit 0
