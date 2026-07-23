# Purgar datos ajenos/no deseados y reconstruir el baseline

Síntoma: la memoria trae proyectos/sesiones que NO son del usuario (típico al forkear
un repo de Engram con memoria de terceros, o al mezclar máquinas). Borrarlos de la DB
local **no alcanza**: vuelven en el próximo import.

## Por qué vuelven (la causa raíz)

El sync por chunks es **ADITIVO**: importa haciendo *upsert por `sync_id`* y **no
propaga borrados**. No existe un "chunk de borrado". Entonces:

- Si borrás filas de `engram.db` (peor aún con SQL crudo, que además saltea el journal
  de sync), los chunks viejos del repo **siguen conteniendo** esa data.
- Cualquier máquina que importe desde cero (o un `engram.db` reseteado) **re-inyecta**
  todo lo viejo. La limpieza local sola es reversible por el propio sync.

Regla: para eliminar data de verdad hay que **(A)** limpiar la DB de CADA máquina y
**(B)** reconstruir el baseline del repo. Las dos patas, o no sirve.

## 0. Identificar qué es ajeno (por directorio, no por nombre)

El `project` se detecta por `dir_basename`, así que es ruidoso. El discriminador
confiable es el **directorio de la sesión**:
```bash
DB="$HOME/.engram/engram.db"
sqlite3 -header "$DB" "SELECT DISTINCT directory FROM sessions ORDER BY directory;"
# ej: /Users/otro-usuario/... = máquina ajena que llegó con el fork
sqlite3 "$DB" "SELECT project, COUNT(*) FROM sessions GROUP BY project ORDER BY 2 DESC;"
```

## A. Limpiar la DB local (backup SIEMPRE primero)

Preferí el CLI cuando puedas — `engram delete project <name> --hard` cascadea y es la
vía soportada. Sólo caé a SQL crudo para criterios que el CLI no cubre (p.ej. borrar
por `directory`). El SQL crudo NO genera mutaciones de sync (por eso hace falta la pata B).

```bash
DB="$HOME/.engram/engram.db"
cp "$DB" "$DB.bak-$(TZ=America/Lima date +%F-%H%M)"     # red de seguridad

# Opción CLI (preferida):
engram delete project "<proyecto-ajeno>" --hard

# Opción SQL cruda (por directorio) — en transacción, limpiando relaciones huérfanas:
sqlite3 "$DB" <<'SQL'
BEGIN;
CREATE TEMP TABLE del AS
  SELECT sync_id FROM observations
  WHERE session_id IN (SELECT id FROM sessions WHERE directory LIKE '/Users/AJENO%');
DELETE FROM memory_relations
  WHERE source_id IN (SELECT sync_id FROM del) OR target_id IN (SELECT sync_id FROM del);
DELETE FROM user_prompts WHERE session_id IN (SELECT id FROM sessions WHERE directory LIKE '/Users/AJENO%');
DELETE FROM observations  WHERE session_id IN (SELECT id FROM sessions WHERE directory LIKE '/Users/AJENO%');
DELETE FROM sessions      WHERE directory LIKE '/Users/AJENO%';
DROP TABLE del;
COMMIT;
SQL

# Verificar salud (los triggers mantienen el FTS solos):
sqlite3 "$DB" "PRAGMA integrity_check;"                                  # -> ok
sqlite3 "$DB" "SELECT COUNT(*) FROM observations WHERE session_id NOT IN (SELECT id FROM sessions);"  # -> 0 huérfanos
sqlite3 "$DB" "INSERT INTO observations_fts(observations_fts) VALUES('integrity-check');" && echo FTS ok
sqlite3 "$DB" "VACUUM;"
```

Para unificar identidades de la MISMA persona (p.ej. hostname viejo → nuevo):
```bash
for t in sessions observations user_prompts; do
  sqlite3 "$DB" "UPDATE $t SET project='NUEVO' WHERE project='VIEJO';"
done
```

## B. Reconstruir el baseline del repo (borra la data ajena del transporte)

```bash
R="$HOME/.engram-sync"
systemctl --user stop engram-sync.timer            # que no pushee a mitad de camino
cp -r "$R/.engram" "/tmp/chunks-sucios-bak"        # backup de los chunks viejos

rm -f "$R/.engram/chunks/"* "$R/.engram/manifest.json"
cd "$R" && ENGRAM_DATA_DIR="$HOME/.engram" engram sync --all   # exporta la DB limpia -> 1 chunk nuevo
```

Verificar que el baseline quedó limpio **mirando SÓLO campos estructurados**, no texto:
```bash
for c in "$R/.engram/chunks/"*.gz; do zcat "$c"; done \
  | rg -c '"project":"AJENO"|/Users/AJENO'            # -> 0
```
OJO: no cuentes menciones sueltas del nombre en `content`/`title` — los prompts y
memorias del propio usuario pueden nombrar lo ajeno legítimamente (ej. "borrá lo de X").
Sólo los campos `"project":"..."` / `directory` estructurados son basura real.

Aplastar historia (para que la data ajena tampoco quede en `git log`) y force-push:
```bash
cd "$R"
git checkout --orphan clean-baseline -q
git add -A
git commit -q -m "sync: $(hostname) $(TZ=America/Lima date +%d-%m-%Y\ %H:%M:%S)"
git branch -D main -q; git branch -m main
git push -f origin main
systemctl --user start engram-sync.timer
systemctl --user start engram-sync.service         # 1 corrida de prueba: la DB NO debe cambiar
```
El `git merge -X theirs` / `git reset --hard origin/main` del script hace que las demás
máquinas adopten la historia reescrita en su próximo sync (remoto gana). No hace falta
tocar git en las otras PCs.

## C. Cada OTRA máquina debe limpiar su DB también

Quitar los chunks del repo **no borra** las filas que esa máquina ya importó. Opciones
para la PC pendiente (ej. Windows):

- **Rápido (recomendado):** borrar su base y repoblar desde el baseline limpio.
  ```powershell
  Stop-ScheduledTask -TaskName EngramSyncPeriodic 2>$null
  # cerrar engram serve/mcp si están corriendo
  Remove-Item "$HOME\.engram\engram.db*" -Force
  cd "$HOME\.engram-sync"; git fetch origin main; git reset --hard origin/main
  powershell -NoProfile -File "$HOME\.engram-sync\engram-sync.ps1"   # import trae SOLO lo limpio
  engram sync --status
  ```
- **Quirúrgico:** repetir la pata A (mismo SQL/CLI) en esa máquina. Más trabajo, sin ventaja.

## Checklist de cierre
- DB local: `integrity_check` = ok, 0 huérfanos, sin proyectos/directorios ajenos.
- Repo: 1 chunk limpio en HEAD, `rg -c '"project":"AJENO"'` = 0, force-push hecho.
- Corrida de sync post-fix: los conteos NO cambian (no re-inyecta).
- Todas las máquinas limpiadas (o su `engram.db` reseteado y repoblado del baseline).
