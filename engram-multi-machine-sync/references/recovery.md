# Recuperar un engram.db corrupto

Síntoma: `engram sync --status` imprime `database disk image is malformed`.
Causa típica: un git-sync viejo versionaba el binario `engram.db` y lo reescribió
mientras `engram serve` lo tenía abierto (SQLite no lo soporta → corrupción).

Regla: trabajar SIEMPRE sobre copias. No borrar los originales hasta terminar.

## 1. Parar procesos y liberar la DB
```bash
for p in $(pgrep -x engram); do kill -TERM "$p"; done   # NO uses pkill -f "engram mcp": matchea tu propio comando
sleep 2
lsof "$HOME/.engram/engram.db" 2>/dev/null || echo "DB liberada"
systemctl --user disable --now engram-sync.timer 2>/dev/null   # frenar el sync viejo
```

## 2. Respaldar todo y medir cuánto se salva (sobre copia)
```bash
BK="$HOME/.engram-recovery-$(TZ=America/Lima date +%F)"; mkdir -p "$BK"
cp -a "$HOME/.engram/"engram.db* "$BK/" 2>/dev/null
sqlite3 "$BK/engram.db" "PRAGMA integrity_check;" | head   # ver el alcance del daño
```

## 3. Recuperar con `.recover` + reconstruir el índice FTS
```bash
sqlite3 "$BK/engram.db" ".recover" > "$BK/recovered.sql" 2>/dev/null
sqlite3 "$BK/clean.db" < "$BK/recovered.sql"
sqlite3 "$BK/clean.db" "INSERT INTO observations_fts(observations_fts) VALUES('rebuild');"
sqlite3 "$BK/clean.db" "DELETE FROM observations WHERE content IS NULL OR length(trim(content))=0;"
sqlite3 "$BK/clean.db" "PRAGMA integrity_check;"           # debe decir: ok
```
Nota: la copia con WAL presente (copiada en caliente) suele traer más datos que la
posterior al apagado; comparar `SELECT count(*) FROM observations;` y quedarse con la mayor.

## 4. Arreglar observaciones huérfanas (FK) antes de exportar a JSON
El import de JSON es estricto y aborta si una observación apunta a una sesión que no
existe. Recrear las sesiones faltantes preservando su id/proyecto:
```bash
sqlite3 "$BK/clean.db" "INSERT INTO sessions (id, project, directory, started_at, summary)
  SELECT DISTINCT o.session_id, COALESCE(NULLIF(o.project,''),'recovered'), '$HOME', datetime('now'), 'sesion reconstruida'
  FROM observations o LEFT JOIN sessions s ON o.session_id=s.id
  WHERE s.id IS NULL AND o.session_id IS NOT NULL;"
```

## 5. Instalar el DB limpio
```bash
mv "$HOME/.engram/"engram.db* "$BK/corrupto/" 2>/dev/null  # ya respaldado
mkdir -p "$BK/corrupto"; cp "$BK/clean.db" "$HOME/.engram/engram.db"
engram sync --status      # ya no debe decir "malformed"
```

## 6. Reiniciar serve y pasar al sync por chunks
```bash
ENGRAM_DATA_DIR="$HOME/.engram" nohup engram serve >/tmp/engram-serve.log 2>&1 & disown
```
Después seguir `setup-linux.md` para dejar el sync por chunks (nunca binario).

## Alternativa simple si no importa perder poco
Si hay un repo de sync sano con chunks recientes: borrar `~/.engram/engram.db*`,
correr `engram-sync.sh` una vez y el import reconstruye la memoria desde los chunks.
