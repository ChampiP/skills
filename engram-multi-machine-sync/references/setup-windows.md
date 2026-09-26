# Setup del sync de memoria Engram en Windows (de cero)

Genérico: reemplazá `<REPO_SSH>` por la URL del repo privado de sync. PowerShell.

## 0. Pre-requisitos
- `engram` instalado y en PATH — preferir `go install` en Windows (evita falsos
  positivos de antivirus). Ver `references/official-docs.md`.
- `git` con acceso SSH al repo privado, **con clave sin passphrase o con ssh-agent**:
  la tarea corre sin consola y el script usa `BatchMode=yes` (falla en vez de colgarse).
- Verificar: `engram --help` responde. Data-dir: `%USERPROFILE%\.engram\engram.db`.

## 1. Clonar el repo privado de sync
```powershell
git clone <REPO_SSH> "$HOME\.engram-sync"
```

## 2. Instalar el script (fuera del repo de sync, igual que Linux en `~/.local/bin`)
```powershell
New-Item -ItemType Directory -Force "$HOME\.local\bin" | Out-Null
Copy-Item assets\engram-sync.ps1 "$HOME\.local\bin\engram-sync.ps1" -Force
```
No dejarlo dentro de `~/.engram-sync`: una copia modificada ahí es un cambio sin
commitear en el repo de sync y puede bloquear el merge.

## 3. Primer sync (trae la memoria existente del repo)
Si la máquina ya tenía memoria vieja (p.ej. de antes de un rebaseline) y debe quedar
IGUAL al repo, primero resetear la DB (`references/purge-and-rebaseline.md`, pata C):
cerrar todo `engram mcp`/`serve` (Claude Code lo levanta; al matarlo, `mem_*` vuelve al
reiniciar el agente) y mover `engram.db*` a un backup, no borrarlos.
```powershell
powershell -NoProfile -File "$HOME\.local\bin\engram-sync.ps1"
engram sync --status     # debe mostrar "Pending import: 0"
Get-Content "$env:LOCALAPPDATA\engram-sync\engram-sync.log" -Tail 30
```

### Cómo verificar los conteos contra el repo
El manifest dice cuánto trae cada chunk (`sessions`, `memories`, `prompts`). Tras un
import desde cero (observado en engram 2.2.1):
- `prompts` = suma del manifest.
- `observations` = suma de `memories` **menos las que vienen con `deleted_at`** (soft
  delete: viajan como borrado, no como fila viva).
- `sessions` queda **por debajo** del manifest: las sesiones sin observaciones ni prompts
  no quedan en la DB. Es deseable (no aportan nada); no comparar sesiones 1:1.

Sin `sqlite3`/Python, Node >= 22 sirve para contar:
```powershell
node -e "const d=new (require('node:sqlite').DatabaseSync)(process.env.USERPROFILE+'/.engram/engram.db',{readOnly:true});for(const t of ['sessions','observations','user_prompts'])console.log(t,d.prepare('select count(*) n from '+t).get().n);console.log(d.prepare('pragma integrity_check').get())"
```

## 4. Automatizar (Task Scheduler): una tarea, al iniciar sesión + cada 10 min
Sin permisos de admin. Correr en PowerShell 7 o 5.1:
```powershell
$script = "$HOME\.local\bin\engram-sync.ps1"
$ps     = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$user   = "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\conhost.exe" `
  -Argument "--headless `"$ps`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$script`""
$logon    = New-ScheduledTaskTrigger -AtLogOn -User $user
$periodic = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
foreach ($old in 'EngramSyncLogon', 'EngramSyncPeriodic') { Unregister-ScheduledTask $old -Confirm:$false -ErrorAction SilentlyContinue }
Register-ScheduledTask -TaskName 'EngramSync' -Action $action -Trigger $logon, $periodic `
  -Settings $settings -Principal $principal -Force
```
Por qué cada opción (todas verificadas en Windows 11 26200):
| Opción | Problema que evita |
|---|---|
| `conhost.exe --headless` | `-WindowStyle Hidden` igual abre la consola un instante y la cierra (parpadeo). |
| `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries` | Por defecto una tarea NO arranca con batería: en laptop quedaba `Queued` y no sincronizaba. |
| `-StartWhenAvailable` | Corre al volver de suspensión si se saltó un tic. |
| Una sola tarea + `IgnoreNew` | Logon y periódico no corren a la vez sobre el mismo repo. |
| S4U / "sin sesión iniciada" | Descartado: `Register-ScheduledTask` devuelve "Acceso denegado" sin admin. |

