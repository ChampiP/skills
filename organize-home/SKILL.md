---
name: organize-home
description: Organize, declutter, or clean up Brayan's personal home directory (~) when files pile up loose in Descargas, Escritorio, or the home root, or when the user asks to "organizar mi carpeta personal", "limpiar el home", "ordenar documentos/descargas/imágenes", or review installed apps/dotfiles for junk. Use this whenever the request is about tidying personal files, deduplicating folders, or auditing what's safe to delete on this machine — it encodes the folder scheme and safety rules already agreed with the user, so re-apply it instead of inventing a new structure from scratch.
---

# Organizar el home de Brayan

Este directorio personal ya tiene un esquema de organización acordado. La tarea no es inventar una estructura nueva — es **detectar qué se salió del esquema y devolverlo a su lugar**, respetando las reglas de seguridad de abajo.

## Estructura de referencia (ya establecida)

| Carpeta | Qué va ahí | Notas |
|---|---|---|
| `~/Documentos/Proyectos/<Cliente>/` | Documentos de trabajo por cliente (xlsx, pdf, docx, pptx) | Único lugar que se llama "Proyectos". Si aparece un cliente nuevo, crear su subcarpeta aquí. |
| `~/Dev/` | Proyectos de código/dev personales (zips, scripts, contenido ligado a desarrollo) | Antes se llamaba `~/Proyectos` — se renombró para no chocar con `Documentos/Proyectos`. **Nunca debe volver a existir una carpeta "Proyectos" en la raíz del home.** |
| `~/git-hub/` | Repositorios git reales (anka_ia, corfid_ai, sellly_AI, etc.) | Solo tocar el nivel superior (clonar/mover el repo entero). Nunca reorganizar carpetas internas de un repo (`src`, `node_modules`, `IA`, `scripts`, `memory`, etc.) — son estructura de código, no archivos personales. |
| `~/Descargas/` | Bandeja de entrada de descargas | `Descargas/Otros/` es catch-all para sueltos sin categoría — dejar como está salvo que el usuario pida limpiarlo. Si se acumulan carpetas con nombre de cliente/proyecto aquí, deben graduarse a `Documentos/Proyectos/<cliente>/`. |
| `~/Imágenes/` | Fotos, capturas, imágenes generadas por IA | Incluye `Capturas de pantalla/` y `ChatGPT_Imagenes/`. |
| `~/Vídeos/`, `~/Música/` | Media suelta sin proyecto asociado | Si un video/audio es el entregable de un proyecto activo (ej. el mp4 final dentro de una carpeta de proyecto), se queda junto al proyecto — no lo saques de su contexto. Ante la duda, pregunta. |
| `~/Escritorio/` | Carpetas de trabajo activo (proyectos en curso con su propio `.claude/`, README, recursos) | Tratar como **en uso activo** — no reorganizar ni mover nada de aquí sin preguntar explícitamente. |
| `~/DataGripProjects/`, `~/Postman/`, etc. | Carpetas de datos gestionadas por una app | Nunca tocar aunque el nombre coincida con un cliente que también tiene carpeta en `Documentos/Proyectos` (ej. `DataGripProjects/sellly` y `Documentos/Proyectos/Sellly` son cosas distintas del mismo cliente — ambas legítimas, no hay que fusionarlas). |

Los dotfiles (`.config`, `.ssh`, `.gnupg`, `.cache`, etc.) son estado de aplicaciones, no desorden personal — no se tocan salvo que el usuario pida explícitamente auditarlos (ver sección de apps más abajo).

## Procedimiento

1. **Levantar inventario.** `ls -la ~` y `du -sh` de las carpetas grandes. Buscar: archivos sueltos en la raíz del home, subcarpetas con nombres repetidos (`find <carpetas-personales> -maxdepth 3 -type d | awk -F/ '{print $NF}' | sort | uniq -d`), y comparar contra la tabla de arriba.
2. **Clasificar cada hallazgo** por tipo (documento/imagen/video/código/instalador/cache) y por dueño (¿es de un cliente? ¿es dev personal? ¿es de una app?).
3. **Antes de mover algo no trivial**, verificar que el destino tiene sentido con la tabla — si es ambiguo (¿este proyecto de video se queda con sus assets o va a Vídeos?), pregunta en vez de asumir.
4. **Antes de borrar algo** (instaladores, carpetas "fuente" de temas, dumps de base de datos, logs grandes, zips duplicados):
   - Verificar que no está en uso: `which <comando>`, `pacman -Qo <archivo>`, revisar `gsettings`/`~/.config/*/settings.ini` si es un tema, o `diff` si se sospecha que es un duplicado exacto de algo que ya se conserva en otro lado.
   - Nunca asumir "esto es basura de instalación" sin comprobarlo — una carpeta fuente de un tema o instalador puede parecer redundante y estar activa.
5. **Nunca ejecutes una acción destructiva sin confirmar primero.** Usa preguntas de confirmación agrupadas (varias decisiones en una sola tanda) en vez de una por una. Aplica también a `rm -rf`, `pacman -R`, sobrescribir archivos.
6. **Cuando dos carpetas podrían llamarse igual** (como pasó con "Proyectos"), la solución es renombrar una para desambiguar — no fusionar contenidos que sirven propósitos distintos (código vs. documentos de cliente).
7. **Reporta el estado final** con un resumen de qué se movió, qué se borró y qué se dejó igual, y por qué.

## Auditoría de apps instaladas y dotfiles (si el usuario lo pide)

Este sistema es Arch/CachyOS con KDE Plasma. Para saber qué se usa de verdad antes de sugerir desinstalar algo:

1. **Uso real de apps GUI** — KDE registra actividad en una base sqlite:
   ```
   sqlite3 ~/.local/share/kactivitymanagerd/resources/database \
     "SELECT targettedResource, count(*), datetime(max(start),'unixepoch') \
      FROM ResourceEvent WHERE targettedResource LIKE 'applications:%' \
      GROUP BY targettedResource ORDER BY 2 DESC;"
   ```
   Cruza esto contra `/usr/share/applications/*.desktop` (y `~/.local/share/applications/`) para ver qué nunca se abrió.

2. **Antes de recomendar desinstalar un paquete**, revisa quién depende de él:
   ```
   pacman -Qi <paquete> | grep "Exigido por"
   ```
   Si "Exigido por" lista algo que el usuario sí usa (o componentes del sistema como `kwin`, `plasma-workspace`, `dbeaver`, `ffmpeg`), **no lo toques** aunque el `.desktop` nunca se haya abierto — puede ser una dependencia silenciosa.

3. **Cachés de gestores de paquetes** (`~/.cache/paru`, `~/.cache/yay`) son casi siempre seguras de limpiar (son clones/builds de paquetes ya instalados, se regeneran solos si se necesitan). Verificar con `which paru yay` que ambos existen antes de asumir que hay redundancia.

4. Presenta la clasificación (uso alto / ocasional / nunca detectado) y **pide confirmación explícita antes de desinstalar nada** — el ahorro de espacio rara vez justifica el riesgo si el usuario no lo pidió con esa intención.

## Principios generales

- El home mezcla vida personal + trabajo de cliente + desarrollo de software — no asumas que un solo criterio de archivado aplica a todo. Si aparece una carpeta nueva con nombre de cliente, pregunta a qué "cajón" (Documentos/Proyectos, Dev, o dejarla en Descargas) pertenece.
- Preferir renombrar/mover sobre borrar cuando hay ambigüedad.
- Todo lo que sea archivo de trabajo activo (Escritorio, proyectos con `.claude/` propio) se trata como intocable salvo permiso explícito.
