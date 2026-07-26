# Implementation Plan: Android Visual Identity & Polish (#516, #517, #519, #520)

Este plan aborda la identidad visual premium de la aplicación, limpieza de código y mejoras de accesibilidad en la pantalla principal.

## Proposed Changes

### [Theme & Identity]

#### [MODIFY] [Type.kt](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/src/main/java/dev/creapolis/pepinillo/ui/theme/Type.kt)
- **#516**: Introducir una fuente premium (Montserrat o similar via Google Fonts) para los estilos `display` y `headline`. Esto dará una identidad de marca más fuerte y profesional al cronómetro y títulos.
- Mantener fuentes del sistema para `body` y `label` para asegurar legibilidad y accesibilidad.

#### [DELETE] [GlassComponents.kt](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/src/main/java/dev/creapolis/pepinillo/ui/components/GlassComponents.kt)
- **#519**: Eliminar este archivo ya que no se utiliza en ninguna parte del proyecto y previene la proliferación de efectos visuales inconsistentes ("glassmorphism sprawl").

### [Focus Screen UX]

#### [MODIFY] [ModeCard.kt](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/src/main/java/dev/creapolis/pepinillo/feature/focus/components/ModeCard.kt)
- **#520**: Aumentar el tamaño de la fuente de las etiquetas de modo de `10.sp` a `12.sp`.
- Mejorar los targets de toque y la legibilidad para baja visión.

#### [MODIFY] [FocusScreen.kt](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/src/main/java/dev/creapolis/pepinillo/feature/focus/FocusScreen.kt)
- **#520**: Cambiar la disposición de los chips de modo de una sola fila (`Row`) a un grid de 2x2. Esto evitará que se vean amontonados en pantallas pequeñas y mejorará la escaneabilidad.
- **#517**: Refinar las animaciones usando tokens de movimiento centralizados (MotionScheme) si están disponibles, o estandarizar los `spring` existentes.

### [Build & Dependencies]

#### [MODIFY] [build.gradle (app)](file:///Users/tiagofur/dev/pepinillo_nativo/android/app/build.gradle)
- Añadir la dependencia `androidx.compose.ui:ui-text-google-fonts` para implementar la tipografía de marca de forma eficiente.

## Verification Plan

### Automated Tests
- Verificar la compilación del proyecto.
- Ejecutar tests de UI si existen para asegurar que el cambio de layout en `FocusScreen` no rompe interacciones.

### Manual Verification
- **Tipografía**: Confirmar que los números del cronómetro se ven con la nueva fuente Montserrat.
- **Accesibilidad**: Verificar con TalkBack que los chips de modo son fáciles de seleccionar.
- **Layout**: Probar en un dispositivo con pantalla pequeña (o modo split screen) que el grid 2x2 se adapta correctamente.
