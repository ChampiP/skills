---
name: engram-multi-machine-sync
description: "Trigger: sincronizar memoria engram, engram multi-maquina, configurar engram sync, engram corrupto/malformed, nueva PC engram, sync Windows/Linux. Setup seguro end-to-end del sync de memoria Engram por chunks entre maquinas, sin corromper la DB."
license: Apache-2.0
metadata:
  author: "ChampiP"
  version: "1.0"
---

# Sync de memoria Engram entre máquinas (seguro, por chunks)

Configura, desde cero y de punta a punta, el sync de la memoria de Engram entre
varias PCs (Linux/macOS/Windows) usando un repo git privado. Es genérico: sirve con
cualquier repo y cualquier base (nueva o existente). El agente puede armar todo solo
en una PC nueva siguiendo las references.

## Activation Contract
Usar cuando el usuario pida: instalar/configurar el sync de Engram, sumar una PC
nueva, arreglar un `engram.db` corrupto (`database disk image is malformed`), o
migrar la memoria a otra máquina/repo. No usar para cambios de código de Engram.

## Hard Rules
- El binario `engram.db` NUNCA entra a git. Versionarlo lo corrompe (git lo reescribe
  mientras `engram serve` lo tiene abierto). Es la causa raíz a evitar siempre.
- Sincronizar SOLO por chunks (`engram sync`). Los chunks deduplican al importar.
- NO usar `engram export/import` (JSON) para el sync recurrente: el import NO
  deduplica y DUPLICA la memoria. JSON sólo para backup/recuperación puntual.
- El SQLite local es la fuente de verdad; el repo de sync es transporte, no dueño.
- El sync es ADITIVO (upsert por `sync_id`) y NO propaga borrados: no hay "chunk de
  borrado". Borrar filas de la DB local NO alcanza — los chunks viejos las reinyectan
  en el próximo import. Para eliminar data de verdad hay que limpiar la DB de CADA
  máquina Y reconstruir el baseline del repo (ver `references/purge-and-rebaseline.md`).
- Data-dir (`~/.engram`, la DB) y repo de sync (`~/.engram-sync`, los chunks) van
  SEPARADOS. Nunca cruzarlos.
- Todo commit de sync debe tener el formato exacto:
  `sync: <hostname> <dd-MM-yyyy HH:MM:SS>` en zona `America/Lima`
  (ej. `sync: cachyos 20-07-2026 19:14:52`). Ya lo generan los scripts de `assets/`.
- No inventar comandos/flags: verificar en `references/official-docs.md`.

## Decision Gates
| Situación | Acción |
|-----------|--------|
| PC Linux/macOS nueva | Seguir `references/setup-linux.md` con `assets/engram-sync.sh` + systemd |
| PC Windows nueva | Seguir `references/setup-windows.md` con `assets/engram-sync.ps1` + Task Scheduler |
| `engram sync --status` dice "malformed" | Primero `references/recovery.md`, luego el setup |
| Hay que borrar data ajena/no deseada (fork con memoria de terceros, purgar proyectos) | `references/purge-and-rebaseline.md`: limpiar DB de cada máquina + reconstruir baseline |
| Otro repo/otra base | Cambiar `<REPO_SSH>` al clonar; los scripts son env-driven, no tocar |
| engram no instalado | Instalar según `references/official-docs.md` (brew / `go install`) |

## Execution Steps
1. Confirmar engram instalado y acceso SSH al repo privado (ver official-docs).
2. Si la DB está corrupta, ejecutar `references/recovery.md` completo antes de seguir.
3. Ejecutar la guía del OS correspondiente (setup-linux / setup-windows): clonar repo
   de sync, instalar script, primer sync, y programar los disparadores.
4. Programar los 3 disparadores (ver `references/sync-timing.md`): pull al iniciar,
   push cada 10 min, y push al apagar (Linux best-effort). No dejar solo el periódico.
5. Blindar `~/.engram` si contiene un clon de código (untrack binario + memoria).
6. Validar (Output Contract) antes de dar por terminado.

## Output Contract
El setup está completo sólo si TODO esto se cumple:
- `engram sync --status` → sin errores y `Pending import: 0`.
- Correr el script 2 veces seguidas → el conteo de observaciones NO cambia
  (`sqlite3 ~/.engram/engram.db 'SELECT count(*) FROM observations;'`): no duplica.
- `PRAGMA integrity_check;` → `ok`.
- En el repo de sync: `git ls-files | grep engram.db` → vacío (0 binario en git).
- Scheduler activo (Linux `systemctl --user is-active engram-sync.timer` → `active`;
  Windows `schtasks /query /tn EngramSync`).
- Último commit del repo con formato `sync: <host> <dd-MM-yyyy HH:MM:SS>`.

## References
- `references/setup-linux.md` — setup Linux/macOS de cero.
- `references/setup-windows.md` — setup Windows de cero.
- `references/sync-timing.md` — cuándo corre el sync, qué se pierde y qué no, y cómo bajar la ventana.
- `references/recovery.md` — recuperar un `engram.db` corrupto.
- `references/purge-and-rebaseline.md` — borrar data ajena/no deseada y reconstruir el baseline (sync aditivo no propaga borrados).
- `references/official-docs.md` — doc oficial de Engram y comandos verificados.
- `assets/engram-sync.sh`, `assets/engram-sync.ps1` — scripts de sync (genéricos).
- `assets/engram-sync.service`, `assets/engram-sync.timer`,
  `assets/engram-sync-shutdown.service` — unidades systemd (periódico + push al apagar).
