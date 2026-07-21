# Sync de la memoria de Engram entre maquinas (Windows) por CHUNKS. Equivalente a engram-sync.sh.
# Los chunks son idempotentes al importar (dedup via sync_chunks). El binario engram.db NUNCA
# se versiona (lo corrompe). El JSON export/import NO deduplica -> no usarlo para sync.
#
# Config por entorno (con defaults):
#   ENGRAM_DATA_DIR  -> data-dir vivo (default: $HOME\.engram)
#   ENGRAM_SYNC_DIR  -> clon del repo privado de sync (default: $HOME\.engram-sync)
$ErrorActionPreference = "SilentlyContinue"

if (-not $env:ENGRAM_DATA_DIR) { $env:ENGRAM_DATA_DIR = "$HOME\.engram" }
$SyncDir = if ($env:ENGRAM_SYNC_DIR) { $env:ENGRAM_SYNC_DIR } else { "$HOME\.engram-sync" }

if (-not (Test-Path $SyncDir)) { exit 0 }
Set-Location $SyncDir
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

# 1. Traer chunks remotos; ante conflicto (manifest) gana remoto, el re-export lo regenera.
git fetch -q origin main
git merge -q -X theirs origin/main
if ($LASTEXITCODE -ne 0) { git merge --abort; git reset -q --hard origin/main }

# 2. Importar chunks remotos (idempotente: dedup por sync_chunks).
engram sync --import --all *> $null

# 3. Exportar nuevas memorias locales -> chunks.
engram sync --all *> $null

# 4. Commit + push si cambiaron los chunks. Commit fijo: "sync: <host> <fecha Lima>".
git add -- .engram *> $null
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  # Fecha en America/Lima para consistencia con Linux (evita depender del TZ local).
  $stamp = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date).ToUniversalTime(), "SA Pacific Standard Time").ToString("dd-MM-yyyy HH:mm:ss")
  git commit -q -m "sync: $env:COMPUTERNAME $stamp"
  git push -q origin main
}
exit 0
