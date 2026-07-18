---
name: cv-ats-harvard
description: "Convierte cualquier currículum (docx, pdf o texto) a un CV compatible con sistemas ATS usando el formato Harvard (una columna, viñetas, sin gráficos). Úsala siempre que el usuario mencione 'CV ATS', 'currículum formato Harvard', 'pasar mi CV a ATS', 'actualizar mi hoja de vida', o suba un CV con fotos/iconos/columnas para adaptarlo. También aplica cuando el usuario pida adaptar/tailorear un CV a una vacante específica, o cuando el CV de origen tenga certificados o logros como imágenes que deban convertirse en texto. No usar para redactar cartas de presentación ni para optimizar perfiles de LinkedIn."
---

# CV ATS — Formato Harvard

Convierte un CV existente (con cualquier diseño: dos columnas, foto, iconos, certificados como imagen) en un documento Word de una sola columna, formato Harvard, optimizado para sistemas ATS (Applicant Tracking System).

## Principio rector

**Compatibilidad ATS primero, estética después.** Todo lo que un ATS no pueda leer como texto plano (foto, ícono, tabla, columna, gráfico) se descarta o se convierte a texto. Si hay conflicto entre "se ve bonito" y "el ATS lo lee", gana el ATS.

## Flujo de trabajo

### 1. Leer el CV de origen
- Si es `.docx`: usar `python-docx` para extraer párrafos y tablas. Revisar `word/document.xml` (unzip) para detectar `<w:cols w:num="2">` (dos columnas) o `<w:tbl>` — son señales de diseño no-ATS que hay que aplanar.
- Si es `.pdf`: usar el skill `pdf-reading` para extraer texto e imágenes.
- Detectar imágenes incrustadas y clasificarlas por tamaño aproximado:
  - Imágenes grandes (>150px lado menor) cerca del encabezado → probablemente **foto de perfil**: nunca se incluye en la versión ATS.
  - Imágenes pequeñas (<50px) junto a datos de contacto → **iconos decorativos** (teléfono, correo, LinkedIn): se descartan, pero el dato de contacto que acompañan se conserva como texto.
  - Imágenes con texto dentro (diplomas, certificados, constancias) → **extraer el texto visible** (institución, nombre del curso, fecha) y agregarlo como viñeta en la sección Certificaciones. Nunca insertar la imagen en el docx final.

### 2. Detectar y señalar datos sensibles
Marcar (y por defecto omitir, salvo pedido explícito) estos datos si aparecen en el CV original: fecha de nacimiento/edad, DNI u otro documento de identidad, estado civil, fotografía. Explicar brevemente al usuario por qué se recomienda quitarlos (formato Harvard/ATS estándar no los incluye).

### 3. Deduplicar
Si el documento de origen tiene secciones repetidas (frecuente cuando el CV viene de un PDF mal convertido: "Referencias" duplicada, certificaciones listadas dos veces), consolidar en una sola instancia por sección.

### 4. Reordenar al esquema Harvard
Ver `references/harvard_sections.md` para el orden exacto y cómo redactar cada sección. Orden estándar:
1. Encabezado (nombre, ciudad/país, teléfono, correo, LinkedIn — todo en texto plano, nunca en header/footer de Word)
2. Perfil profesional (3-4 líneas)
3. Educación
4. Experiencia laboral (cronológico inverso, viñetas con verbo de acción + resultado cuantificable)
5. Proyectos relevantes (si aplica, especialmente en perfiles técnicos)
6. Habilidades (agrupadas: técnicas, herramientas, idiomas)
7. Certificaciones (texto: institución — curso — fecha)
8. Referencias (opcional, solo si el usuario quiere incluirlas o la vacante lo pide explícitamente)

### 5. Aplicar reglas duras ATS
Ver `references/ats_rules.md` antes de generar el documento final. Estas reglas son no negociables salvo instrucción explícita del usuario en sentido contrario.

### Notas de diseño (para que se vea "presentable", no solo válido)
- La plantilla Harvard original usa Times New Roman; el script la reemplaza por **Calibri** en los 4 estilos base — sigue siendo una fuente ATS-safe, pero se ve más moderna.
- Se agrega una **línea horizontal** (borde de párrafo nativo de Word, no una imagen ni tabla) bajo el bloque de contacto, y un **subtítulo de rol en cursiva** bajo el nombre (campo opcional `titulo_profesional`) — ninguno de los dos rompe la lectura ATS.
- Si el usuario sigue viendo el resultado "feo" después de esto, pedirle que señale **qué elemento puntual** no le gusta (¿tamaño de letra, espaciado entre secciones, negrita de los encabezados?) en vez de reintentar cambios a ciegas — no hay una skill de diseño visual que resuelva esto por adivinanza.

### 6. Generar el documento
Usar `scripts/build_resume.py`, que toma un JSON con los datos estructurados y produce un `.docx` reutilizando los estilos de `assets/harvard_template.docx` (Heading 1, Body Text, List Paragraph, Normal). No crear el documento desde cero con `docx-js`/estilos nuevos: partir siempre de la plantilla para heredar tipografía y formato Harvard correctos.

```bash
python scripts/build_resume.py --data datos.json --template assets/harvard_template.docx --out /mnt/user-data/outputs/CV_Nombre_ATS.docx
```

El JSON de entrada tiene esta forma (ver también `references/harvard_sections.md`):
```json
{
  "nombre": "Nombre Apellido",
  "titulo_profesional": "Ej: Backend Developer | AI Automation Engineer (opcional, cursiva bajo el nombre)",
  "contacto": "Ciudad, País • correo@ejemplo.com • +51 999 999 999 • linkedin.com/in/usuario",
  "perfil": "Párrafo de 3-4 líneas...",
  "educacion": [
    {"institucion": "...", "lugar": "...", "titulo": "...", "fecha": "..."}
  ],
  "experiencia": [
    {"empresa": "...", "lugar": "...", "cargo": "...", "fecha": "...",
     "logros": ["Viñeta con verbo de acción y resultado cuantificable", "..."]}
  ],
  "proyectos": [
    {"nombre": "...", "logros": ["..."]}
  ],
  "habilidades": [
    {"categoria": "Backend y desarrollo", "items": "Python, JavaScript, ..."}
  ],
  "certificaciones": [
    {"institucion": "...", "curso": "...", "fecha": "..."}
  ]
}
```

### 7. Verificar antes de entregar
Convertir el `.docx` a PDF/imagen (ver skill `docx`, sección "Verify the output") y revisar visualmente que:
- Sea una sola columna, sin tablas ni imágenes.
- Los encabezados de sección sean los estándar (no creativos).
- No haya texto en encabezado/pie de página con datos de contacto.

### 8. Si el usuario pide "también quiero la versión bonita para la entrevista"
Se puede ofrecer, aparte, una segunda versión con foto/diseño visual usando el skill `docx` normal — pero **siempre como archivo separado**, dejando explícito que esa versión no debe subirse a portales de empleo (Computrabajo, Bumeran, LinkedIn Easy Apply, etc.) porque no es ATS-friendly.

## Cuándo pedir información al usuario
- Si falta la vacante/puesto objetivo y el usuario quiere adaptar palabras clave: preguntar por el puesto o pegar el texto de la oferta.
- Si el CV trae datos sensibles (DNI, estado civil, edad): avisar que se omitirán por defecto y preguntar solo si el usuario insiste en conservarlos.
- No preguntar por el formato de salida (siempre `.docx`, formato Harvard) — eso ya está definido por esta skill.
