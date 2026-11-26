# Clean-Context Review Bundle — Issue #990

> **Context Isolation Notice**: This packet is generated deterministically from git state.
> Do NOT read the implementer's conversation history. Evaluate strictly against the
> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.

## Pinned Identity
- **Issue**: `#990`
- **Base SHA**: `5c1255225c2bbc3492cd4aa68ef77c0fee787117`
- **Head SHA**: `53aa46e76effb615eeb6702af15405ffe20807aa`
- **Scope Digest (SHA-256)**: `693d559e1c66b187032250d8a4359f5818c3cdbdd994ac2de3334d2dc4ac2d71`
- **Changed Lines**: `686` (review budget: 400)
- **Blind Dual Review (`judgment-day`) Required**: `True`

## High-Risk Triggers
- `sensitive-surface:contracts/fixtures/energy-hours-989.json`
- `size-exception:686 changed lines > 400`

## Acceptance Criteria (source: `task:odd/tasks/990-actionable-energy.md`)
# odd/tasks/990-actionable-energy.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/990 (status:approved + GO de Tiago)
Topología: Delegated Direct · Único escritor: implementador de esta sesión
Base: main 5c125522 · Rama: feat/990-actionable-energy (worktree pepinillo-wt-990)

## Specs (S1..Sn de la issue)
- **S1** tabla 24h compartida → `contracts/fixtures/energy-hours-989.json`; suites iOS/web/Android la afirman (macOS comparte el motor iOS). ✓
- **S2** sugerencia visible en «Hoy» sin agrupado en iOS/macOS/Android/web; descarte por sesión. ✓
- **S3** sin candidatos → no se muestra. ✓
- **S4** tap → filtra; «Mostrar todo»/segundo tap quita. ✓
- **S5** arranque por las acciones existentes (startFocusOnTask / inspector web). ✓ (sin nuevo camino)
- **S6** gratis, sin cambios en el tope Free. ✓
- **S7** accesibilidad + `## Visual Evidence` en el PR (en curso).

## Allowed edit surfaces
- `contracts/fixtures/energy-hours-989.json` (nuevo)
- `ios/Features/Tasks/EnergySuggestionPrompt.swift` (nuevo) · `TaskListFeature.swift` · `PlanTaskList.swift`
- `ios/Mac/MacPlanView.swift` · `ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift`
- `android/.../domain/tasks/EnergySuggestion.kt` + test (nuevos) · `feature/tasks/TasksScreen.kt` · res strings ×3
- `web/src/routes/(app)/plan/+page.svelte` · `src/lib/i18n/messages.ts` · `tests/unit/energy.test.ts` (nuevo)

## Tasks
- **T1** (S1): fixture + tests 4 plataformas. RED: Android sin motor (compile fail) → GREEN. ✓
- **T2** (S2-S4-S3 Apple): prompt compartido + acciones + enrutado por píldora. ✓
- **T3** (S2-S4 Android): chip + wiring del ViewModel existente + strings ×3. ✓
- **T4** (S2-S4 web): pill + filtro + i18n ×3 (+ quita el hint viejo gateado a free). ✓
- **T5** (S7 + handoff + jueces + PR): en curso

## Log
- 26-nov: brief UX publicado como comentario (ux:shape) antes de implementar.
- Nota entorno: el scheme PepinilloMac NO compila en este entorno por ActivityKit/27.3 (preexistente, verificado con stash — falla idéntico en main limpio); validación Mac = swiftc -parse + Visual Evidence/QA humano.

## Allowed Edit Surfaces
- `contracts/fixtures/energy-hours-989.json`
- `ios/Features/Tasks/EnergySuggestionPrompt.swift`
- `TaskListFeature.swift`
- `PlanTaskList.swift`
- `ios/Mac/MacPlanView.swift`
- `ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift`
- `android/.../domain/tasks/EnergySuggestion.kt`
- `feature/tasks/TasksScreen.kt`
- `web/src/routes/(app)/plan/+page.svelte`
- `src/lib/i18n/messages.ts`
- `tests/unit/energy.test.ts`

## Files Outside Allowed Edit Surfaces
- ⚠️ `android/app/src/main/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestion.kt`
- ⚠️ `android/app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt`
- ⚠️ `android/app/src/main/res/values-es/strings.xml`
- ⚠️ `android/app/src/main/res/values-pt/strings.xml`
- ⚠️ `android/app/src/main/res/values/strings.xml`
- ⚠️ `android/app/src/test/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestionTest.kt`
- ⚠️ `docs/evidence/990/web-today-filter-active.png`
- ⚠️ `docs/evidence/990/web-today-s3-no-candidates.png`
- ⚠️ `docs/evidence/990/web-today-show-all.png`
- ⚠️ `docs/evidence/990/web-today-suggestion-visible.png`
- ⚠️ `ios/Features/Plan/PlanTaskList.swift`
- ⚠️ `ios/Features/Tasks/TaskListFeature.swift`
- ⚠️ `odd/tasks/990-actionable-energy.md`
- ⚠️ `web/src/lib/i18n/messages.ts`
- ⚠️ `web/tests/unit/energy.test.ts`