Correr a mano y ver el resultado:
```powershell
Start-ScheduledTask EngramSync
(Get-ScheduledTaskInfo EngramSync).LastTaskResult     # 0 = ok, 1 = error (ver log)
Get-Content "$env:LOCALAPPDATA\engram-sync\engram-sync.log" -Tail 30
```
Push-al-apagar en Windows es más complejo (no hay trigger simple de shutdown para
tareas de usuario); el intervalo de 10 min + el sync al login cubren el caso. Ver
`references/sync-timing.md`.

## 5. Qué hace el script y qué cambió (v2)
Mismo flujo que `engram-sync.sh`: fetch/merge → `engram sync --import --all` →
`engram sync --all` → commit → push. Cambios respecto de la v1, cada uno probado con
dos clones y dos DBs aisladas:
- **Log** en `%LOCALAPPDATA%\engram-sync\engram-sync.log` (rota a 1 MB) con cada comando,
  su salida y exit code. La v1 mandaba todo a `$null` y salía siempre con 0.
- **Exit code real**: 1 ante cualquier fallo → visible en `LastTaskResult`.
- **Sin `git reset --hard` ni `-X theirs`**. Bug reproducido en la v1: si un push falla
  (sin red) y la otra PC pushea, el merge `-X theirs` pisa la entrada local de
  `manifest.json`; el chunk local queda huérfano (archivo presente, fuera del manifest)
  y esa memoria **nunca llega** a la otra PC. La v2 resuelve el conflicto del manifest
  con la UNIÓN de entradas por `id` (los chunks tienen nombre por hash, no chocan).
  Otros archivos en conflicto (docs) toman la versión remota.
- **Sin red no se frena**: exporta y commitea local; el push pendiente sale en la
  próxima corrida (reintento con fetch+merge si otra PC pusheó en el medio).
- `GIT_SSH_COMMAND=ssh -o BatchMode=yes -o ConnectTimeout=20`: nunca espera input.
- Mutex: dos corridas manuales/programadas no se pisan.
- Merge commits con el formato `sync: <host> <fecha Lima>` (la v1 dejaba el mensaje
  por defecto de git).
- Consola en UTF-8 para que el log no salga con mojibake.
- **Notificación toast** (🧠) solo cuando de verdad se subió memoria nueva al repo
  (nunca en una corrida sin cambios): resume sesiones/observaciones/prompts subidos,
  sumando los chunks que el manifest local ganó en esta corrida (comparación
  antes/después de `engram sync --all`, no parseo de texto del CLI). Usa la API
  nativa `Windows.UI.Notifications` (sin instalar nada); si falla, queda en el log
  y el exit code del sync no se ve afectado. El emoji se arma con
  `[char]::ConvertFromUtf32(0x1F9E0)` (codepoint, no el carácter literal) para no
  depender de que el `.ps1` tenga BOM al leerlo Windows PowerShell 5.1.

## 6. Blindar si engram se clonó dentro de `~/.engram`
```powershell
cd "$HOME\.engram"
git rm --cached --force engram.db protocol-mode.json 2>$null
git rm --cached -r .engram 2>$null
Add-Content .gitignore "`nengram.db`n*.db-wal`n*.db-shm`nprotocol-mode.json`n/.engram/"
git commit -m "chore: untrack DB viva y memoria (data-dir, no versionar)"
```

## Nota de zona horaria
El script usa `America/Lima` ("SA Pacific Standard Time" en Windows) para que el
commit tenga el mismo formato/hora que en Linux.
