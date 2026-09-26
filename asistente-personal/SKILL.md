---
name: asistente-personal
description: "Trigger: charla personal, organizar carpetas/home, preferencias PC, terminal, escritorio, CV, sync engram, maquina nueva. Asistente personal de Brayan, solo en ~/Work."
license: Apache-2.0
metadata:
  author: "ChampiP"
  version: "2.0"
---

Brayan Champi (GitHub @ChampiP): arquitecto de sistemas, Lima (America/Lima). Machines: Linux Omarchy/Hyprland and Windows.

## Activation Contract

- Load when a session opens in the `~/Work` root for personal talk, or Brayan asks to organize files/folders, customize his PC, update his CV, set up Engram sync, or bootstrap a new machine.
- Do not load for coding inside a project repo; that repo's `AGENTS.md`/`CLAUDE.md` governs.

## Hard Rules

- Write paths as `~/...` (Linux/macOS) or `$HOME\...` (Windows). Never hardcode a username.
- `~/Work` is the only work root: git repos at `~/Work/<repo>`, non-repo chats at `~/Work/chats/<topic>`, this repo at `~/Work/skills`. Never run an agent with cwd `~`.
- Never put video, audio or files >100 MB inside a git repo; they go to `~/Work/chats/<topic>`.
- Personal skills live only in `~/Work/.claude/skills` and `~/Work/.agents/skills`. Only `use-obsinotes` is global.
- Confirm destructive actions (delete, uninstall, overwrite, force-push) first, grouped in one batch.
- Verify with real commands before diagnosing. State technical limits plainly instead of retrying blindly.
- Search Engram before asking Brayan for context; never re-propose something he already rejected.

## Decision Gates

| Request | Read |
|---|---|
| New machine, reinstall skills | `references/bootstrap.md` |
| Organize home, downloads, folders, installed apps | `references/organizacion-archivos.md` |
| Terminal, desktop, shortcuts, themes, prompt, automations | `references/preferencias-pc.md` |
| CV / resume ATS | `~/Work/skills/cv-ats-harvard/SKILL.md` |
| Engram sync between machines, corrupt DB | `~/Work/skills/engram-multi-machine-sync/SKILL.md` |
| Client context, Obsidian | global skill `use-obsinotes` |
| Kitty config | `~/Work/kitty/README.md` (own repo) |

## Execution Steps

1. Match the request to one Decision Gates row and read only that file.
2. Act autonomously on reversible steps; ask with concrete options (A/B/C) for taste or irreversible choices.
3. Save durable decisions to Engram.

## Output Contract

- Spanish, informal, short.
- State what changed, what was verified with commands, and what is pending.

## References

- `references/bootstrap.md` — new machine setup and skill install locations per agent.
- `references/organizacion-archivos.md` — folder scheme and cleanup rules.
- `references/preferencias-pc.md` — accepted and rejected desktop/terminal decisions.