## Observed Verification Evidence (V0/V1/V2)
```text
# Verification Evidence — issue #990 (feat/990-actionable-energy)

Fecha: 2026-11-26 · Worktree: /Users/tiagofur/dev/pepinillo-wt-990 · Base: main 5c125522

## S1 — tabla compartida (4 plataformas)
1. Fixture contracts/fixtures/energy-hours-989.json (24 horas).
2. iOS: `xcodebuild -scheme "Pepinillo Dev" -destination 'id=80547AB1-…'
   -only-testing:PepinilloTests/EnergySuggestionTests -only-testing:PepinilloTests/TaskListFeatureTests test`
   → TEST SUCCEEDED (matchesSharedFixtureTable + regresión TaskListFeature).
3. Web: `pnpm test` → 144/144 (energy.test.ts contra el fixture).
4. Android: EnergySuggestionTest contra el fixture → BUILD SUCCESSFUL
   (RED observado primero: EnergySuggestion inexistente).

## S2-S4 — plataformas
5. iOS subset arriba (TaskListFeature incluye los 2 acciones nuevas).
6. Android: `./gradlew :app:testDebugUnitTest --tests "dev.creapolis.pepinillo.*"`
   → BUILD SUCCESSFUL (compila chip + engine; suite CI corre el targeted set).
7. Web: `pnpm test` 144 ✓ + `pnpm check` 0 errores.
8. macOS: el scheme PepinilloMac NO compila en este entorno por ActivityKit
   (Xcode 27.2 vs ActivityKit-Mac 27.3) — PREEXISTENTE verificado con stash
   (falla idéntico en main limpio: LiveActivityManager.swift:119). MacPlanView
   + EnergySuggestionPrompt validados con swiftc -parse; QA visual humano al
   merge (Visual Evidence abajo).

## Factoría
9. `make test` (guardrails + backend) → OK. Backend sin cambios.

## Visual Evidence (S7)
- Web: capturas adjuntas al PR (pill inactiva y filtro activo sobre /plan).
- iOS/Android/macOS: pendiente de captura automatizada — el diff usa la
  anatomía existente del banner (iOS) y componentes nativos estándar
  (FilterChip Android, pill web); QA humano de Tiago al merge según
  qa-recipe (incluye Dynamic Type/hit targets).

Risk: item 3 (superficies Plan en 4 plataformas; paridad funcional con el
vocabulario existente y sin cambios de datos)
```

## Changed Files
- `android/app/src/main/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestion.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt`
- `android/app/src/main/res/values-es/strings.xml`
- `android/app/src/main/res/values-pt/strings.xml`
- `android/app/src/main/res/values/strings.xml`
- `android/app/src/test/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestionTest.kt`
- `contracts/fixtures/energy-hours-989.json`
- `docs/evidence/990/web-today-filter-active.png`
- `docs/evidence/990/web-today-s3-no-candidates.png`
- `docs/evidence/990/web-today-show-all.png`
- `docs/evidence/990/web-today-suggestion-visible.png`
- `ios/Features/Plan/PlanTaskList.swift`
- `ios/Features/Tasks/EnergySuggestionPrompt.swift`
- `ios/Features/Tasks/TaskListFeature.swift`
- `ios/Mac/MacPlanView.swift`
- `ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift`
- `odd/tasks/990-actionable-energy.md`
- `web/src/lib/i18n/messages.ts`
- `web/src/routes/(app)/plan/+page.svelte`
- `web/tests/unit/energy.test.ts`

## Diff Stat
```text
.../pepinillo/domain/tasks/EnergySuggestion.kt     |  23 +++
 .../pepinillo/feature/tasks/TasksScreen.kt         |  60 +++++++-
 android/app/src/main/res/values-es/strings.xml     |   2 +
 android/app/src/main/res/values-pt/strings.xml     |   2 +
 android/app/src/main/res/values/strings.xml        |   2 +
 .../pepinillo/domain/tasks/EnergySuggestionTest.kt |  35 +++++
 contracts/fixtures/energy-hours-989.json           | 101 +++++++++++++
 docs/evidence/990/web-today-filter-active.png      | Bin 0 -> 60416 bytes
 docs/evidence/990/web-today-s3-no-candidates.png   | Bin 0 -> 71634 bytes
 docs/evidence/990/web-today-show-all.png           | Bin 0 -> 77860 bytes
 docs/evidence/990/web-today-suggestion-visible.png | Bin 0 -> 77911 bytes
 ios/Features/Plan/PlanTaskList.swift               |  58 +++++++-
 ios/Features/Tasks/EnergySuggestionPrompt.swift    | 159 +++++++++++++++++++++
 ios/Features/Tasks/TaskListFeature.swift           |  16 +++
 ios/Mac/MacPlanView.swift                          |  29 +++-
 .../TaskFeatureTests/EnergySuggestionTests.swift   |  31 ++++
 odd/tasks/990-actionable-energy.md                 |  32 +++++
 web/src/lib/i18n/messages.ts                       |  20 +++
 web/src/routes/(app)/plan/+page.svelte             |  90 ++++++++++--
 web/tests/unit/energy.test.ts                      |  26 ++++
 20 files changed, 673 insertions(+), 13 deletions(-)
```

