# Setup del sync de memoria Engram en Linux / macOS (de cero)

Genérico: reemplazá `<REPO_SSH>` por la URL del repo privado de sync (ej.
`git@github.com:USUARIO/engram-champip.git`). Sirve para una PC nueva con una
base nueva o para sumar una máquina a un repo de memoria ya existente.

## 0. Pre-requisitos
- `engram` instalado y en PATH — ver `references/official-docs.md` (Homebrew o `go install`).
- `git` con acceso SSH al repo privado de sync.
- Verificar: `engram --help` y `git ls-remote <REPO_SSH>` responden.

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
engram sync --status     # debe mostrar "Pending import: 0"
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
Verificar el push-al-apagar: `systemctl --user stop engram-sync-shutdown.service`
(corre el sync una vez) y luego `systemctl --user start engram-sync-shutdown.service`
para rearmarlo. Ver el diseño de tiempos/durabilidad en `references/sync-timing.md`.

## 5. Blindar el fork de código si engram se clonó dentro de `~/.engram`
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
