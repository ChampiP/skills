#!/usr/bin/env bash
# Sync Engram memory between machines (Linux/macOS) through CHUNKS. Same flow as engram-sync.ps1:
# fetch/merge -> engram sync --import --all -> engram sync --all -> commit -> push.
#
# Why chunks and NOT the binary: versioning engram.db in git CORRUPTS it (git rewrites it while
# engram keeps it open). Chunks are hash-named (two machines never collide) and importing is
# IDEMPOTENT (engram dedups via sync_chunks). JSON export/import does NOT dedup -> never for sync.
#
# Config through env (with defaults):
#   ENGRAM_DATA_DIR  -> live data-dir (default: $HOME/.engram, holds engram.db)
#   ENGRAM_SYNC_DIR  -> clone of the private sync repo (default: $HOME/.engram-sync)
#
# Output goes to stdout/stderr (systemd -> journalctl --user -u engram-sync).
# Exit code: 0 = ok (with or without changes), 1 = any failure. Needs git, jq, flock.

set -uo pipefail

export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-$HOME/.engram}"
SYNC_DIR="${ENGRAM_SYNC_DIR:-$HOME/.engram-sync}"
MANIFEST=.engram/manifest.json

# Without a terminal (systemd) git/ssh cannot ask for anything: fail fast instead of hanging.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=20}"

die() { echo "ERROR: $*" >&2; exit 1; }
run() { echo "> $*"; "$@"; }
sync_msg() { echo "sync: $(uname -n) $(TZ=America/Lima date '+%d-%m-%Y %H:%M:%S')"; }

# Desktop notification; a missing notifier or session bus never changes the exit code.
notify() {
  command -v notify-send >/dev/null || return 0
  notify-send -a engram-sync "🧠 Engram sync" "$1" || echo "WARN: could not show notification" >&2
}

# Chunk ids currently in the local manifest, as a JSON array.
manifest_ids() {
  [ -f "$MANIFEST" ] || { echo '[]'; return; }
  jq -c '[(.chunks // [])[].id]' "$MANIFEST"
}

# Chunk ids in origin/main's manifest (what the remote already has), as a JSON array.
remote_ids() {
  git cat-file -e "origin/main:$MANIFEST" 2>/dev/null || { echo '[]'; return; }
  git show "origin/main:$MANIFEST" | jq -c '[(.chunks // [])[].id]'
}

# Manifest entries whose id is not in the JSON array $1.
chunks_not_in() {
  [ -f "$MANIFEST" ] || { echo '[]'; return; }
  jq -c --argjson known "$1" '[(.chunks // [])[] | select(.id as $i | $known | index($i) | not)]' "$MANIFEST"
}

# Sets $fresh to the chunks the manifest gained since the last call and refreshes $known.
# Must not run inside $(...): the updated $known would be lost in the subshell.
take_new_chunks() {
  fresh=$(chunks_not_in "$known") && known=$(manifest_ids) || die "cannot read $MANIFEST"
}

summary() {
  jq -r 'select(length > 0) | "\(map(.sessions) | add) sesiones, \(map(.memories) | add) observaciones, \(map(.prompts) | add) prompts"' <<<"$1"
}