## Full Diff
```diff
diff --git a/android/app/src/main/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestion.kt b/android/app/src/main/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestion.kt
new file mode 100644
index 00000000..0df48a39
--- /dev/null
+++ b/android/app/src/main/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestion.kt
@@ -0,0 +1,23 @@
+package dev.creapolis.pepinillo.domain.tasks
+
+import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
+
+/**
+ * Issue #990 (S1): hour → energy engine. The table is mirrored from
+ * contracts/fixtures/energy-hours-989.json (the single source of truth —
+ * this suite and the web/iOS suites all assert against it). Canonical
+ * levels map onto Android's UI labels: deep→Deep, shallow→Light,
+ * admin→Regular.
+ *
+ * 06–10 deep · 11–12 shallow · 13–14 admin · 15–17 deep · 18–20 shallow · 21–05 admin
+ */
+object EnergySuggestion {
+    fun suggestedLevel(hour: Int): EnergyLevel = when (hour) {
+        in 6..10 -> EnergyLevel.Deep
+        in 11..12 -> EnergyLevel.Light
+        in 13..14 -> EnergyLevel.Regular
+        in 15..17 -> EnergyLevel.Deep
+        in 18..20 -> EnergyLevel.Light
+        else -> EnergyLevel.Regular
+    }
+}
diff --git a/android/app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt b/android/app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt
index ac5609dc..3d833147 100644
--- a/android/app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt
+++ b/android/app/src/main/java/dev/creapolis/pepinillo/feature/tasks/TasksScreen.kt
@@ -91,6 +91,10 @@ import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens
 import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled
 import dev.creapolis.pepinillo.ui.theme.MotionScheme
 import kotlinx.coroutines.delay
+import androidx.compose.material3.SuggestionChip
+import androidx.compose.material3.SuggestionChipDefaults
+import dev.creapolis.pepinillo.domain.tasks.EnergySuggestion
+import java.time.LocalTime
 
 @OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
 @Composable
@@ -204,7 +208,54 @@ fun TasksScreen(
                 }
             }
 
-            Spacer(modifier = Modifier.height(16.dp))
+            Spacer(modifier = Modifier.height(12.dp))
+
+            // ── 2b. ENERGY SUGGESTION CHIP (issue #990) ──
+            // Only on "Today" (S2): suggests the level for the current hour
+            // (S1), hides when no candidate tasks exist (S3), tapping filters
+            // (S4) and tapping again clears it. Rows keep their start-focus.
+            if (uiState.selectedFilter == TaskFilter.Today) {
+                val suggested = EnergySuggestion.suggestedLevel(LocalTime.now().hour)
+                val hasCandidates = uiState.tasks.any {
+                    !it.isCompleted && it.scheduledForToday && it.energyLevel == suggested
+                }
+                val isSelected = uiState.energyFilter == suggested
+                val visible = hasCandidates || (uiState.energyFilter != null && isSelected)
+                if (visible) {
+                    Row(
+                        modifier = Modifier.fillMaxWidth(),
+                        horizontalArrangement = Arrangement.spacedBy(8.dp),
+                        verticalAlignment = Alignment.CenterVertically,
+                    ) {
+                        SuggestionChip(
+                            onClick = {
+                                viewModel.selectEnergyFilter(if (isSelected) null else suggested)
+                            },
+                            label = {
+                                Text(
+                                    stringResource(R.string.energy_suggestion_chip, suggested.label),
+                                    style = MaterialTheme.typography.labelLarge,
+                                )
+                            },
+                            icon = { Text(suggested.suggestionEmoji()) },
+                            colors = SuggestionChipDefaults.suggestionChipColors(
+                                containerColor = if (isSelected)
+                                    MaterialTheme.colorScheme.primaryContainer
+                                else
+                                    MaterialTheme.colorScheme.surfaceVariant,
+                            ),
+                        )
+                        if (uiState.energyFilter != null) {
+                            TextButton(onClick = { viewModel.selectEnergyFilter(null) }) {
+                                Text(stringResource(R.string.energy_show_all))
+                            }
+                        }
+                    }
+                    Spacer(modifier = Modifier.height(8.dp))
+                }
+            }
+
+            Spacer(modifier = Modifier.height(4.dp))
 
             // ── 3. TASK LIST ──
             if (filteredTasks.isEmpty() && !uiState.isLoading) {
@@ -670,3 +721,10 @@ private fun TaskFilter.accentColor(): Color = when (this) {
     TaskFilter.Upcoming -> DomainColors.FilterUpcoming
     TaskFilter.Completed -> DomainColors.Positive
 }
+
+/** Issue #990: emoji del nivel para el chip de sugerencia (espejo del widget). */
+private fun dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.suggestionEmoji(): String = when (this) {
+    dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Deep -> "\uD83D\uDD25"
+    dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Light -> "\uD83D\uDCA7"
+    dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Regular -> "\u26A1"
+}
diff --git a/android/app/src/main/res/values-es/strings.xml b/android/app/src/main/res/values-es/strings.xml
index 6c0af122..04d37be1 100644
--- a/android/app/src/main/res/values-es/strings.xml
+++ b/android/app/src/main/res/values-es/strings.xml
@@ -924,4 +924,6 @@
     <string name="rc_link_success_title">¡Compra vinculada!</string>
     <string name="rc_link_success_body">Vinculada a %1$s. Tu plan ya está disponible en la web.</string>
     <string name="rc_link_btn_continue">Continuar</string>
+    <string name="energy_suggestion_chip">Sugerido ahora: %1$s</string>
+    <string name="energy_show_all">Mostrar todo</string>
 </resources>
diff --git a/android/app/src/main/res/values-pt/strings.xml b/android/app/src/main/res/values-pt/strings.xml
index 542fb0a5..3e0854cd 100644
--- a/android/app/src/main/res/values-pt/strings.xml
+++ b/android/app/src/main/res/values-pt/strings.xml
@@ -931,4 +931,6 @@
     <string name="rc_link_success_title">Compra vinculada!</string>
     <string name="rc_link_success_body">Vinculada a %1$s. Seu plano já está disponível na web.</string>
     <string name="rc_link_btn_continue">Continuar</string>
+    <string name="energy_suggestion_chip">Sugerido agora: %1$s</string>
+    <string name="energy_show_all">Mostrar tudo</string>
 </resources>
diff --git a/android/app/src/main/res/values/strings.xml b/android/app/src/main/res/values/strings.xml
index 9ae66ed5..58615820 100644
--- a/android/app/src/main/res/values/strings.xml
+++ b/android/app/src/main/res/values/strings.xml
@@ -922,4 +922,6 @@
     <string name="rc_link_success_title">Purchase linked!</string>
     <string name="rc_link_success_body">Linked to %1$s. Your plan is now available on the web.</string>
     <string name="rc_link_btn_continue">Continue</string>
+    <string name="energy_suggestion_chip">Suggested now: %1$s</string>
+    <string name="energy_show_all">Show all</string>
 </resources>
diff --git a/android/app/src/test/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestionTest.kt b/android/app/src/test/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestionTest.kt
new file mode 100644
index 00000000..414637b3
--- /dev/null
+++ b/android/app/src/test/java/dev/creapolis/pepinillo/domain/tasks/EnergySuggestionTest.kt
@@ -0,0 +1,35 @@
+package dev.creapolis.pepinillo.domain.tasks
+
+import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
+import org.junit.Assert.assertEquals
+import org.junit.Assert.assertTrue
+import org.junit.Test
+import java.nio.file.Files
+import java.nio.file.Paths
+
+/**
+ * Issue #990 (S1): every platform asserts its hour → energy engine against
+ * the same 24-hour fixture versioned in the repo (contracts/fixtures).
+ */
+class EnergySuggestionTest {
+
+    @Test
+    fun `suggestEnergy matches the shared 24-hour fixture table`() {
+        val repoRoot = Paths.get(System.getProperty("user.dir"), "..", "..").normalize()
+        val fixture = repoRoot.resolve("contracts").resolve("fixtures").resolve("energy-hours-989.json")
+        assertTrue("fixture must exist: $fixture", Files.exists(fixture))
+        val json = Files.readString(fixture)
+        val entries = Regex("\"hour\"\\s*:\\s*(\\d+)").findAll(json).map { it.groupValues[1].toInt() }.toList()
+        val levels = Regex("\"level\"\\s*:\\s*\"(\\w+)\"").findAll(json).map { it.groupValues[1] }.toList()
+        assertEquals(24, entries.size)
+        entries.zip(levels).forEach { (hour, level) ->
+            // canonical vocabulary (deep/shallow/admin) → Android labels
+            val expected = when (level) {
+                "deep" -> EnergyLevel.Deep
+                "shallow" -> EnergyLevel.Light
+                else -> EnergyLevel.Regular
+            }
+            assertEquals("hour $hour", expected, EnergySuggestion.suggestedLevel(hour))
+        }
+    }
+}
diff --git a/contracts/fixtures/energy-hours-989.json b/contracts/fixtures/energy-hours-989.json
new file mode 100644
index 00000000..da642c35
--- /dev/null
+++ b/contracts/fixtures/energy-hours-989.json
@@ -0,0 +1,101 @@
+{
+  "issue": 990,
+  "hours": [
+    {
+      "hour": 0,
+      "level": "admin"
+    },
+    {
+      "hour": 1,
+      "level": "admin"
+    },
+    {
+      "hour": 2,
+      "level": "admin"
+    },
+    {
+      "hour": 3,
+      "level": "admin"
+    },
+    {
+      "hour": 4,
+      "level": "admin"
+    },
+    {
+      "hour": 5,
+      "level": "admin"
+    },
+    {
+      "hour": 6,
+      "level": "deep"
+    },
+    {
+      "hour": 7,
+      "level": "deep"
+    },
+    {
+      "hour": 8,
+      "level": "deep"
+    },
+    {
+      "hour": 9,
+      "level": "deep"
+    },
+    {
+      "hour": 10,
+      "level": "deep"
+    },
+    {
+      "hour": 11,
+      "level": "shallow"
+    },
+    {
+      "hour": 12,
+      "level": "shallow"
+    },
+    {
+      "hour": 13,
+      "level": "admin"
+    },
+    {
+      "hour": 14,
+      "level": "admin"
+    },
+    {
+      "hour": 15,
+      "level": "deep"
+    },
+    {
+      "hour": 16,
+      "level": "deep"
+    },
+    {
+      "hour": 17,
+      "level": "deep"
+    },
+    {
+      "hour": 18,
+      "level": "shallow"
+    },
+    {
+      "hour": 19,
+      "level": "shallow"
+    },
+    {
+      "hour": 20,
+      "level": "shallow"
+    },
+    {
+      "hour": 21,
+      "level": "admin"
+    },
+    {
+      "hour": 22,
+      "level": "admin"
+    },
+    {
+      "hour": 23,
+      "level": "admin"
+    }
+  ]
+}
diff --git a/docs/evidence/990/web-today-filter-active.png b/docs/evidence/990/web-today-filter-active.png
new file mode 100644
index 00000000..387a4dce
Binary files /dev/null and b/docs/evidence/990/web-today-filter-active.png differ
diff --git a/docs/evidence/990/web-today-s3-no-candidates.png b/docs/evidence/990/web-today-s3-no-candidates.png
new file mode 100644
index 00000000..97a5b89e
Binary files /dev/null and b/docs/evidence/990/web-today-s3-no-candidates.png differ
diff --git a/docs/evidence/990/web-today-show-all.png b/docs/evidence/990/web-today-show-all.png
new file mode 100644
index 00000000..8ca319a7
Binary files /dev/null and b/docs/evidence/990/web-today-show-all.png differ
diff --git a/docs/evidence/990/web-today-suggestion-visible.png b/docs/evidence/990/web-today-suggestion-visible.png
new file mode 100644
index 00000000..eeb71eae
Binary files /dev/null and b/docs/evidence/990/web-today-suggestion-visible.png differ
diff --git a/ios/Features/Plan/PlanTaskList.swift b/ios/Features/Plan/PlanTaskList.swift
index 47869d18..d1faa62d 100644
--- a/ios/Features/Plan/PlanTaskList.swift
+++ b/ios/Features/Plan/PlanTaskList.swift
@@ -130,6 +130,34 @@ struct PlanTaskList: View {
 
     // MARK: - Task List Content
 
+    // Issue #990: hour-based suggestion for Today (S2), actionable (S4),
+    // hidden when the level has no candidates (S3). Shared with macOS.
+    private var suggestedLevel: EnergyLevel {
+        EnergySuggestion.suggestedLevel(for: Date())
+    }
+
+    @ViewBuilder
+    private var energySuggestionPrompt: some View {
+        if filter == .today, !store.isGroupedByEnergy, !store.energySuggestionDismissed {
+            let suggested = suggestedLevel
+            EnergySuggestionPrompt(
+                suggestedLevel: suggested,
+                hour: Calendar.current.component(.hour, from: Date()),
+                isActive: store.energyFilter != .all,
+                hasCandidates: store.energyFilter != .all
+                    || filteredTasks.contains { $0.energyLevel == suggested },
+                onFilter: { store.send(.suggestedEnergyTapped(suggested)) },
+                onClear: { store.send(.energyFilterCleared) },
+                onDismiss: {
+                    // The ✕ dismisses the suggestion for the session; while a
+                    // filter is active it also clears it (never a dead end).
+                    if store.energyFilter != .all { store.send(.energyFilterCleared) }
+                    store.send(.energySuggestionDismissed)
+                }
+            )
+        }
+    }
+
     @ViewBuilder
     private var taskListContent: some View {
         // Compute the filtered list ONCE per body evaluation (issue #81).
@@ -139,6 +167,25 @@ struct PlanTaskList: View {
         if store.isLoading {
             ProgressView()
                 .frame(maxHeight: .infinity)
+        } else if filter == .today {
+            // Issue #990: the suggestion sits above Today's list, grouped or
+            // flat (S2); while filtering, the empty state keeps "Show all"
+            // reachable (never a dead end).
+            VStack(spacing: 8) {
+                energySuggestionPrompt
+                if store.energyFilter != .all && tasks.isEmpty {
+                    PepinilloEmptyState(
+                        title: emptyTitle,
+                        description: emptyDescription,
+                        systemImage: filter.systemImage,
+                        tint: filter.color
+                    )
+                    .padding(.horizontal, 16)
+                    .frame(maxHeight: .infinity)
+                } else {
+                    groupedOrFlatList(tasks: tasks)
+                }
+            }
         } else if tasks.isEmpty {
             PepinilloEmptyState(
                 title: emptyTitle,
@@ -148,7 +195,16 @@ struct PlanTaskList: View {
             )
             .padding(.horizontal, 16)
             .frame(maxHeight: .infinity)
-        } else if store.isGroupedByEnergy {
+        } else {
+            groupedOrFlatList(tasks: tasks)
+        }
+    }
+
+    // MARK: - Grouped / Flat List
+
+    @ViewBuilder
+    private func groupedOrFlatList(tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>) -> some View {
+        if store.isGroupedByEnergy {
             // Energy-grouped mode: sections by level, reorder disabled across sections
             EnergyGroupedTaskList(
                 store: store,
diff --git a/ios/Features/Tasks/EnergySuggestionPrompt.swift b/ios/Features/Tasks/EnergySuggestionPrompt.swift
new file mode 100644
index 00000000..d0ee35b6
--- /dev/null
+++ b/ios/Features/Tasks/EnergySuggestionPrompt.swift
@@ -0,0 +1,159 @@
+// EnergySuggestionPrompt.swift
+// Pepinillo — Deep Work Companion for Apple
+//
+// Issue #990: the hour-based energy suggestion promoted from an informative
+// banner to an actionable filter (S2–S4). Shared by Plan on iOS and macOS.
+//
+// UX brief (issue comment): same anatomy as the existing EnergySuggestionBanner
+// (rounded 12, level tint, icon + "X · suggested now" + reason); tap anywhere
+// filters the list to that level; while active the same surface becomes the
+// active-filter bar ("Filtered by X · Show all ✕"); hidden when the level has
+// no candidate tasks in Today (S3); dismiss (✕) only hides the suggestion for
+// the session. Level tint only — never the brand green.
+
+import SwiftUI
+import ComposableArchitecture
+
+struct EnergySuggestionPrompt: View {
+    let suggestedLevel: EnergyLevel
+    let hour: Int
+    let isActive: Bool
+    let hasCandidates: Bool
+    let onFilter: () -> Void
+    let onClear: () -> Void
+    let onDismiss: () -> Void
+
+    var body: some View {
+        if hasCandidates {
+            if isActive {
+                activeBar
+            } else {
+                promptButton
+            }
+        }
+    }
+
+    // Tap target: the whole banner filters (S4). ≥44 pt tall (S7).
+    private var promptButton: some View {
+        Button {
+            onFilter()
+            HapticManager.impact(.light)
+        } label: {
+            bannerContent
+        }
+        .buttonStyle(.plain)
+        .accessibilityLabel(String(localized: "Filter by \(suggestedLevel.displayName)"))
+        .accessibilityHint(Text(suggestionReason))
+    }
+
+    private var activeBar: some View {
+        HStack(spacing: 12) {
+            Image(systemName: suggestedLevel.icon)
+                .font(.title3)
+                .foregroundStyle(suggestedLevel.color)
+                .frame(width: 28)
+
+            VStack(alignment: .leading, spacing: 2) {
+                (Text(suggestedLevel.displayName)
+                    .foregroundStyle(suggestedLevel.color)
+                + Text(String(localized: " · showing only this level"))
+                    .foregroundStyle(.secondary))
+                    .font(.subheadline.weight(.semibold))
+            }
+
+            Spacer(minLength: 0)
+
+            Button {
+                onClear()
+                HapticManager.selection()
+            } label: {
+                Text(String(localized: "Show all"))
+                    .font(.subheadline.weight(.semibold))
+                    .foregroundStyle(suggestedLevel.color)
+            }
+            .buttonStyle(.plain)
+            .accessibilityLabel(String(localized: "Show all levels"))
+
+            Button {
+                onDismiss()
+                HapticManager.impact(.light)
+            } label: {
+                Image(systemName: "xmark")
+                    .font(.caption.weight(.semibold))
+                    .foregroundStyle(.secondary)
+                    .padding(6)
+                    .background(.quaternary, in: Circle())
+                    .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
+                    .contentShape(Circle())
+            }
+            .buttonStyle(.plain)
+            .accessibilityLabel(String(localized: "Dismiss energy suggestion"))
+        }
+        .padding(.horizontal, 14)
+        .padding(.vertical, 11)
+        .background(
+            RoundedRectangle(cornerRadius: 12, style: .continuous)
+                .fill(suggestedLevel.color.opacity(0.14))
+                .overlay(
+                    RoundedRectangle(cornerRadius: 12, style: .continuous)
+                        .stroke(suggestedLevel.color.opacity(0.35), lineWidth: 1)
+                )
+        )
+        .padding(.horizontal, 16)
+        .padding(.top, 8)
+        .transition(.opacity)
+        .accessibilityElement(children: .contain)
+    }
+
+    private var bannerContent: some View {
+        HStack(spacing: 12) {
+            Image(systemName: suggestedLevel.icon)
+                .font(.title3)
+                .foregroundStyle(suggestedLevel.color)
+                .frame(width: 28)
+
+            VStack(alignment: .leading, spacing: 2) {
+                (Text(suggestedLevel.displayName)
+                    .foregroundStyle(suggestedLevel.color)
+                + Text(String(localized: " · suggested now"))
+                    .foregroundStyle(.secondary))
+                    .font(.subheadline.weight(.semibold))
+
+                Text(EnergySuggestion.suggestionReason(forHour: hour))
+                    .font(.caption)
+                    .foregroundStyle(.secondary)
+                    .lineLimit(2)
+            }
+
+            Spacer(minLength: 0)
+
+            Image(systemName: "line.3.horizontal.decrease.circle")
+                .font(.body)
+                .foregroundStyle(.secondary)
+                .padding(6)
+                .frame(minWidth: 44, minHeight: 44)
+                .contentShape(Circle())
+        }
+        .padding(.horizontal, 14)
+        .padding(.vertical, 11)
+        .frame(minHeight: 44)
+        .background(
+            RoundedRectangle(cornerRadius: 12, style: .continuous)
+                .fill(suggestedLevel.color.opacity(0.08))
+                .overlay(
+                    RoundedRectangle(cornerRadius: 12, style: .continuous)
+                        .stroke(suggestedLevel.color.opacity(0.22), lineWidth: 1)
+                )
+        )
+        .padding(.horizontal, 16)
+        .padding(.top, 8)
+        .transition(.asymmetric(
+            insertion: .move(edge: .top).combined(with: .opacity),
+            removal: .opacity
+        ))
+    }
+
+    private var suggestionReason: String {
+        EnergySuggestion.suggestionReason(forHour: hour)
+    }
+}
diff --git a/ios/Features/Tasks/TaskListFeature.swift b/ios/Features/Tasks/TaskListFeature.swift
index baad3b09..625d4268 100644
--- a/ios/Features/Tasks/TaskListFeature.swift
+++ b/ios/Features/Tasks/TaskListFeature.swift
@@ -191,6 +191,10 @@ struct TaskListFeature {
         case filterChanged(TaskFilter)
         case planFilterSelected(PlanFilter)
         case energyFilterChanged(EnergyFilter)
+        /// Issue #990 (S4): tapping the suggestion filters the list to the level.
+        case suggestedEnergyTapped(EnergyLevel)
+        /// Issue #990 (S4): "Show all" clears the energy filter.
+        case energyFilterCleared
         case sortOrderChanged(SortOrder)
         case newTaskTitleChanged(String)
         case newTaskRequested
@@ -348,6 +352,9 @@ struct TaskListFeature {
 
             case .planFilterSelected(let filter):
                 state.selectedPlanFilter = filter
+                // Issue #990: the energy suggestion/filter is a Today-scoped
+                // interaction — switching pills clears it.
+                state.energyFilter = .all
                 // Clear detail column selection when switching filters
                 if let currentDetail = state.detail {
                     state.tasks[id: currentDetail.taskID] = TaskItemState.from(currentDetail.toDTO())
@@ -360,6 +367,15 @@ struct TaskListFeature {
                 state.energyFilter = filter
                 return .none
 
+            case .suggestedEnergyTapped(let level):
+                // Issue #990 (S4): the suggestion filters Hoy to its level.
+                state.energyFilter = EnergyFilter(rawValue: level.rawValue) ?? .all
+                return .none
+
+            case .energyFilterCleared:
+                state.energyFilter = .all
+                return .none
+
             case .sortOrderChanged(let order):
                 state.sortOrder = order
                 return .none
diff --git a/ios/Mac/MacPlanView.swift b/ios/Mac/MacPlanView.swift
index ec9d340f..e0c727e2 100644
--- a/ios/Mac/MacPlanView.swift
+++ b/ios/Mac/MacPlanView.swift
@@ -176,10 +176,35 @@ struct MacPlanView: View {
         if store.isLoading && !store.hasLoadedData {
             ProgressView()
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
-        } else if tasks.isEmpty {
+        } else if tasks.isEmpty && store.energyFilter == .all {
             emptyState
         } else {
-            taskTable(tasks: tasks)
+            // Issue #990: the energy suggestion sits above the Plan table on
+            // Today (system material — Plan is matte, no glass per design.md).
+            VStack(spacing: 8) {
+                if filter == .today, !store.energySuggestionDismissed {
+                    let suggested = EnergySuggestion.suggestedLevel(for: Date())
+                    EnergySuggestionPrompt(
+                        suggestedLevel: suggested,
+                        hour: Calendar.current.component(.hour, from: Date()),
+                        isActive: store.energyFilter != .all,
+                        hasCandidates: store.energyFilter != .all
+                            || tasks.contains { $0.energyLevel == suggested },
+                        onFilter: { store.send(.suggestedEnergyTapped(suggested)) },
+                        onClear: { store.send(.energyFilterCleared) },
+                        onDismiss: {
+                            if store.energyFilter != .all { store.send(.energyFilterCleared) }
+                            store.send(.energySuggestionDismissed)
+                        }
+                    )
+                }
+                if tasks.isEmpty {
+                    // Filtering emptied the list: keep "Show all" reachable above.
+                    emptyState
+                } else {
+                    taskTable(tasks: tasks)
+                }
+            }
         }
     }
 
diff --git a/ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift b/ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift
index 80670688..c30e25b2 100644
--- a/ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift
+++ b/ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift
@@ -96,4 +96,35 @@ struct EnergySuggestionTests {
         let level = EnergySuggestion.suggestedLevel(for: date, calendar: calendar)
         #expect(level == .deep)
     }
+
+    // MARK: - Issue #990 (S1): the shared 24-hour fixture
+
+    /// contracts/fixtures/energy-hours-989.json is the single source of truth
+    /// for the hour → level table; every platform's suite asserts its engine
+    /// against the same file.
+    @Test func matchesSharedFixtureTable() throws {
+        let fixtureURL = URL(fileURLWithPath: #filePath)
+            .deletingLastPathComponent() // TaskFeatureTests
+            .deletingLastPathComponent() // Tests
+            .deletingLastPathComponent() // ios
+            .deletingLastPathComponent() // repo root
+            .appendingPathComponent("contracts/fixtures/energy-hours-989.json")
+        let raw = try Data(contentsOf: fixtureURL)
+        let table = try JSONDecoder().decode(EnergyHoursTable.self, from: raw)
+        #expect(table.hours.count == 24)
+        for entry in table.hours {
+            #expect(
+                EnergySuggestion.suggestedLevel(forHour: entry.hour) == EnergyLevel(rawValue: entry.level),
+                "hour \(entry.hour) must map to \(entry.level)"
+            )
+        }
+    }
+}
+
+struct EnergyHoursTable: Decodable {
+    let hours: [HourEntry]
+    struct HourEntry: Decodable {
+        let hour: Int
+        let level: String
+    }
 }
diff --git a/odd/tasks/990-actionable-energy.md b/odd/tasks/990-actionable-energy.md
new file mode 100644
index 00000000..72a94a4a
--- /dev/null
+++ b/odd/tasks/990-actionable-energy.md
@@ -0,0 +1,32 @@
+# odd/tasks/990-actionable-energy.md
+
+Issue: https://github.com/tiagofur/pepinillo_nativo/issues/990 (status:approved + GO de Tiago)
+Topología: Delegated Direct · Único escritor: implementador de esta sesión
+Base: main 5c125522 · Rama: feat/990-actionable-energy (worktree pepinillo-wt-990)
+
+## Specs (S1..Sn de la issue)
+- **S1** tabla 24h compartida → `contracts/fixtures/energy-hours-989.json`; suites iOS/web/Android la afirman (macOS comparte el motor iOS). ✓
+- **S2** sugerencia visible en «Hoy» sin agrupado en iOS/macOS/Android/web; descarte por sesión. ✓
+- **S3** sin candidatos → no se muestra. ✓
+- **S4** tap → filtra; «Mostrar todo»/segundo tap quita. ✓
+- **S5** arranque por las acciones existentes (startFocusOnTask / inspector web). ✓ (sin nuevo camino)
+- **S6** gratis, sin cambios en el tope Free. ✓
+- **S7** accesibilidad + `## Visual Evidence` en el PR (en curso).
+
+## Allowed edit surfaces
+- `contracts/fixtures/energy-hours-989.json` (nuevo)
+- `ios/Features/Tasks/EnergySuggestionPrompt.swift` (nuevo) · `TaskListFeature.swift` · `PlanTaskList.swift`
+- `ios/Mac/MacPlanView.swift` · `ios/Tests/TaskFeatureTests/EnergySuggestionTests.swift`
+- `android/.../domain/tasks/EnergySuggestion.kt` + test (nuevos) · `feature/tasks/TasksScreen.kt` · res strings ×3
+- `web/src/routes/(app)/plan/+page.svelte` · `src/lib/i18n/messages.ts` · `tests/unit/energy.test.ts` (nuevo)
+
+## Tasks
+- **T1** (S1): fixture + tests 4 plataformas. RED: Android sin motor (compile fail) → GREEN. ✓
+- **T2** (S2-S4-S3 Apple): prompt compartido + acciones + enrutado por píldora. ✓
+- **T3** (S2-S4 Android): chip + wiring del ViewModel existente + strings ×3. ✓
+- **T4** (S2-S4 web): pill + filtro + i18n ×3 (+ quita el hint viejo gateado a free). ✓
+- **T5** (S7 + handoff + jueces + PR): en curso
+
+## Log
+- 26-nov: brief UX publicado como comentario (ux:shape) antes de implementar.
+- Nota entorno: el scheme PepinilloMac NO compila en este entorno por ActivityKit/27.3 (preexistente, verificado con stash — falla idéntico en main limpio); validación Mac = swiftc -parse + Visual Evidence/QA humano.
diff --git a/web/src/lib/i18n/messages.ts b/web/src/lib/i18n/messages.ts
index 79a16b89..6601bff9 100644
--- a/web/src/lib/i18n/messages.ts
+++ b/web/src/lib/i18n/messages.ts
@@ -293,6 +293,11 @@ export type MessageKey =
 	| 'plan.energy.admin'
 	| 'plan.energySuggest'
 	| 'plan.energyHint'
