# Documentación oficial de Engram (fuente de verdad)

No inventar comandos ni flags: consultar estos archivos del repo de Engram.
Si el repo local no está clonado: `github.com/Gentleman-Programming/engram`.

- Instalación (brew, `go install`, binarios, Windows, env vars):
  `~/git-hub/engram/docs/INSTALLATION.md`
- Sync por chunks y cloud (mecanismo, guardrails, idempotencia):
  `~/git-hub/engram/docs/codebase/sync-and-cloud.md`
- Setup de agentes (Claude Code, Cursor, etc.):
  `~/git-hub/engram/docs/AGENT-SETUP.md`

## Hechos oficiales clave (confirmados en la doc)
- `ENGRAM_DATA_DIR` default `~/.engram` (Windows `%USERPROFILE%\.engram`); DB en `.engram/engram.db`.
- `ENGRAM_PORT` default `7437`.
- Sync git = chunks en `.engram/manifest.json` + `.engram/chunks/*.jsonl.gz`.
  "avoids one large shared JSON file… reduces merge conflicts and lets multiple
  machines generate memory in parallel."
- Guardrails oficiales: no modificar chunks viejos; mantener el tracking de chunks
  importados para evitar duplicados; el SQLite local es la fuente de verdad.

## Comandos usados por esta skill (verificados)
- `engram sync --all`            exporta TODA la memoria a chunks en `<cwd>/.engram/`.
- `engram sync --import --all`   importa chunks de `<cwd>/.engram/` al DB (idempotente).
- `engram sync --status`         muestra chunks locales/remotos y "Pending import".
- `engram sync --all --force`    export completo ignorando estado incremental (raro).
- `engram export <f.json>` / `engram import <f.json>`  dump completo JSON —
  ⚠ el import NO deduplica: duplica memoria si ya existe. Sólo para backup/recuperación,
  NUNCA para el sync recurrente.
- `engram doctor`                diagnóstico read-only.
