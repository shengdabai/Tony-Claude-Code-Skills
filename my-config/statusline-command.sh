#!/usr/bin/env bash

input=$(cat)
reset=$'\033[0m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'
dim=$'\033[2m'

# --- Line 1: Model + Git + Context ---

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')

cwd=$(echo "$input" | jq -r '.workspace.current_dir // "."')
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  diff_stats=$(git -C "$cwd" diff --shortstat HEAD 2>/dev/null)
  added=$(echo "$diff_stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  deleted=$(echo "$diff_stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
  [ -z "$added" ] && added=0
  [ -z "$deleted" ] && deleted=0
  git_info="🌿 ${branch} ${green}+${added}${reset}/${red}-${deleted}${reset}"
else
  git_info=""
fi

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
used_int=${used_pct%.*}
used_int=${used_int:-0}

make_bar() {
  local pct=$1 width=${2:-10}
  local filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  [ "$filled" -lt 0 ] && filled=0
  local empty=$(( width - filled ))
  local b=""
  for ((i=0; i<filled; i++)); do b+="█"; done
  for ((i=0; i<empty; i++)); do b+="░"; done
  echo "$b"
}

color_for_pct() {
  local pct=$1
  if [ "$pct" -lt 50 ]; then echo "$green"
  elif [ "$pct" -lt 80 ]; then echo "$yellow"
  else echo "$red"
  fi
}

format_duration() {
  local secs=$1
  [ "$secs" -le 0 ] && return
  local d=$(( secs / 86400 )) h=$(( (secs % 86400) / 3600 )) m=$(( (secs % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  else echo "${m}m"
  fi
}

ctx_color=$(color_for_pct "$used_int")
ctx_bar=$(make_bar "$used_int" 15)
context_bar="💭 ${ctx_color}${ctx_bar}${reset} ${used_int}%"

# --- Line 2: Try official rate_limits first, fallback to ccusage ---

five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

usage_line=""

if [ -n "$five_hour_pct" ] || [ -n "$seven_day_pct" ]; then
  # Official rate_limits available
  if [ -n "$five_hour_pct" ]; then
    fh_int=${five_hour_pct%.*}; fh_int=${fh_int:-0}
    fh_color=$(color_for_pct "$fh_int")
    fh_bar=$(make_bar "$fh_int")
    fh_reset=""
    if [ -n "$five_hour_reset" ]; then
      fh_ep=$(awk "BEGIN{printf \"%d\", $five_hour_reset}")
      now_ep=$(date +%s)
      fh_reset=" ${dim}$(format_duration $(( fh_ep - now_ep )))${reset}"
    fi
    usage_line="⚡5h ${fh_color}${fh_bar}${reset} ${fh_int}%${fh_reset}"
  fi
  if [ -n "$seven_day_pct" ]; then
    sd_int=${seven_day_pct%.*}; sd_int=${sd_int:-0}
    sd_color=$(color_for_pct "$sd_int")
    sd_bar=$(make_bar "$sd_int")
    sd_reset=""
    if [ -n "$seven_day_reset" ]; then
      sd_ep=$(awk "BEGIN{printf \"%d\", $seven_day_reset}")
      now_ep=$(date +%s)
      sd_reset=" ${dim}$(format_duration $(( sd_ep - now_ep )))${reset}"
    fi
    [ -n "$usage_line" ] && usage_line="${usage_line}  "
    usage_line="${usage_line}📅7d ${sd_color}${sd_bar}${reset} ${sd_int}%${sd_reset}"
  fi
else
  # Fallback: use ccusage statusline (already has all the info)
  ccusage_line=$(echo "$input" | ccusage statusline 2>/dev/null)
  if [ -n "$ccusage_line" ]; then
    # Extract cost and time info from ccusage output
    # Format: 🤖 Model | 💰 ... | 🔥 ... | 🧠 ...
    block_info=$(echo "$ccusage_line" | grep -oE '\$[0-9.]+ block \([^)]+\)' || true)
    today_cost=$(echo "$ccusage_line" | grep -oE '\$[0-9.]+ today' | head -1 || true)
    burn_rate=$(echo "$ccusage_line" | grep -oE '🔥 [^|]+' | sed 's/[[:space:]]*$//' || true)

    if [ -n "$block_info" ] || [ -n "$today_cost" ]; then
      parts=""
      [ -n "$block_info" ] && parts="📦 ${block_info}"
      [ -n "$today_cost" ] && { [ -n "$parts" ] && parts="${parts}  "; parts="${parts}📅 ${today_cost}"; }
      [ -n "$burn_rate" ] && parts="${parts}  ${burn_rate}"
      usage_line="$parts"
    fi
  fi
fi

# Append session cost
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$session_cost" ] && [ -n "$usage_line" ]; then
  cost_note=$(printf " ${dim}| session \$%.2f${reset}" "$session_cost")
  usage_line="${usage_line}${cost_note}"
fi

# --- Output ---
line1="🤖 ${model}"
[ -n "$git_info" ] && line1="${line1}   ${git_info}"
line1="${line1}   ${context_bar}"

echo "$line1"
[ -n "$usage_line" ] && echo "$usage_line"
