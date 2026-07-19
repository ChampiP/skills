#!/usr/bin/env bash
input=$(cat)

if command -v jq >/dev/null 2>&1; then
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
  style=$(echo "$input" | jq -r '.output_style.name // "default"')
  ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
else
  cwd="?"
  style="default"
  ctx_pct=""
fi

branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

C=36 # cyan
printf '\033[38;5;%sm%s\033[0m' "$C" "$style"
[ -n "$branch" ] && printf ' | \033[38;5;%sm%s\033[0m' "$C" "$branch"
[ -n "$ctx_pct" ] && printf ' | \033[38;5;%smctx %.0f%%\033[0m' "$C" "$ctx_pct"

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
