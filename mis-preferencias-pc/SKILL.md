---
name: mis-preferencias-pc
description: Gustos y preferencias de Brayan para configurar su escritorio CachyOS/KDE Plasma, terminal (kitty/fish/zsh) y automatizaciones — basado en decisiones reales que tomó durante varias sesiones de configuración. Úsalo SIEMPRE que Brayan pida mejorar/cambiar/personalizar su terminal, su escritorio, atajos, temas de color, prompt, o automatizaciones del sistema, para no repetir cosas que ya rechazó explícitamente ni reinventar lo que ya tiene funcionando. También sirve como referencia de "cómo le gusta trabajar conmigo" (forma de preguntar, nivel de autonomía, honestidad ante límites técnicos).
---

# Preferencias de entorno y de colaboración de Brayan

Esta skill resume decisiones **ya tomadas** sobre su PC (CachyOS + KDE Plasma 6,
kitty + fish/zsh) para que cualquier sesión futura de Claude Code parta del
mismo punto, en vez de proponer desde cero cosas que Brayan ya probó y aceptó
o rechazó. El repo con los archivos de config reales es
`github.com/ChampiP/kitty` (clonado en `~/git-hub/kitty`) — **esa es la fuente
de verdad de los archivos**; esta skill es la fuente de verdad de **por qué**
están así y qué NO volver a proponer.

## Estética: vivo y saturado, no plano ni pastel

Probó un tema morado/índigo oscuro completo (fondo, tabs, bordes, scrollbar) y
lo revirtió dos veces — la primera vez porque "lo sentía muerto/apagado" con
colores muy planos, la segunda vez con el morado específicamente porque
"no me está gustando". Terminó de vuelta en la paleta ANSI original, vívida
y saturada (`background #1e1e2e`, colores tipo macOS WhiteSur). **Conclusión:
prefiere colores vivos/contrastados sobre paletas suaves o monocromáticas.**
Si propones un cambio de color, dale una opción vívida, no un pastel apagado.

## Transparencia: sí, bastante, pero sin magia automática

Terminó en `background_opacity 0.72` (empezó en 0.85, la fue subiendo). Pidió
que la opacidad se ajustara sola según si la ventana está encima o en una
esquina (auto-detección de solapamiento) — se le explicó que kitty no tiene
esa capacidad nativa (no sabe qué hay debajo de la ventana), y lo aceptó sin
insistir. **No proponer ese auto-ajuste como si fuera posible** a menos que
implique construir algo con KWin scripting + kitty remote-control (marcado
como trabajo opcional futuro, nunca pedido).

También pidió un atajo para alternar opacidad manualmente
(`dynamic_background_opacity` + `Ctrl+Shift+A`), lo probó, y luego pidió
quitarlo explícitamente ("no me sirven"). **No lo vuelvas a agregar** salvo
que lo pida de nuevo.

## Rechazó explícitamente (no reintroducir sin que lo pida de nuevo)

- Atajos de kitty para lanzar Claude Code / OpenCode automáticamente.
- Una "mascota" animada en el terminal (probó con nyancat en un panel
  permanente tipo VS Code pet, lo pidió, y luego dijo "elimina lo del
  gatito" — el concepto en sí no encajó una vez implementado).
- Usar `Windows+B` o `Windows+A` para atajos custom — son atajos reales de
  KDE (power-profile y clipboard-history respectivamente), causaban
  conflicto.
- El toggle de opacidad dinámica (ver arriba).

## Lo que sí quedó y usa a diario

- **kitty**: `shell zsh` por defecto (cambiado desde `fish` porque quería
  consistencia con lo que abre Cursor). fish sigue instalado y configurado
  igual de completo — se puede abrir con `fish` a mano si se necesita.
- **Prompt**: starship con paleta calcada de los colores de kitty
  (`~/.config/starship.toml`, `[palettes.kitty]`).
- **fastfetch**: logo aleatorio entre variantes `_small` de varias distros
  (evita que el ASCII art se distorsione al achicar la ventana) + una
  leyenda de qué significa cada símbolo del prompt, impresa hasta que se la
  aprenda de memoria (el propio Brayan dijo que la deje así).
- **atuin** (Ctrl+R, historial con duración/código de salida), **zoxide**
  (`z <algo>`), **fzf** (Ctrl+T / Alt+C) — todo integrado sin choques de
  atajos (Ctrl+R es de atuin, no de fzf).
- **Powerlevel10k desactivado** en zsh (`prompt_powerlevel9k_teardown` +
  `POWERLEVEL9K_INSTANT_PROMPT=off`) a favor de starship, para que zsh se
  vea igual que fish.
- **Windows+S**: divide la ventana de kitty y abre otra terminal
  (`launch --type=window --cwd=current`).
- **Automatizaciones de sistema** (`systemd --user timers`, nunca cron —
  no está instalado): scripts de ObsiNotes corriendo solos (sync de Notion,
  transcripción, clasificación de Kanban, aviso de tareas pendientes al
  iniciar sesión). Ver `~/git-hub/obsidian/ObsiNotes/AGENTS.md`.
- **Seguridad/mantenimiento del sistema**: fail2ban en sshd, snapshots
  automáticos de snapper (timeline + los que ya dispara `snap-pac` en cada
  update de pacman), firewall ufw activo (solo 22 y 1714-1764 abiertos).
- **Klipper**: historial de portapapeles en 200, persistente.
- **lazydocker**: instalado para manejar contenedores Docker sin comandos
  largos.
- **KDE Connect**: instalado; falta emparejar el celular (posible bloqueo
  por aislamiento de clientes AP en el router — fuera del control del PC).

## Cómo le gusta que trabajemos

- **Verificar antes de recomendar**: varias veces la causa real de un
  problema no era la que parecía a primera vista (ufw sí estaba bien
  configurado, el problema de KDE Connect era de red/router; la
  autosugerencia de zsh sí funcionaba, la ventana vieja no había recargado
  config). Prefiere que se pruebe/confirme con comandos reales antes de dar
  un diagnóstico, en vez de asumir.
- **Ser honesto sobre límites técnicos** en vez de insistir a ciegas: el
  atajo `Alt+K` de KDE no se pudo aplicar en caliente por D-Bus/config —
  se le explicó la causa real (requiere System Settings o logout) y se
  paró ahí en vez de seguir probando cosas al azar.
- **Preguntar con opciones concretas** cuando hay una decisión de gusto
  (color, qué automatizar) en vez de una pregunta abierta — responde mejor
  a "elige entre A/B/C" que a "¿qué quieres?".
- **Iterar rápido y revertir sin drama**: pide un cambio, lo prueba, y si
  no le gusta lo dice directo ("revierte eso también", "no me sirve") — no
  hay que insistir en defender un cambio ya rechazado.
- Escribe en español, informal, con errores de tipeo — no hace falta
  formalidad en las respuestas.
