# Setup del sync de memoria Engram en Linux / macOS (de cero)

Genérico: reemplazá `<REPO_SSH>` por la URL del repo privado de sync (ej.
`git@github.com:USUARIO/engram-champip.git`). Sirve para una PC nueva con una
base nueva o para sumar una máquina a un repo de memoria ya existente.

## 0. Pre-requisitos
- `engram` instalado y en PATH — ver `references/official-docs.md` (Homebrew o `go install`).
- `git` con acceso SSH al repo privado de sync.
- `jq` (une el `manifest.json`) y `flock` (util-linux). Opcional: `notify-send`
  (libnotify) + un daemon de notificaciones (mako en Hyprland) para los avisos.
- Verificar: `engram --help`, `jq --version` y `git ls-remote <REPO_SSH>` responden.

## 1. Clonar el repo privado de sync
```bash
git clone <REPO_SSH> "$HOME/.engram-sync"
```
El data-dir vivo queda en `$HOME/.engram` (default de `ENGRAM_DATA_DIR`), separado
del repo de sync. NUNCA cruzarlos.

## 2. Instalar el script
```bash
install -Dm755 assets/engram-sync.sh "$HOME/.local/bin/engram-sync.sh"
```

## 3. Primer sync (trae la memoria existente del repo)
```bash
bash "$HOME/.local/bin/engram-sync.sh"
cd "$HOME/.engram-sync" && engram sync --status   # debe mostrar "Pending import: 0"
```
Importa los chunks del repo (idempotente) y mergea con lo local sin duplicar.

## 4. Automatizar (systemd --user timer; NUNCA cron)
Timer = pull al encender (`OnBootSec=2min`) + push cada 10 min (`OnUnitActiveSec=10min`).
Servicio de apagado = push best-effort al cerrar sesión/apagar (`ExecStop`).
```bash
install -Dm644 assets/engram-sync.service          "$HOME/.config/systemd/user/engram-sync.service"
install -Dm644 assets/engram-sync.timer            "$HOME/.config/systemd/user/engram-sync.timer"
install -Dm644 assets/engram-sync-shutdown.service "$HOME/.config/systemd/user/engram-sync-shutdown.service"
systemctl --user daemon-reload
systemctl --user enable --now engram-sync.timer
systemctl --user enable --now engram-sync-shutdown.service
systemctl --user start engram-sync.service   # corrida de prueba
```
Log de cada corrida: `systemctl --user status engram-sync` (última) o
`journalctl --user -u engram-sync` (historial). Termina en `---- ok`; si falla, en
`ERROR: ...` y la unidad queda `failed` (exit 1).

Verificar el push-al-apagar: `systemctl --user stop engram-sync-shutdown.service`
(corre el sync una vez) y luego `systemctl --user start engram-sync-shutdown.service`
para rearmarlo. Ver el diseño de tiempos/durabilidad en `references/sync-timing.md`.

## 5. Qué hace el script
Mismo flujo que `engram-sync.ps1` v2: fetch/merge → `engram sync --import --all` →
`engram sync --all` → commit → push. Cada punto probado con un repo bare local, dos
clones y dos copias de la DB (`VACUUM INTO`, no `cp`: un `cp` pierde lo que está en el WAL):
- **Salida a stdout/stderr** (journal) y **exit 1 ante cualquier fallo**. La v1 mandaba
  todo a `/dev/null` y salía siempre con 0.
- **Sin `git reset --hard` ni `-X theirs`**. Bug reproducido en la v1: si un push falla
  sin red y la otra PC pushea, `-X theirs` pisa la entrada local de `manifest.json`; el
  chunk local queda huérfano (archivo presente, fuera del manifest) y esa memoria no
  llega nunca a la otra PC. Ahora el conflicto del manifest se resuelve con la UNIÓN
  de entradas por `id` (con `jq`, que conserva `created_at` como texto exacto, con
  nanosegundos). Otros archivos en conflicto (docs) toman la versión remota. Si algo
  queda sin resolver: `git merge --abort` y exit 1, con el estado local intacto.
- **Sin red no se frena**: importa, exporta y commitea local (exit 1 en el push); el
  push pendiente sale en la próxima corrida, con fetch+merge y reintento si la otra PC
  pusheó en el medio.
- **Historia reescrita** (force-push de un rebaseline): el merge falla por historias no
  relacionadas → exit 1 sin tocar nada; alinear con la pata C de `purge-and-rebaseline.md`.
- `GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=20'` y `GIT_TERMINAL_PROMPT=0`:
  nunca espera input. `flock` sobre `$XDG_RUNTIME_DIR/engram-sync.lock`: dos corridas no
  se pisan (la segunda sale con 0 y lo dice).
- Merge commits con el formato `sync: <host> <dd-MM-yyyy HH:MM:SS>` (America/Lima).
- **Notificaciones** `notify-send` (🧠 Engram sync), independientes y solo cuando pasó algo:
  - **"Bajado: ..."** si el fetch/merge trajo chunks nuevos de otra PC.
  - **"Subido: ..."** si el push salió bien; cuenta los chunks que `origin/main` no tenía,
    así también avisa la memoria que quedó commiteada en una corrida sin red.
  Suma sesiones/observaciones/prompts de esos chunks leyendo el manifest (no la salida
  del CLI). Sin `notify-send` o sin bus de sesión, queda un WARN y el exit code no cambia.

## 6. Blindar el fork de código si engram se clonó dentro de `~/.engram`
Si `~/.engram` es a la vez un clon del código de Engram, sacá del git el binario y
la memoria para que un `git pull` futuro no corrompa la DB:
```bash
cd "$HOME/.engram"
git rm --cached --force engram.db protocol-mode.json 2>/dev/null
git rm --cached -r .engram 2>/dev/null
printf '\nengram.db\n*.db-wal\n*.db-shm\nprotocol-mode.json\n/.engram/\n' >> .gitignore
git commit -m "chore: untrack DB viva y memoria (data-dir, no versionar)"
```

Ver validaciones finales en `SKILL.md` (Output Contract).
