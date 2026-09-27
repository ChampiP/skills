# Bootstrap de una máquina nueva

Brayan clona este repo en `~/Work/skills`, abre un agente ahí y pide "haz lo que dicen mis skills". Ejecutar en orden; confirmar antes de borrar o mover. Todo es re-ejecutable.

## 1. Estructura base

| Ruta | Contenido |
|---|---|
| `~/Work/` | Única raíz de trabajo (Windows: `$HOME\Work\`). Ningún agente corre en `~` |
| `~/Work/<repo>/` | Repos git (`git clone` directo acá) |
| `~/Work/chats/<tema>/` | Todo lo que no es repo: consultas, excel, audio, video, scripts o zips sueltos. Nunca `git init` |
| `~/Work/skills/` | Este repo (`git@github.com:ChampiP/skills.git`) |
| `~/Work/ObsiNotes/` | Vault Obsidian (`git@github.com:ChampiP/ObsiNotes.git`) |
| `~/Work/kitty/` | Config de terminal (`git@github.com:ChampiP/kitty.git`), tiene su propio README |

## 2. Dónde lee skills cada agente

| Agente | Global (todos los proyectos) | Solo proyecto |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `<proyecto>/.claude/skills/` |
| Codex, OpenCode, Gemini/Antigravity, Pi/gentle-shell | `~/.agents/skills/` | `<proyecto>/.agents/skills/` |
| Pi (propio) | `~/.pi/agent/skills/` | — |
| Codex (propio) | `~/.codex/skills/` | — |
| OpenCode (propio) | `~/.config/opencode/skills/` | — |
| Gemini (propio) | `~/.gemini/skills/` | — |

La búsqueda de skills de proyecto sube carpetas pero se detiene en la raíz del repo git: desde `~/Work/<repo>` nunca se ve `~/Work/.claude` ni `~/Work/.agents`.

## 3. Limpiar antes de instalar

Buscar `asistente-personal cv-ats-harvard engram-multi-machine-sync mis-preferencias-pc organize-home use-obsinotes` en cada ruta global de la tabla 2. Si alguno es una carpeta real (no enlace), moverlo al backup tras confirmar:

```bash
mkdir -p ~/.local/share/skills-backup && mv <ruta> ~/.local/share/skills-backup/
```

```powershell
New-Item -ItemType Directory -Force "$HOME\skills-backup" | Out-Null; Move-Item <ruta> "$HOME\skills-backup\"
```

Mover también al backup, si existen, restos de haber corrido un agente en el home: `~/AGENTS.md`, `~/CLAUDE.md`, `~/GEMINI.md`, `~/.atl`, `~/.playwright-mcp`. (`~/.codegraph` NO: es la config global de CodeGraph).

## 4. Instalar skills (enlaces, sin copias que se desincronizan)

Scope Work: `asistente-personal`. Global: `use-obsinotes`. Nunca instalar como skill: `cv-ats-harvard`, `engram-multi-machine-sync` (se leen bajo demanda).

Linux/macOS:

```bash
mkdir -p ~/Work/.claude/skills ~/Work/.agents/skills ~/.claude/skills ~/.agents/skills
ln -sfn ../../skills/asistente-personal ~/Work/.claude/skills/asistente-personal
ln -sfn ../../skills/asistente-personal ~/Work/.agents/skills/asistente-personal
ln -sfn ~/Work/skills/use-obsinotes ~/.claude/skills/use-obsinotes
ln -sfn ~/Work/skills/use-obsinotes ~/.agents/skills/use-obsinotes
```

Windows (PowerShell; junction no requiere admin; `Delete()` quita solo el enlace y falla si es carpeta real, que el paso 3 ya movió):

```powershell
$links = @{
  "$HOME\Work\.claude\skills\asistente-personal" = "$HOME\Work\skills\asistente-personal"
  "$HOME\Work\.agents\skills\asistente-personal" = "$HOME\Work\skills\asistente-personal"
  "$HOME\.claude\skills\use-obsinotes"           = "$HOME\Work\skills\use-obsinotes"
  "$HOME\.agents\skills\use-obsinotes"           = "$HOME\Work\skills\use-obsinotes"
}
foreach ($l in $links.Keys) {
  New-Item -ItemType Directory -Force (Split-Path $l) | Out-Null
  if (Test-Path $l) { (Get-Item $l -Force).Delete() }
  New-Item -ItemType Junction -Path $l -Target $links[$l] | Out-Null
}
```

Pi/gentle-shell solo carga skills de proyecto si la carpeta es confiable: abrir `pi` en `~/Work` una vez y aceptar con `/trust` (se guarda en `~/.pi/agent/trust.json`). En modo `pi -p` usar `--approve`.

## 5. Candados y config global

- Agentes nunca en `~`: Linux agregar al final de `~/.zshrc` → `[ -f ~/Work/skills/dotfiles/agent-guard.zsh ] && source ~/Work/skills/dotfiles/agent-guard.zsh`. Windows agregar a `$PROFILE` → `. "$HOME\Work\skills\dotfiles\agent-guard.ps1"`.
- Gitignore global para cachés de agentes: crear `~/.config/git/ignore` con `.atl/` y `.codegraph/`, y `git config --global core.excludesFile ~/.config/git/ignore`.
- Engram en la raíz Work: `cd ~/Work && engram init work` (sin esto responde "ambiguous project" por los muchos repos hijos).
- Engram en el home: `cd ~ && engram init work`, así un agente abierto en `~` guarda en `work` y no en un proyecto con el nombre del usuario. Crea `~/.engram/config.json` al lado de `engram.db` (convive bien, verificado). Solo cubre `~` exacto: las subcarpetas sin config propia toman su propio nombre. Las memorias viejas de `champip`/`diver` no se mueven: no hay comando documentado (`rescue-ownership` rechaza lo que ya tiene dueño y `consolidate` no los agrupa), y un `UPDATE` directo exigiría reconstruir el baseline.
- Statusline de Claude Code: copiar `~/Work/skills/dotfiles/statusline.sh` a `~/.claude/statusline.sh` y en `~/.claude/settings.json` poner `"statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"}`.
- Sync de Engram: seguir `~/Work/skills/engram-multi-machine-sync/SKILL.md`.
- Atajos globales Windows (`Win+Enter` = Windows Terminal con PowerShell 7 en `$HOME\Work`, como `Super+Enter` en Hyprland). Instalar AutoHotkey v2 y registrar `dotfiles\hotkeys.ahk` al inicio de sesión:

  ```powershell
  winget install --id AutoHotkey.AutoHotkey -e --scope user --accept-package-agreements --accept-source-agreements
  $ahk = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
  $script = "$HOME\Work\skills\dotfiles\hotkeys.ahk"
  $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'hotkeys.lnk'))
  $s.TargetPath = $ahk; $s.Arguments = "`"$script`""; $s.WorkingDirectory = "$HOME\Work"; $s.Save()
  Start-Process $ahk -ArgumentList "`"$script`""
  ```

  Probar desde otro script AHK requiere `SendLevel(1)` antes de `Send("#{Enter}")`; sin eso AutoHotkey ignora teclas enviadas por otro script y parece que el atajo no funciona.

## 6. Verificación

- Prueba por agente, en `~/Work` y en `~/Work/<repo>`: `claude -p`, `codex exec`, `opencode run`, `pi --approve -p` con el prompt "List only the names of the skills available to you"; Gemini: `gemini skills list`.
- En `~/Work` → aparecen `asistente-personal` y `use-obsinotes`. En `~/Work/<repo>` → solo `use-obsinotes`.
- Ningún directorio global de la tabla 2 es carpeta real de una skill personal; `use-obsinotes` es enlace.
- `engram context` en `~/Work` muestra el proyecto `work`; en un repo, el nombre del repo.
- No existe `~/AGENTS.md`, `~/CLAUDE.md` ni `~/.atl`.
