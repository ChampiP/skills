---
name: use-obsinotes
description: Use Brayan's Obsidian vault at ~/git-hub/ObsiNotes as a source of project/client context, or help organize it. Trigger this whenever Brayan is working in ANY repo/project and asks you to check "mi obsidian", "mi vault", or needs background/context on a client project (TBWA, Sellly, ANKA, corfid, Farma, Depilab, Emove, HPG, Nogalia, Tukompa) — meeting notes, decisions, and requirements usually live there even when you're not currently inside that folder. Also trigger for "organiza/limpia/ordena mi obsidian" or questions about how the vault, its plugins, or its automations work. Do NOT assume which vault "mi obsidian" means if it could also refer to ~/git-hub/Obsidian_coorpi (a separate personal-assistant memory vault) — ask if unclear.
---

# Usar / organizar ObsiNotes

`~/git-hub/ObsiNotes` es el vault de Obsidian de Brayan: contexto de proyectos de
cliente (Holinsys), proyectos personales y aprendizaje técnico. El vault tiene su
propio `AGENTS.md` en la raíz — **léelo primero**, ahí está la estructura completa,
el mapeo proyecto→cliente, las automatizaciones y las reglas de organización. Este
SKILL.md es solo el gancho para que Claude Code lo recuerde desde cualquier sesión;
no dupliques ahí — mantenlo a `~/git-hub/ObsiNotes/AGENTS.md` como fuente de verdad.

## Vault hermano — desambiguar antes de actuar

También existe `~/git-hub/Obsidian_coorpi` (memoria del asistente personal
"Coorpi" de Brayan, con su propio `AGENTS.md` y protocolos). Es un sistema
deliberadamente separado. Si Brayan dice "revisa mi obsidian" sin más contexto
y no es obvio cuál de los dos vaults necesita, **pregunta**. Pista: mencionar
un cliente/proyecto (TBWA, Sellly, ANKA, corfid, Farma, etc.) casi siempre
apunta a ObsiNotes; mencionar algo personal/memoria/preferencias suele ser
Coorpi. Está bien leer o guardar en Coorpi si Brayan lo pide — no es territorio
prohibido, solo un sistema distinto con sus propias reglas.

## Caso 1: te piden contexto de un proyecto/cliente desde OTRO repo

Ejemplo: Brayan está en el código de TBWA y dice "revisa mi obsidian, ahí está
el contexto de este proyecto".

1. Ve a `~/git-hub/ObsiNotes/AGENTS.md`, sección "Mapeo proyecto → cliente"
   para ubicar la carpeta correcta en `02_Areas/Holinsys/01_Projects/<Proyecto>/`
   (o `02_Areas/Personal/<Área>/` si es personal).
2. Lee la nota-hub `<Proyecto>.md` y sus notas enlazadas.
3. Busca reuniones relevantes en `01_Inbox/Reuniones/(Proyecto) *.md` — las
   reuniones no viven en la carpeta del proyecto, se quedan en Inbox con el
   proyecto marcado en el nombre y en el frontmatter `proyecto:`.
4. **Sintetiza** lo relevante a la tarea actual — no pegues notas completas ni
   transcripciones enteras en la respuesta.

## Caso 2: te piden organizar/limpiar el vault

Sigue el procedimiento de la sección "Cómo se organiza" en
`~/git-hub/ObsiNotes/AGENTS.md`. Resumen de los puntos que no son obvios:

- Reuniones "(Sin clasificar)": clasifica comparando participantes/tema contra
  proyectos existentes, no muevas de carpeta, solo renombra + actualiza
  frontmatter.
- Notas "(Notion)" duplicadas o con `#` pegado al nombre: son artefactos del
  script de migración de Notion — revisa contenido único antes de fusionar y
  borrar, usa wikilinks.
- `vault/` (adjuntos) es intencionalmente plano — no lo subdividas en
  subcarpetas. Solo detecta huérfanos y pregunta qué hacer con ellos.
- Links rotos en `03_Learning` casi siempre son intencionales (conceptos
  futuros sin nota propia todavía) — no los "arregles". Los de otras carpetas
  sí suelen ser errores reales; si el arreglo requiere adivinar contenido,
  pregunta primero.

## Seguridad

`migrate_notion_projects.py` y `migrate_notion_phase2.py` tienen un
`NOTION_TOKEN` hardcodeado — no tocar ni rotar sin pedido explícito de Brayan.
Otros scripts (`auto_kanban.py`, `auto_transcribe.py`, `auto_notion_sync.py`)
también tienen claves hardcodeadas (Groq/Notion) — se pueden ejecutar
normalmente, solo no las edites, muevas ni las expongas en otro lado.
