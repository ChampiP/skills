# Setup del sync de memoria Engram en Windows (de cero)

Genérico: reemplazá `<REPO_SSH>` por la URL del repo privado de sync. PowerShell.

## 0. Pre-requisitos
- `engram` instalado y en PATH — preferir `go install` en Windows (evita falsos
  positivos de antivirus). Ver `references/official-docs.md`.
- `git` con acceso SSH al repo privado.
- Verificar: `engram --help` responde. Data-dir: `%USERPROFILE%\.engram\engram.db`.

## 1. Clonar el repo privado de sync
```powershell
git clone <REPO_SSH> "$HOME\.engram-sync"
```

## 2. Instalar el script
```powershell
Copy-Item assets\engram-sync.ps1 "$HOME\.engram-sync\engram-sync.ps1"
```

## 3. Primer sync (trae la memoria existente del repo)
```powershell
powershell -NoProfile -File "$HOME\.engram-sync\engram-sync.ps1"
engram sync --status     # debe mostrar "Pending import: 0"
```

## 4. Automatizar (Task Scheduler): al iniciar sesión + cada 10 min
Dos tareas: una pulea al loguearte (trae cambios de la otra PC), otra pushea seguido
(reduce la ventana de pérdida si apagás la PC).
```powershell
$cmd = "powershell -NoProfile -WindowStyle Hidden -File %USERPROFILE%\.engram-sync\engram-sync.ps1"
# a) pull/sync al iniciar sesion
schtasks /create /tn "EngramSyncLogon"    /sc onlogon        /tr $cmd
# b) sync cada 10 minutos
schtasks /create /tn "EngramSyncPeriodic" /sc minute /mo 10  /tr $cmd
# Correr a mano: schtasks /run /tn EngramSyncPeriodic
```
Push-al-apagar en Windows es más complejo (no hay trigger simple de shutdown para
tareas de usuario); el intervalo de 10 min + el sync al login cubren el caso. Ver
`references/sync-timing.md`.

## 5. Blindar si engram se clonó dentro de `~/.engram`
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
