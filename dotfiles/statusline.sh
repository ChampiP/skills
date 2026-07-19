#!/usr/bin/env bash
input=$(cat)

if command -v jq >/dev/null 2>&1; then
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
  style=$(echo "$input" | jq -r '.output_style.name // "default"')
  ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  model=$(echo "$input" | jq -r '.model.display_name // empty')
  rl5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  rl5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
else
  cwd="?"
  style="default"
  ctx_pct=""
  model=""
  rl5h=""
  rl5h_reset=""
fi

branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
[ ${#branch} -gt 16 ] && branch="${branch:0:15}…"

spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
frame=${spin:$(( $(date +%s) % 10 )):1}
printf '\033[38;5;208m%s\033[0m ' "$frame"                                    # orange spinner
printf '\033[38;5;36m%s\033[0m' "$style"                                      # cyan
[ -n "$model" ]   && printf '|\033[38;5;213m%s\033[0m' "$model"               # pink
[ -n "$branch" ]  && printf '|\033[38;5;77m%s\033[0m' "$branch"              # green
[ -n "$ctx_pct" ] && printf '|\033[38;5;178m%.0f%%\033[0m' "$ctx_pct"         # gold
if [ -n "$rl5h" ]; then
  remain=""
  if [ -n "$rl5h_reset" ]; then
    secs=$(( ${rl5h_reset%.*} - $(date +%s) ))
    if [ "$secs" -gt 0 ]; then
      if [ "$secs" -ge 3600 ]; then
        remain="$((secs/3600))h$(((secs%3600)/60))m"
      else
        remain="$((secs/60))m"
      fi
    fi
  fi
  printf '|\033[38;5;204m%.0f%%(%s)\033[0m' "$rl5h" "$remain"                 # red-pink
fi

flag="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.ponytail-active"
if [ -f "$flag" ]; then
  pmode=$(head -n1 "$flag" | tr -d '[:space:]')
  pcolor=108
  [ "$pmode" = "ultra" ] && pcolor=173
  if [ -z "$pmode" ] || [ "$pmode" = "full" ]; then
    printf ' | \033[38;5;%sm[PONYTAIL]\033[0m' "$pcolor"
  else
    printf ' | \033[38;5;%sm[PONYTAIL:%s]\033[0m' "$pcolor" "$(printf '%s' "$pmode" | tr '[:lower:]' '[:upper:]')"
  fi
fi
printf '\n'
