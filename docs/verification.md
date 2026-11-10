# Verificación y CI

Escala con el riesgo (`CHECKPOINTS.md` C3: `V0` estructural, `V1` RED/GREEN
focalizado, `V2` integración/contratos). Evidencia capturada en el PR y en el
bundle `factory_handoff.py`.

---

## 1. Matriz de comandos verificada (2026-11-10)

### Factoría (siempre primero)
```bash
python3 scripts/factory_preflight.py          # C1 read-only
make test-factory                             # 21 guardrails (scripts, plantilla PR, flags documentados)
python3 scripts/check_secrets.py --self-test && python3 scripts/check_secrets.py
```

### Backend Go
```bash
cd backend && go test ./...                   # unitarios (CI añade -race -count=1)
go vet ./...
```
CI: `.github/workflows/test.yml` (PRs backend/**) con PostgreSQL 16 + Redis 7
reales; `.github/workflows/deploy.yml` testea y despliega a producción al
push a `main` si toca `backend/**`.

### Android / Wear OS
```bash
cd android && ./gradlew :app:testDebugUnitTest :wear:testDebugUnitTest
cd android && ./gradlew :app:assembleDebug :wear:assembleDebug
```
CI: `.github/workflows/android-test.yml` ejecuta **subconjunto focalizado**
(`data.repository.*`, sync mappers, dashboard, `core.auth.*`, `core.billing.*`,
`domain.timer.*`); `SyncEngineTest` excluido hasta #281/#282 (timeout GHA).
Instrumentados Room: `./gradlew :app:connectedDebugAndroidTest`
(`MigrationTest.kt`).

### iOS / watchOS / macOS
```bash
cd ios && xcodegen generate                   # obligatorio tras tocar project.yml
# iPhone/iPad (scheme con PepinilloTests):
xcodebuild -scheme "Pepinillo Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
# macOS (sin target de tests; la lógica Mac se prueba en el simulador iOS):
xcodebuild -scheme "PepinilloMac Dev" -destination 'platform=macOS' build
```
CI: `.github/workflows/ios-test.yml` (macos-15, `xcodegen generate`, trust de
macros, simulador iPhone 16/17) ejecuta solo subconjuntos `-only-testing:`
(fast en PR, +suites de migración/persistencia/engine en push a `main`).
Trucos: `-parallel-testing-enabled NO`, timeouts por test (120/180 s) para
evitar hangs de simulador.

### Contratos
```bash
make contracts-lint    # Spectral 6.17.0 + .spectral.yaml (0 errores)
make contracts-diff    # oasdiff v1.35.0 breaking vs origin/main (fail-closed)
```
Nota: mientras esta rama reemplaza el contrato plantilla, `contracts-diff`
reportará el `GET /healthz` eliminado como breaking change contra
`origin/main`; tras el merge a `main` la comparación es limpia. Si algún día
hace falta romper un endpoint real, etiqueta el PR `contract-break` con
aprobación humana.

### iOS tests en cuarentena (conocidos)
- `AppFeatureIntegrationTests.spotlightTaskDeepLinkOpensTaskDetail`:
  `@Test(.disabled())` — deep-link `pepinillo://task/` no entrega el efecto con
  TCA 1.26 (issue #634).

---

## 2. Reglas de verificación

1. **RED observable antes de GREEN**: ningún fix/feature se marca hecho sin
   haber visto fallar el test por la razón esperada.
2. **Suite afectada, no todo el mundo**: V1 corre los tests del módulo tocado;
   V2 añade contratos + regresión cross-platform.
3. **Simuladores/OS**: si un destino no existe en tu máquina, usa el equivalente
   más cercano y **decláralo** en la evidencia.
4. **Nada se omite por tiempo**: si un check caro no cabe, escala a `leader`
   en lugar de saltarlo en silencio.
5. **Evidencia en el PR**: comando exacto + resultado observado (la plantilla
   exige secciones `## Verification Evidence` y valida `check_pr_metadata.py`).

---

## 3. Mapa de workflows CI

| Workflow | Disparador | Qué hace |
| :--- | :--- | :--- |
| `secret-scan.yml` | PRs y push a `main` | `check_secrets.py` sobre árbol y rango de commits |
| `test.yml` | PR/push `backend/**` | build + `go test -race` contra Postgres/Redis |
| `deploy.yml` | push `main` tocando `backend/**` | test + SCP + rebuild `api` + healthcheck en VPS |
| `android-test.yml` | PR/push `android/**` | subconjunto de unit tests |
| `ios-test.yml` | PR/push `ios/**` | subconjunto `-only-testing:` en simulador |
| `windows-build.yml` | PR/push `windows/**` | Core tests + builds x64/ARM64 (plataforma en pausa; se mantiene por si se reanuda) |
