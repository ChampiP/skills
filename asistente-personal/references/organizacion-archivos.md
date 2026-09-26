# Organización de archivos y carpetas

La tarea no es inventar estructura: es detectar qué se salió del esquema y devolverlo a su lugar.

## Carpetas del sistema (no hardcodear nombres)

Los nombres cambian por idioma y OS (`Downloads`/`Descargas`). Resolverlos en tiempo real:

| OS | Comando |
|---|---|
| Linux | `xdg-user-dir DOCUMENTS` / `DOWNLOAD` / `PICTURES` / `VIDEOS` / `MUSIC` / `DESKTOP` |
| Windows | `[Environment]::GetFolderPath('MyDocuments')` (y `Desktop`, `MyPictures`, `MyVideos`, `MyMusic`); Descargas: `(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path` |
| macOS | `~/Documents`, `~/Downloads`, `~/Pictures`, `~/Movies`, `~/Music`, `~/Desktop` |

## Esquema

| Carpeta | Qué va | Regla |
|---|---|---|
| `~/Work/<repo>` | Repos git | Solo mover el repo entero; nunca reorganizar su interior |
| `~/Work/chats/<tema>` | Todo lo que no es repo: consultas, archivos pesados, scripts o zips de dev sueltos | Nunca `git init`; si crece como código, convertirlo en repo en `~/Work/<repo>` |
| `<DOCUMENTS>/Proyectos/<Cliente>` | Documentos de cliente (xlsx, pdf, docx, pptx) | Cliente nuevo → subcarpeta nueva |
| `<DOWNLOAD>` | Bandeja de entrada | Carpetas con nombre de cliente se gradúan a `Proyectos/<Cliente>` |
| `<PICTURES>`, `<VIDEOS>`, `<MUSIC>` | Media suelta | Si es entregable de un proyecto, se queda con el proyecto |
| `<DESKTOP>` | Trabajo activo | No tocar sin permiso explícito |
| Datos de apps (`DataGripProjects`, `Postman`, dotfiles, `.cache`) | Estado de aplicaciones | No tocar salvo auditoría pedida |

No debe existir otra raíz de repos (`~/github`, `~/git-hub`, `~/Dev`): todo vive en `~/Work`.

## Procedimiento

1. Inventario: `ls -la ~` y `du -sh` de las carpetas grandes; buscar sueltos en la raíz y nombres duplicados.
2. Clasificar cada hallazgo por tipo (documento, media, código, instalador, cache) y dueño (cliente, personal, app).
3. Destino ambiguo → preguntar. Dos carpetas con igual nombre y distinto propósito → renombrar una, no fusionar.
4. Antes de borrar: comprobar que no está en uso (`which`, `pacman -Qo`, `diff` contra el duplicado).
5. Confirmar acciones destructivas en una sola tanda.
6. Reportar qué se movió, qué se borró y qué quedó igual.

## Auditoría de apps (solo si la pide)

| OS | Uso / dependencias |
|---|---|
| Arch (Omarchy) | `LC_ALL=C pacman -Qi <pkg>` → campo "Required By" (sin `LC_ALL=C` sale traducido, ej. "Exigido por"); no desinstalar si algo usado depende de él |
| Windows | `winget list`; revisar dependencias antes de desinstalar |

Cachés de `paru`/`yay` son seguras de limpiar. Pedir confirmación explícita antes de desinstalar.