# A manifest conflict means both machines exported new chunks. Chunks are hash-named and never
# collide, so the manifest is resolved with the UNION of entries by id. Keeping only the remote
# side (-X theirs) would orphan the local chunk: nobody would ever import it.
# jq keeps created_at as the exact original string (nanoseconds included).
merge_manifest() {
  local tmp="$MANIFEST.merge"
  jq -j -n --argjson ours "$(git show ":2:$MANIFEST")" --argjson theirs "$(git show ":3:$MANIFEST")" '
    {version: $theirs.version,
     chunks: (($theirs.chunks // []) + ($ours.chunks // []) | unique_by(.id) | sort_by(.created_at))}' >"$tmp" \
    && mv "$tmp" "$MANIFEST" || { rm -f "$tmp"; return 1; }
  echo "manifest: union of local + remote = $(jq '.chunks | length' "$MANIFEST") chunks"
}

# Merge origin/main. Never drops local commits (no reset --hard, no -X theirs).
merge_remote() {
  local msg f
  msg=$(sync_msg)
  run git merge -q --no-edit -m "$msg" origin/main && return 0
  git rev-parse -q --verify MERGE_HEAD >/dev/null || die "git merge origin/main failed (rewritten history?); local state intact"
  while IFS= read -r f; do
    if [ "$f" = "$MANIFEST" ]; then
      merge_manifest && git add -- "$f"
    else
      git checkout -q --theirs -- "$f" && git add -- "$f" && echo "conflict in $f -> remote version (not memory)"
    fi
  done < <(git diff --name-only --diff-filter=U)
  if [ -n "$(git diff --name-only --diff-filter=U)" ] || ! run git commit -q --no-edit -m "$msg"; then
    run git merge --abort
    die "unresolved merge with origin/main; local state intact"
  fi
}

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/engram-sync.lock" || die "cannot open lock file"
flock -n 9 || { echo "another run in progress; exiting"; exit 0; }

echo "---- start on $(uname -n)"
command -v engram >/dev/null || die "engram not in PATH"
command -v jq >/dev/null || die "jq not in PATH"
cd "$SYNC_DIR" 2>/dev/null || die "$SYNC_DIR does not exist (clone the repo first)"
git rev-parse --is-inside-work-tree >/dev/null || die "$SYNC_DIR is not a git repo"

# Every chunk known before touching the network, to tell "the remote merge brought this"
# apart from "we generated this when exporting".
known=$(manifest_ids) || die "cannot read $MANIFEST"
pulled='[]'

# 1. Bring remote chunks. Offline we keep going: the local export/commit is ready for the next
#    run, and this run ends with exit 1 at the push.
if run git fetch -q origin main; then
  merge_remote
  take_new_chunks
  pulled=$(jq -cn --argjson a "$pulled" --argjson b "$fresh" '$a + $b')
else
  echo "WARN: git fetch failed (network or SSH); continuing with local export" >&2
fi

# 2. Import remote chunks (idempotent) and 3. export new local memories.
run engram sync --import --all || die "engram sync --import --all failed"
run engram sync --all || die "engram sync --all failed"
take_new_chunks   # mark our own exported chunks so a later merge never counts them as pulled
git add -- .engram || die "git add failed"
if ! git diff --cached --quiet; then
  run git commit -q -m "$(sync_msg)" || die "git commit failed"
fi

# 4. Push if there are local commits (including those left by an offline run).
#    If another machine pushed in between: fetch + merge + retry.
pushed=0
for try in 1 2; do
  ahead=$(git rev-list --count origin/main..HEAD) || die "cannot compare with origin/main"
  [ "$ahead" -eq 0 ] && break
  # Chunks this push uploads, including those exported by an earlier offline run.
  uploading=$(chunks_not_in "$(remote_ids)") || die "cannot read $MANIFEST"
  if run git push -q origin HEAD:main; then pushed=1; break; fi
  [ "$try" -eq 2 ] && die "git push failed twice; commits stay local for the next run"
  run git fetch -q origin main || die "git fetch failed (network or SSH); commits stay local for the next run"
  merge_remote
  take_new_chunks
  pulled=$(jq -cn --argjson a "$pulled" --argjson b "$fresh" '$a + $b')
  run engram sync --import --all || die "engram sync --import --all failed"
done

# 5. Check from outside: status must read the manifest without errors.
run engram sync --status || die "engram sync --status failed"

# Independent notifications, each only when something really happened.
msg=$(summary "$pulled") && [ -n "$msg" ] && notify "Bajado: $msg"
[ "$pushed" -eq 1 ] && msg=$(summary "$uploading") && [ -n "$msg" ] && notify "Subido: $msg"

echo "---- ok"
exit 0
