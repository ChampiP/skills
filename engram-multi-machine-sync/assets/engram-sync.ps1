# Sync de la memoria de Engram entre maquinas (Windows) por CHUNKS. Equivalente a engram-sync.sh.
# Los chunks son idempotentes al importar (dedup via sync_chunks). El binario engram.db NUNCA
# se versiona (lo corrompe). El JSON export/import NO deduplica -> no usarlo para sync.
#
# Config por entorno (con defaults):
#   ENGRAM_DATA_DIR  -> data-dir vivo (default: $HOME\.engram)
#   ENGRAM_SYNC_DIR  -> clon del repo privado de sync (default: $HOME\.engram-sync)
#   ENGRAM_SYNC_LOG  -> log de cada corrida (default: $env:LOCALAPPDATA\engram-sync\engram-sync.log)
#
# Exit code: 0 = ok (con o sin cambios), 1 = error. Task Scheduler lo muestra como
# "Last Run Result"; el detalle queda en el log (nunca se descarta la salida).
# Probado con Windows PowerShell 5.1 (el que usa la tarea) y PowerShell 7.

$ErrorActionPreference = 'Stop'
# engram y git escriben UTF-8; sin esto PS 5.1 lo lee como OEM y el log sale con mojibake.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

if (-not $env:ENGRAM_DATA_DIR) { $env:ENGRAM_DATA_DIR = "$HOME\.engram" }
$SyncDir  = if ($env:ENGRAM_SYNC_DIR) { $env:ENGRAM_SYNC_DIR } else { "$HOME\.engram-sync" }
$Log      = if ($env:ENGRAM_SYNC_LOG) { $env:ENGRAM_SYNC_LOG } else { "$env:LOCALAPPDATA\engram-sync\engram-sync.log" }
$Manifest = '.engram/manifest.json'

# Sin consola (Task Scheduler) git/ssh no pueden pedir nada: fallar rapido en vez de colgarse.
$env:GIT_TERMINAL_PROMPT = '0'
if (-not $env:GIT_SSH_COMMAND) { $env:GIT_SSH_COMMAND = 'ssh -o BatchMode=yes -o ConnectTimeout=20' }

New-Item -ItemType Directory -Force (Split-Path $Log) | Out-Null
if ((Test-Path $Log) -and (Get-Item $Log).Length -gt 1MB) { Move-Item $Log "$Log.1" -Force }

function Write-Log([string]$Msg) {
  Add-Content -Path $Log -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Msg"
}

function Stop-Sync([string]$Msg) { Write-Log "ERROR: $Msg"; exit 1 }

# Toast nativo de Windows. Solo se llama cuando de verdad se subio memoria nueva al
# repo (no en cada corrida de 10 min sin cambios). Si la API no esta disponible
# (falla, versionde Windows vieja) queda en el log, nunca rompe el exit code del sync.
function Send-SyncToast([string]$Body) {
  try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop | Out-Null
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $brain = [char]::ConvertFromUtf32(0x1F9E0)   # codepoint, no el emoji literal: evita mojibake si el .ps1 se lee sin BOM
    $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $nodes = $xml.GetElementsByTagName('text')
    $nodes.Item(0).AppendChild($xml.CreateTextNode("$brain Engram sync")) | Out-Null
    $nodes.Item(1).AppendChild($xml.CreateTextNode($Body)) | Out-Null
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('PowerShell').Show($toast)
  } catch {
    Write-Log "WARN: no se pudo mostrar la notificacion: $($_.Exception.Message)"
  }
}

# Chunks del manifest local ahora mismo, para comparar antes/despues del export.
function Get-ManifestChunks {
  if (-not (Test-Path $Manifest)) { return @() }
  @((Get-Content $Manifest -Raw | ConvertFrom-Json).chunks)
}

# Corre un comando nativo, loguea su salida (stdout+stderr) y devuelve el exit code.
function Invoke-Logged([string]$Exe, [string[]]$Arguments) {
  $ErrorActionPreference = 'Continue'   # en PS 5.1 el stderr de un nativo con 'Stop' aborta
  $out = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  Write-Log "> $Exe $($Arguments -join ' ') (exit $code)"
  foreach ($line in $out) { if ($line.Trim()) { Write-Log "  $line" } }
  return $code
}

# Commit con formato fijo "sync: <host> <dd-MM-yyyy HH:mm:ss>" en America/Lima (igual que Linux).
function Get-SyncMessage {
  $lima = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date).ToUniversalTime(), 'SA Pacific Standard Time')
  "sync: $env:COMPUTERNAME $($lima.ToString('dd-MM-yyyy HH:mm:ss'))"
}

function Read-ManifestStage([int]$Stage) {
  $text = (git show ":$($Stage):$Manifest") -join "`n"
  if ($PSVersionTable.PSVersion.Major -ge 7) { return $text | ConvertFrom-Json -DateKind String }
  return $text | ConvertFrom-Json   # PS 5.1 no convierte fechas: created_at queda como texto
}

