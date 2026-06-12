#!/bin/bash
# IdeaForge 自动归档 hook (PostToolUse on Write/Edit)
# 任何 .html 写入后，自动登记进想法工坊 pages.json（登记原路径，不复制、不删除）。
# 静默、不阻断、失败即放过（永远 exit 0）。
input=$(cat)
fp=$(printf '%s' "$input" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);process.stdout.write((j.tool_input&&(j.tool_input.file_path||j.tool_input.filePath))||'')}catch(e){}})" 2>/dev/null)
[ -z "$fp" ] && exit 0
case "$fp" in *.html) ;; *) exit 0 ;; esac
# 排除：系统自身、临时、依赖、版本控制、废纸篓
case "$fp" in
  */00-想法工坊/*|/tmp/*|*/tmp/*|*/node_modules/*|*/.omc/*|*/.git/*|*/.Trash/*|*/待分类/*) exit 0 ;;
esac
[ -f "$fp" ] || exit 0
# 后台登记，绝不阻断主流程
( cd "$HOME/Desktop/学习资料/00-想法工坊" && node engine/forge.mjs import "$fp" --category=自动归档 >/dev/null 2>&1 ) &
exit 0
