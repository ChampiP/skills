# Coding agents never start with cwd = $HOME; they jump to ~/Work first.
for _agent in claude codex opencode gemini pi gentle-shell; do
  eval "$_agent() { [[ \$PWD == \$HOME ]] && cd ~/Work; command $_agent \"\$@\"; }"
done
unset _agent