# Conflicto en manifest.json = las dos PCs exportaron chunks nuevos. Los chunks tienen nombre
# por hash y no chocan; el manifest se resuelve con la UNION de entradas por id. Quedarse solo
# con el remoto (-X theirs) dejaria el chunk local huerfano: nadie lo importaria nunca.
function Merge-Manifest {
  $ours = Read-ManifestStage 2
  $theirs = Read-ManifestStage 3
  $byId = [ordered]@{}
  foreach ($c in @($theirs.chunks) + @($ours.chunks)) {
    if ($c -and -not $byId.Contains($c.id)) { $byId[$c.id] = $c }
  }
  $merged = [pscustomobject]@{ version = $theirs.version; chunks = @($byId.Values | Sort-Object { [string]$_.created_at }) }
  $json = ConvertTo-Json -InputObject $merged -Depth 5
  [System.IO.File]::WriteAllText((Join-Path $SyncDir $Manifest), $json, (New-Object System.Text.UTF8Encoding $false))
  Write-Log "manifest: union de $(@($ours.chunks).Count) locales + $(@($theirs.chunks).Count) remotos = $($byId.Count) chunks"
}

# Mergea origin/main. Nunca descarta commits locales (sin reset --hard).
function Merge-Remote {
  $msg = Get-SyncMessage
  if ((Invoke-Logged git @('merge', '-q', '--no-edit', '-m', $msg, 'origin/main')) -eq 0) { return }
  foreach ($f in @(git diff --name-only --diff-filter=U)) {
    if ($f -eq $Manifest) { Merge-Manifest }
    else { git checkout -q --theirs -- $f; Write-Log "conflicto en $f -> version remota (no es memoria)" }
    git add -- $f
  }
  if (@(git diff --name-only --diff-filter=U).Count -gt 0 -or (Invoke-Logged git @('commit', '-q', '--no-edit', '-m', $msg)) -ne 0) {
    Invoke-Logged git @('merge', '--abort') | Out-Null
    Stop-Sync 'merge con origin/main sin resolver; estado local intacto'
  }
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\EngramSync')
if (-not $mutex.WaitOne(0)) { Write-Log 'otra corrida en curso; salgo'; exit 0 }
try {
  Write-Log "---- inicio en $env:COMPUTERNAME"
  if (-not (Get-Command engram -ErrorAction SilentlyContinue)) { Stop-Sync 'engram no esta en PATH' }
  if (-not (Test-Path $SyncDir)) { Stop-Sync "no existe $SyncDir (clonar el repo primero)" }
  Set-Location $SyncDir
  if ((Invoke-Logged git @('rev-parse', '--is-inside-work-tree')) -ne 0) { Stop-Sync "$SyncDir no es un repo git" }

  # 1. Traer chunks remotos. Sin red se sigue: el export/commit local queda listo para
  #    la proxima corrida y la corrida termina con exit 1 en el push.
  if ((Invoke-Logged git @('fetch', '-q', 'origin', 'main')) -eq 0) { Merge-Remote }
  else { Write-Log 'WARN: git fetch fallo (red o SSH); sigo con export local' }

  # 2. Importar chunks remotos (idempotente) y 3. exportar memorias locales nuevas.
  if ((Invoke-Logged engram @('sync', '--import', '--all')) -ne 0) { Stop-Sync 'engram sync --import --all fallo' }
  $chunksBefore = @{}
  foreach ($c in (Get-ManifestChunks)) { $chunksBefore[$c.id] = $true }
  if ((Invoke-Logged engram @('sync', '--all')) -ne 0) { Stop-Sync 'engram sync --all fallo' }
  $newChunks = @(Get-ManifestChunks | Where-Object { -not $chunksBefore.ContainsKey($_.id) })
  git add -- .engram
  git diff --cached --quiet
  if ($LASTEXITCODE -ne 0) {
    if ((Invoke-Logged git @('commit', '-q', '-m', (Get-SyncMessage))) -ne 0) { Stop-Sync 'git commit fallo' }
  }

  # 4. Push si hay commits locales (incluye los que quedaron de una corrida sin red).
  #    Si otra PC pusheo en el medio: fetch + merge + reintento.
  $pushed = $false
  foreach ($try in 1..2) {
    $ahead = [int](git rev-list --count origin/main..HEAD)
    if ($ahead -eq 0) { break }
    if ((Invoke-Logged git @('push', '-q', 'origin', 'HEAD:main')) -eq 0) { $pushed = $true; break }
    if ($try -eq 2) { Stop-Sync 'git push fallo 2 veces; los commits quedan locales para la proxima corrida' }
    if ((Invoke-Logged git @('fetch', '-q', 'origin', 'main')) -ne 0) { Stop-Sync 'git fetch fallo (red o SSH)' }
    Merge-Remote
    if ((Invoke-Logged engram @('sync', '--import', '--all')) -ne 0) { Stop-Sync 'engram sync --import --all fallo' }
  }

  # 5. Verificacion desde afuera: el status debe leer el manifest sin error y sin pendientes.
  if ((Invoke-Logged engram @('sync', '--status')) -ne 0) { Stop-Sync 'engram sync --status fallo' }

  # Notificacion SOLO si de verdad se subio memoria nueva al repo (no en corridas vacias).
  if ($pushed -and $newChunks.Count -gt 0) {
    $sessions = ($newChunks | Measure-Object -Property sessions -Sum).Sum
    $obs      = ($newChunks | Measure-Object -Property memories -Sum).Sum
    $prompts  = ($newChunks | Measure-Object -Property prompts  -Sum).Sum
    Send-SyncToast "Subido: $sessions sesiones, $obs observaciones, $prompts prompts"
  }

  Write-Log '---- ok'
  exit 0
} finally {
  $mutex.ReleaseMutex()
}
