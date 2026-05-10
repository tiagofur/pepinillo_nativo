# Pepinillo Android: Strict TDD Standard

Este documento establece el estándar de calidad y testing para el desarrollo de la aplicación Android de Pepinillo. El objetivo es garantizar que cada nueva funcionalidad sea robusta, verificable y libre de regresiones.

## 1. Principios Core

*   **Test-First (siempre que sea posible):** Escribir el test antes de la implementación para definir el comportamiento esperado.
*   **100% Cobertura de Lógica de Negocio:** Todos los ViewModels, Repositorios, Use Cases y Motores (como `FocusEngine`) deben tener tests unitarios exhaustivos.
*   **Verificación de UI:** Los componentes de Compose deben ser verificados mediante tests de UI o Screenshot testing para asegurar consistencia visual y accesibilidad.
*   **Cero Warnings:** El código no debe compilarse con warnings de testing o corrutinas.

## 2. Tecnologías y Herramientas

*   **Testing Framework:** JUnit 4.
*   **Mocking:** MockK (preferir `relaxed = true` solo cuando el comportamiento no sea crítico para el test).
*   **Corrutinas:** `kotlinx-coroutines-test`. Uso obligatorio de `runTest` y `TestDispatcher`.
*   **Flows:** Turbine (para verificar emisiones de StateFlow y SharedFlow).
*   **Networking:** Ktor Mock Engine para simular respuestas del servidor en tests de repositorios.
*   **Database:** Room in-memory database para tests de integración de DAOs.

## 3. Estructura de los Tests

Todos los tests deben seguir el patrón **Arrange-Act-Assert** (o Given-When-Then):

```kotlin
@Test
fun `nombre descriptivo de la accion y el resultado esperado`() = runTest {
    // Arrange: Configuración de mocks y estado inicial
    
    // Act: Ejecución de la acción bajo prueba
    
    // Assert: Verificación de resultados y llamadas a mocks
}
```

## 4. Requisitos por Capa

### ViewModels
*   Verificar todos los cambios en el `UiState`.
*   Verificar que se disparen los eventos únicos (SharedFlow) como errores o navegaciones.
*   Verificar que se llamen a los métodos correctos de los repositorios.

### Repositorios / SyncEngine
*   Verificar el manejo de errores de red (401, 500, timeouts).
*   Verificar que los datos se guarden correctamente en la base de datos local tras una sincronización.

### UI / Composable
*   Verificar que los elementos críticos sean visibles.
*   Verificar las interacciones básicas (clicks, scrolls).
*   Verificar el estado visual (ej. si una tarea está completada, debe mostrarse tachada).

## 5. Automatización

*   Los tests se ejecutan automáticamente en cada PR a través de GitHub Actions.
*   Ninguna tarea se considera "Terminada" (Done) sin sus correspondientes tests unitarios aprobados.