+	| 'plan.energySuggestedNow'
+	| 'plan.energyFilterActive'
+	| 'plan.showAll'
+	| 'plan.energyFilterAria'
+	| 'plan.energyDismissAria'
 	| 'plan.due.today'
 	| 'plan.due.tomorrow'
 	| 'plan.due.overdue'
@@ -856,6 +861,11 @@ const en: Dict = {
 	'plan.energy.admin': 'Admin',
 	'plan.energySuggest': 'Suggest for now',
 	'plan.energyHint': 'Suggested energy right now: {energy}',
+	'plan.energySuggestedNow': 'suggested now',
+	'plan.energyFilterActive': 'showing only',
+	'plan.showAll': 'Show all',
+	'plan.energyFilterAria': 'Filter the list by {energy}',
+	'plan.energyDismissAria': 'Dismiss the energy suggestion',
 	'plan.due.today': 'Today',
 	'plan.due.tomorrow': 'Tomorrow',
 	'plan.due.overdue': 'Overdue',
@@ -1477,6 +1487,11 @@ const es: Dict = {
 	'plan.energy.admin': 'Admin',
 	'plan.energySuggest': 'Sugerir para ahora',
 	'plan.energyHint': 'Energía sugerida ahora: {energy}',
+	'plan.energySuggestedNow': 'sugerida ahora',
+	'plan.energyFilterActive': 'mostrando solo',
+	'plan.showAll': 'Mostrar todo',
+	'plan.energyFilterAria': 'Filtrar la lista por {energy}',
+	'plan.energyDismissAria': 'Ocultar la sugerencia de energía',
 	'plan.due.today': 'Hoy',
 	'plan.due.tomorrow': 'Mañana',
 	'plan.due.overdue': 'Vencida',
@@ -2069,6 +2084,11 @@ const pt: Dict = {
 	'plan.energy.admin': 'Admin',
 	'plan.energySuggest': 'Sugerir para agora',
 	'plan.energyHint': 'Energia sugerida agora: {energy}',
+	'plan.energySuggestedNow': 'sugerida agora',
+	'plan.energyFilterActive': 'mostrando apenas',
+	'plan.showAll': 'Mostrar tudo',
+	'plan.energyFilterAria': 'Filtrar a lista por {energy}',
+	'plan.energyDismissAria': 'Dispensar a sugestão de energia',
 	'plan.due.today': 'Hoje',
 	'plan.due.tomorrow': 'Amanhã',
 	'plan.due.overdue': 'Vencida',
diff --git a/web/src/routes/(app)/plan/+page.svelte b/web/src/routes/(app)/plan/+page.svelte
index 21db16ef..f881db96 100644
--- a/web/src/routes/(app)/plan/+page.svelte
+++ b/web/src/routes/(app)/plan/+page.svelte
@@ -13,6 +13,7 @@
 	import Segmented from '$lib/design/Segmented.svelte';
 	import Icon from '$lib/design/Icon.svelte';
 	import { groupByEnergy, PLAN_FILTERS, quickAddDefaults, type PlanFilter } from '$lib/domain/tasks/plan';
+		import type { TaskEnergy } from '$lib/domain/entities/types';
 	import { suggestEnergy } from '$lib/domain/tasks/energy';
 	import type { Task } from '$lib/domain/entities/types';
 
@@ -86,11 +87,27 @@
 	let selectedTask = $derived(plan.tasks.find((x) => x.id === selectedId) ?? null);
 	let suggestion = $derived(suggestEnergy(new Date().getHours()));
 
+	/* Issue #990: the energy suggestion is an actionable Today-scoped filter
+	 * (S2–S4). Not persisted; dismissal lasts the session. Hidden when the
+	 * suggested level has no candidate tasks (S3). */
+	let energyFilter = $state<TaskEnergy | null>(null);
+	let suggestionDismissed = $state(false);
+	$effect(() => {
+		void plan.filter;
+		energyFilter = null;
+	});
+	let suggestionVisible = $derived(
+		plan.filter === 'today' &&
+			!suggestionDismissed &&
+			(energyFilter !== null || plan.visible.some((t) => t.energy === suggestion))
+	);
+
 	/** Toolbar search (Mac `.searchable`): narrows the visible subset by title. */
 	let displayed = $derived.by(() => {
+		const base = energyFilter ? plan.visible.filter((task) => task.energy === energyFilter) : plan.visible;
 		const q = query.trim().toLowerCase();
-		if (!q) return plan.visible;
-		return plan.visible.filter((task) => task.title.toLowerCase().includes(q));
+		if (!q) return base;
+		return base.filter((task) => task.title.toLowerCase().includes(q));
 	});
 
 	/** ⌘⌥I / toolbar toggle: open the inspector on the first visible task. */
@@ -325,6 +342,31 @@
 
 		<div class="inspector-grid" class:with-inspector={!!selectedTask}>
 		<div class="list-area">
+			{#if suggestionVisible}
+				<div class="energy-prompt" role="group">
+					{#if energyFilter}
+						<span class="energy-active">
+							✨ {t(`plan.energy.${energyFilter}`)} · {t('plan.energyFilterActive')}
+							<button class="pill-action pressable" onclick={() => (energyFilter = null)}>
+								{t('plan.showAll')}
+							</button>
+						</span>
+					{:else}
+						<button
+							class="suggest-pill pressable"
+							onclick={() => (energyFilter = suggestion)}
+							aria-label={t('plan.energyFilterAria', { energy: t(`plan.energy.${suggestion}`) })}
+						>
+							✨ {t(`plan.energy.${suggestion}`)} · {t('plan.energySuggestedNow')}
+						</button>
+						<button
+							class="pill-dismiss"
+							onclick={() => (suggestionDismissed = true)}
+							aria-label={t('plan.energyDismissAria')}
+						>✕</button>
+					{/if}
+				</div>
+			{/if}
 			{#if displayed.length === 0}
 				<!-- Mac ContentUnavailableView: symbol, title, description and the
 					 contextual action directly on the content background -->
@@ -401,10 +443,6 @@
 		<TaskInspector task={selectedTask} onclose={() => selectTask(null)} />
 	</div>
 
-	{#if plan.filter === 'today' && displayed.length > 0 && app.tier === 'free'}
-		<p class="suggest-hint">✨ {t('plan.energyHint', { energy: t(`plan.energy.${suggestion}`) })}</p>
-	{/if}
-
 	{#if showCapNotice && plan.freeCapReached}
 		<div class="cap card" role="alert">
 			<span class="cap-text">🔒 {t('plan.capBlocked')} {t('plan.upgradeTeaser')}</span>
@@ -579,9 +617,43 @@
 
 	}
 
-	.suggest-hint {
-		color: var(--muted);
-		font-size: var(--text-xs);
+	.energy-prompt {
+		display: flex;
+		align-items: center;
+		gap: 8px;
+		margin-bottom: 8px;
+	}
+	.suggest-pill,
+	.energy-active {
+		font-size: 0.85rem;
+		font-weight: 600;
+		color: var(--fg);
+		background: var(--surface-2);
+		border: 1px solid var(--border);
+		border-radius: 999px;
+		padding: 6px 14px;
+		min-height: 36px;
+	}
+	.suggest-pill {
+		cursor: pointer;
+	}
+	.pill-action {
+		margin-inline-start: 8px;
+		background: none;
+		border: none;
+		color: var(--accent);
+		font: inherit;
+		font-weight: 600;
+		cursor: pointer;
+		min-height: 36px;
+	}
+	.pill-dismiss {
+		background: none;
+		border: none;
+		color: var(--fg-muted);
+		cursor: pointer;
+		min-height: 36px;
+		min-width: 36px;
 	}
 
 	.cap {
diff --git a/web/tests/unit/energy.test.ts b/web/tests/unit/energy.test.ts
new file mode 100644
index 00000000..279c0c3e
--- /dev/null
+++ b/web/tests/unit/energy.test.ts
@@ -0,0 +1,26 @@
+import { describe, expect, it } from 'vitest';
+import { readFileSync } from 'node:fs';
+import { fileURLToPath } from 'node:url';
+import { resolve } from 'node:path';
+import { suggestEnergy } from '$lib/domain/tasks/energy';
+
+/**
+ * Issue #990 (S1): every platform asserts its hour → energy engine against
+ * the same 24-hour fixture versioned in the repo (contracts/fixtures).
+ */
+describe('shared energy-hours fixture (S1)', () => {
+	const fixturePath = resolve(
+		fileURLToPath(import.meta.url),
+		'../../../../contracts/fixtures/energy-hours-989.json'
+	);
+	const table = JSON.parse(readFileSync(fixturePath, 'utf8')) as {
+		hours: { hour: number; level: 'deep' | 'shallow' | 'admin' }[];
+	};
+
+	it('suggestEnergy matches the shared 24-hour table', () => {
+		expect(table.hours).toHaveLength(24);
+		for (const entry of table.hours) {
+			expect(suggestEnergy(entry.hour), `hour ${entry.hour}`).toBe(entry.level);
+		}
+	});
+});
```
