---
tags:
  - view
  - estado
  - pepinillo
aliases:
  - Estado General
platform: all
type: view
status: active
date: 2026-04-17
updated: 2026-04-17
---

# 📊 Estado General del Vault

> [!tip] Requiere el plugin **Dataview**
> Instalalo desde *Settings → Community plugins → Browse → Dataview*.
> Las queries debajo se renderizan automáticamente con el plugin activo.

---

## Todos los documentos por plataforma y estado

```dataview
TABLE WITHOUT ID
  file.link AS "📄 Documento",
  platform AS "Plataforma",
  type AS "Tipo",
  status AS "Estado",
  updated AS "Actualizado"
FROM "Pepinillo"
WHERE file.name != "README" AND type != "view"
SORT platform ASC, type ASC, file.name ASC
```

---

## Documentos activos por plataforma

### 🍎 iOS

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  type AS "Tipo",
  status AS "Estado"
FROM "Pepinillo"
WHERE platform = "ios"
SORT type ASC
```

### 🤖 Android

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  type AS "Tipo",
  status AS "Estado"
FROM "Pepinillo"
WHERE platform = "android"
SORT type ASC
```

### ⚙️ Backend

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  type AS "Tipo",
  status AS "Estado"
FROM "Pepinillo"
WHERE platform = "backend"
SORT type ASC
```

### 🔀 Cross-Platform

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  type AS "Tipo",
  status AS "Estado"
FROM "Pepinillo"
WHERE platform = "cross-platform"
SORT type ASC
```

---

## Documentos por tipo

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  platform AS "Plataforma",
  status AS "Estado"
FROM "Pepinillo"
WHERE file.name != "README" AND type != "view"
GROUP BY type
SORT platform ASC
```

---

## Documentos modificados recientemente

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  platform AS "Plataforma",
  updated AS "Actualizado"
FROM "Pepinillo"
WHERE file.name != "README"
SORT updated DESC
LIMIT 10
```
