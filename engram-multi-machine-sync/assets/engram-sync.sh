#!/usr/bin/env bash
# Sync de la memoria de Engram entre maquinas (Linux/macOS) por CHUNKS.
# Generico: funciona con cualquier repo privado y cualquier data-dir via env vars.
#
# Por que chunks y NO el binario: versionar engram.db por git lo CORROMPE (git lo
# reescribe mientras engram lo tiene abierto) y da conflictos binarios imposibles.
# Los chunks son JSONL/gz con nombre por hash (dos maquinas no chocan) e importar es
# IDEMPOTENTE (engram deduplica via tabla sync_chunks). El JSON export/import NO
# deduplica -> duplica la memoria; por eso NO se usa para sync.
#
# Config por entorno (con defaults):
#   ENGRAM_DATA_DIR  -> data-dir vivo (default: $HOME/.engram, contiene engram.db)
#   ENGRAM_SYNC_DIR  -> clon del repo privado de sync (default: $HOME/.engram-sync)

set -uo pipefail

export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-$HOME/.engram}"
SYNC_DIR="${ENGRAM_SYNC_DIR:-$HOME/.engram-sync}"
ENGRAM_BIN="$(command -v engram || echo "$HOME/.local/bin/engram")"

[ -x "$ENGRAM_BIN" ] || { echo "engram no encontrado en PATH"; exit 0; }
cd "$SYNC_DIR" 2>/dev/null || { echo "no existe $SYNC_DIR (clonar el repo primero)"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 1. Traer chunks remotos. Ante conflicto (manifest) gana remoto; el re-export lo regenera.
git fetch -q origin main 2>/dev/null || true
git merge -q -X theirs origin/main 2>/dev/null || { git merge --abort 2>/dev/null; git reset -q --hard origin/main 2>/dev/null; }

# 2. Importar chunks remotos al DB local (idempotente: dedup por sync_chunks).
"$ENGRAM_BIN" sync --import --all >/dev/null 2>&1 || true

# 3. Exportar nuevas memorias locales -> chunks.
"$ENGRAM_BIN" sync --all >/dev/null 2>&1 || true

# 4. Commit + push si cambiaron los chunks. Formato de commit fijo: "sync: <host> <fecha Lima>".
git add -- .engram >/dev/null 2>&1 || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -q -m "sync: $(hostname) $(TZ='America/Lima' date +%d-%m-%Y\ %H:%M:%S)" 2>/dev/null || true
  git push -q origin main 2>/dev/null || true
fi
exit 0
