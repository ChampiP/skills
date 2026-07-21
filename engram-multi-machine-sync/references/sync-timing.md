# Tiempos y durabilidad del sync (qué se pierde y qué no)

## Modelo
- `mem_save` (o `engram save`) escribe al **DB local al instante**. Nunca se pierde
  localmente por apagar la PC.
- El **push a git** ocurre solo cuando corre `engram-sync.sh`. Entre corridas, los
  cambios están en el DB local pero aún no en el repo remoto.

## Cuándo corre el sync (3 disparadores)
1. **Al iniciar** — trae cambios de la otra máquina antes de trabajar.
   Linux: timer `OnBootSec=2min`. Windows: tarea `onlogon`.
2. **Cada 10 min** — push periódico corto (ventana máxima de pérdida ≈ 10 min).
   Linux: `OnUnitActiveSec=10min`. Windows: tarea `minute /mo 10`.
3. **Al apagar/cerrar sesión** (Linux, best-effort) — servicio con `ExecStop`.
   Windows no tiene equivalente simple; queda cubierto por (2).

## Garantías reales (honesto)
- **Apagado normal en Linux**: el push-al-apagar dispara → cambios sincronizados
  (si hay red en ese momento). Si la red ya cayó, quedan para el próximo arranque.
- **Apagado normal en Windows**: se pierde a lo sumo lo de los últimos ~10 min (hasta
  el próximo tic); al re-encender cualquiera de las dos PCs, se sincroniza.
- **Corte abrupto (tirar el cable / batería a 0)**: se puede perder lo guardado desde
  el último push (≤10 min). Nada lo evita sin un servidor en vivo.
- El DB local **siempre** conserva todo; "perder" aquí significa "todavía no llegó al
  repo", no "se borró".

## Flujo entre dos PCs (por qué converge)
1. PC-A guarda memoria → push (periódico / al apagar) sube chunks nuevos.
2. PC-B al iniciar → pull baja esos chunks → `engram sync --import` los mergea (dedup).
3. Los chunks tienen nombre por hash: dos PCs no colisionan. Si el `manifest.json`
   choca, gana el remoto y el re-export lo regenera → siempre converge.

## Si querés cero pérdida real (opcional, no montado)
Usar **Engram Cloud** (`engram sync --cloud --project <p>` contra `engram cloud serve`)
da push/pull continuo con resolución de conflictos en el servidor. Requiere levantar
ese servidor (self-host docker o VPS). Ver `references/official-docs.md`.

## Bajar aún más la ventana
Editar el intervalo: Linux `OnUnitActiveSec` en `~/.config/systemd/user/engram-sync.timer`
(luego `systemctl --user daemon-reload && systemctl --user restart engram-sync.timer`);
Windows recrear `EngramSyncPeriodic` con otro `/mo`.
