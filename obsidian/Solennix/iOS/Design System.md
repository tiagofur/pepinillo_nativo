#ios #design #ui #tema

# Design System

> [!abstract] Resumen
> Paquete **SolennixDesign** con 100+ tokens de color para light/dark mode, tipografía custom (Cinzel + system), spacing, shadows, gradientes, y 11 componentes reutilizables. Paleta cálida dorado + navy.

---

## Paleta de Colores

### Brand

| Token | Light | Dark | Uso |
|-------|-------|------|-----|
| `primary` | `#C4A265` | `#C4A265` | Acciones principales, marca |
| `primaryDark` | `#A3854E` | `#D4B87A` | Variante para contraste |
| `primaryLight` | `#D4B87A` | `#A3854E` | Variante sutil |

### Texto

| Token | Light | Dark | Uso |
|-------|-------|------|-----|
| `text` | Oscuro | Claro | Texto principal |
| `textSecondary` | Gris medio | Gris claro | Texto secundario |
| `textTertiary` | Gris suave | Gris medio | Texto terciario |
| `textInverse` | Blanco | Negro | Sobre fondos colored |

### Superficies

| Token | Light | Dark | Uso |
|-------|-------|------|-----|
| `background` | Crema cálido | Negro | Fondo principal |
| `surface` | Blanco | Gris muy oscuro | Cards, modales |
| `surfaceGrouped` | Gris cálido | Negro | Fondos agrupados |
| `surfaceAlt` | Beige | Navy oscuro | Fondos alternativos |
| `card` | Blanco | Gris oscuro | Cards elevadas |

### Status

| Estado | Color | Uso |
|--------|-------|-----|
| `statusQuoted` | Naranja `#D97706` | + fondo suave |
| `statusConfirmed` | Azul `#007AFF` | + fondo suave |
| `statusCompleted` | Verde `#2D6A4F` | + fondo suave |
| `statusCancelled` | Rojo `#FF3B30` | + fondo suave |

### KPIs

| Token | Color |
|-------|-------|
| `kpiGreen` | `#34C759` + fondo |
| `kpiOrange` | `#D97706` + fondo |
| `kpiBlue` | `#007AFF` + fondo |

### Semánticos

| Token | Color | Uso |
|-------|-------|-----|
| `success` | Verde | + fondo |
| `warning` | Naranja | + fondo |
| `error` | Rojo | + fondo |
| `info` | Azul | + fondo |

### Tab Bar

| Token | Uso |
|-------|-----|
| `tabBarBackground` | Fondo del tab bar |
| `tabBarActive` | Tab seleccionado |
| `tabBarInactive` | Tab inactivo |
| `tabBarBorder` | Borde superior |

### Avatar Palette

8 colores predefinidos para avatares generados por hash del nombre.

---

## Tipografía

| Style | Font | Size | Weight | Uso |
|-------|------|------|--------|-----|
| `h1Premium` | System | 28pt | Black | Títulos premium |
| `solennixTitle` | Cinzel | 32pt | SemiBold | Marca, splash |
| `solennixSubtitle` | Cinzel | 24pt | Regular | Subtítulos de marca |
| System styles | SF Pro | Varies | Varies | Body, headlines, captions |

> [!tip] Tracking Modifier
> `.tracking()` custom modifier para ajustar letter-spacing en textos decorativos.

---

## Spacing

| Token | Valor | Uso |
|-------|-------|-----|
| `xs` | 4pt | Gaps mínimos |
| `s` | 8pt | Padding interno |
| `m` | 16pt | Padding estándar |
| `l` | 24pt | Separación de secciones |
| `xl` | 32pt | Separación mayor |

---

## Shadows

Profundidades predefinidas para elevación visual:

| Nivel | Uso |
|-------|-----|
| Sutil | Cards en superficie |
| Medio | Cards elevadas |
| Fuerte | Modales, dropdowns |

---

## Implementación de Colores

```swift
public enum SolennixColors {
    public static let primary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#C4A265")
            : UIColor(hex: "#C4A265")
    })

    public static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: "#000000")
            : UIColor(hex: "#F5F4F1")
    })
    // ... 100+ más
}
```

> [!important] UIColor Adaptive
> Todos los colores usan `UIColor { traits in }` para soportar light/dark mode dinámicamente. NO usan Asset Catalog.

---

## Anti-Patrones

> [!danger] Prohibido
> - Gradientes cyan/purple estilo "AI"
> - Glassmorphism decorativo sin propósito
> - Grids genéricos de ícono+heading+text
> - Estética fría de enterprise SaaS
> - Usar colores de status para decoración
> - Colores hardcoded fuera de `SolennixColors`

---

## Archivos Clave

| Archivo | Ubicación |
|---------|-----------|
| `Colors.swift` | `SolennixDesign/` |
| `Typography.swift` | `SolennixDesign/` |
| `Spacing.swift` | `SolennixDesign/` |
| `Shadows.swift` | `SolennixDesign/` |
| `Gradient.swift` | `SolennixDesign/` |

---

## Relaciones

- [[Componentes Compartidos]] — componentes que usan estos tokens
- [[Arquitectura General]] — paquete SolennixDesign
- [[Módulo Settings]] — no hay selector de tema manual (sigue sistema)
