#android #seguridad #release #play-store

# 🔐 Firma y Secretos de Release — Android

> [!warning] Estado actual
> **Bloque A del plan Play Store (Wave Rescate Android)** — en progreso.
> Este documento describe cómo configurar y rotar los secretos de firma y RevenueCat.

---

## Resumen

El build de release de Solennix Android necesita dos secretos que **NO viven en el repo**:

1. **Keystore de firma** (`solennix.jks`) — firma el APK/AAB para Play Store
2. **RevenueCat API key** (`REVENUECAT_API_KEY`) — habilita suscripciones en runtime

Ambos se resuelven en este orden (el primero que exista gana):

| Secreto | Env var (CI) | Archivo local (dev) |
| ------- | ------------ | ------------------- |
| Keystore file | `SOLENNIX_KEYSTORE_FILE` | `android/key.properties` → `storeFile` |
| Keystore password | `SOLENNIX_KEYSTORE_PASSWORD` | `android/key.properties` → `storePassword` |
| Key alias | `SOLENNIX_KEY_ALIAS` | `android/key.properties` → `keyAlias` |
| Key password | `SOLENNIX_KEY_PASSWORD` | `android/key.properties` → `keyPassword` |
| RevenueCat API key | `REVENUECAT_API_KEY` | `~/.gradle/gradle.properties` → `REVENUECAT_API_KEY=...` |

**Fail-fast**: si intentás `./gradlew assembleRelease` o `bundleRelease` sin tener estos secretos, el build falla con error explícito antes de compilar — nunca más APKs sin firmar accidentales.

---

## Qué está gitignored (verificado)

`android/.gitignore` incluye:

- `key.properties` (línea 34)
- `*.jks`, `*.keystore`, `*.p12`, `*.jceks` (líneas 30-33)
- `app/google-services.json` (línea 37)

> [!success] Ninguno de estos archivos está committed en git.
> `git ls-files` y `git log --all` verificados el 2026-04-11.

---

## Setup inicial de un dev nuevo

### 1. Copiar el template

```bash
cd android
cp key.properties.example key.properties
```

### 2. Generar un keystore nuevo (solo si no tenés uno)

> [!tip] Si heredás el proyecto, pedí el `.jks` al dev anterior — NO generes uno nuevo.
> Una vez publicada una versión en Play Store, el upload key no se puede cambiar sin intervención manual de Google Play Support.

```bash
keytool -genkeypair \
  -v \
  -keystore android/solennix.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storetype PKCS12
```

Vas a ver prompts:

- **Keystore password**: mínimo 16 caracteres, mixto — **NO usar `asd123` ni nada similar**
- **First and last name**: `Solennix` (o tu nombre)
- **Organizational unit**: `Mobile`
- **Organization**: `Creapolis`
- **City/State/Country**: tus datos reales
- **Key password**: podés darle el mismo que el store, o uno distinto (recomendado)

Anotá ambos passwords en un password manager (1Password, Bitwarden, etc.) — si los perdés, **perdiste la identidad de la app**.

### 3. Editar `android/key.properties`

```properties
storeFile=solennix.jks
keyAlias=upload
storePassword=<el password que elegiste>
keyPassword=<el password del key>
```

### 4. Configurar RevenueCat API key

```bash
# Opción A: en ~/.gradle/gradle.properties (recomendado — sirve para todos los proyectos)
echo "REVENUECAT_API_KEY=goog_xxxxxxxxxxxxxxxxxxxxxxxxx" >> ~/.gradle/gradle.properties

# Opción B: en el environment (si usás direnv o zshenv)
export REVENUECAT_API_KEY=goog_xxxxxxxxxxxxxxxxxxxxxxxxx
```

La key la sacás del [RevenueCat Dashboard](https://app.revenuecat.com/) → **Project Settings → API Keys → Public App-Specific API Keys → Google Play**.

Empieza con `goog_` (Android) o `appl_` (iOS). **No mezclar.**

### 5. Verificar que el build funciona

```bash
cd android
./gradlew :app:assembleRelease
```

Si falla con `Cannot build release: missing required config:` → revisá cuál secreto falta.
Si falla con `Failed to read key upload from store`: el password del key es incorrecto.
Si compila y genera `app/build/outputs/apk/release/app-release.apk` → todo OK.

---

## Rotar el password del keystore existente

Aplica si el password actual es trivial (como `asd123`) y la app **aún no está publicada**.

```bash
# Rotar el store password
keytool -storepasswd \
  -keystore android/solennix.jks \
  -storepass asd123 \
  -new <nuevo-password-fuerte>

# Rotar el key password
keytool -keypasswd \
  -keystore android/solennix.jks \
  -alias upload \
  -storepass <nuevo-password-fuerte> \
  -keypass asd123 \
  -new <nuevo-key-password-fuerte>
```

Después actualizá `android/key.properties` con los nuevos valores.

---

## Rotar el keystore ya publicado en Play Store

Si la app YA está en Play Store con una versión publicada, **no podés simplemente reemplazar el keystore**. Hay dos caminos:

1. **Play App Signing está habilitado** (recomendado, es el default en apps nuevas):
   - Google firma la app final con su propio key
   - Vos solo firmás con un "upload key" que SÍ podés rotar
   - Flujo: Play Console → Setup → App integrity → Upload key certificate → Request upload key reset
   - Google responde por email con los pasos — normalmente 48h

2. **Play App Signing NO está habilitado** (deprecated, apps viejas):
   - No hay forma de rotar. El keystore es la identidad de la app.
   - Tendrías que publicar una app nueva con otro `applicationId`.

> [!tip] Como Solennix tiene `versionCode = 1` y nunca se publicó → rotación libre, sin pedirle nada a Google.

---

## CI (GitHub Actions u otro)

En CI, **no subas el `.jks` al repo**. Opciones:

1. **Base64-encoded secret**:

    ```yaml
    env:
      SOLENNIX_KEYSTORE_FILE: ${{ runner.temp }}/solennix.jks
      SOLENNIX_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
      SOLENNIX_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
      SOLENNIX_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
      REVENUECAT_API_KEY: ${{ secrets.REVENUECAT_API_KEY }}

    steps:
      - uses: actions/checkout@v4
      - name: Decode keystore
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > ${{ runner.temp }}/solennix.jks
      - name: Build release
        run: ./gradlew :app:bundleRelease
        working-directory: android
    ```

2. **Google Cloud Secret Manager / HashiCorp Vault**: cargar los secretos en env vars antes del build.

---

## SSL Pinning

> [!warning] Defensa contra MITM
> Sin pinning, cualquier atacante con control de la red (proxy corporativo con TLS inspection, WiFi público comprometido, router hackeado) puede interceptar y modificar los requests de la app. Pinning rompe ese ataque.

El cliente Ktor (`KtorClient`) instala un `CertificatePinner` de OkHttp si `BuildConfig.SSL_PINS` está poblado. Los pins se resuelven desde:

1. Env var `SOLENNIX_SSL_PINS` (CI)
2. Gradle property `SOLENNIX_SSL_PINS` (en `~/.gradle/gradle.properties`)

Formato: lista separada por comas de entries `sha256/<base64>=`. Ejemplo:

```properties
SOLENNIX_SSL_PINS=sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
```

**Mínimo 2 pins en release** (current + backup) — sin un backup pin, cualquier rotación del certificado del backend brickea la app hasta que los usuarios actualicen. `./gradlew :app:bundleRelease` falla si hay menos de 2.

### Obtener los pins de `api.solennix.com`

El pin es el hash SHA-256 del **Subject Public Key Info** (no del cert entero). Usá `openssl`:

```bash
# Pin del leaf cert (current)
echo | openssl s_client -servername api.solennix.com -connect api.solennix.com:443 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl rsa -pubin -outform DER 2>/dev/null \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64

# Pin de la intermediate CA (backup — sobrevive rotación del leaf)
echo | openssl s_client -servername api.solennix.com -connect api.solennix.com:443 -showcerts 2>/dev/null \
  | awk '/BEGIN CERT/,/END CERT/{print}' \
  | awk -v RS='-----END CERTIFICATE-----\n' 'NR==2{print $0 "-----END CERTIFICATE-----"}' \
  | openssl x509 -pubkey -noout \
  | openssl rsa -pubin -outform DER 2>/dev/null \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

> [!tip] Estrategia recomendada
> Pinea el **leaf + intermediate + backup intermediate de otra CA**. Eso te da resiliencia ante:
> - Rotación automática del leaf (el intermediate pin sigue válido)
> - Compromiso del intermediate (el backup de otra CA sigue válido)
> - Cualquier ataque con un cert legítimamente firmado por CA distinta (el pinner lo rechaza)

### Configurar los pins

Una vez que tengas los hashes, pegalos en `~/.gradle/gradle.properties`:

```properties
SOLENNIX_SSL_PINS=sha256/<leaf-pin>=,sha256/<intermediate-pin>=,sha256/<backup-pin>=
```

### Pins actuales (snapshot 2026-04-11)

> [!warning] Rotación
> **El pin del leaf rota cada 60-90 días** cuando Let's Encrypt renueva el certificado automáticamente. Si ves `SSLPeerUnverifiedException` en producción, regenerá el leaf pin con los comandos de arriba. El intermediate (R13) es estable por años.

- **Leaf** (`api.solennix.com` cert actual al 2026-04-11):
  `sha256/cqUCZrKa2WzBkuENY5IHCkPgp7uR9Xsb3k2OUw0u3Hs=`
- **Intermediate** (Let's Encrypt R13 — estable):
  `sha256/AlSQhgtJirc8ahLyekmtX+Iw+v46yPYRLJt9Cq1GlB0=`

Valor completo para copiar a `~/.gradle/gradle.properties`:
```properties
SOLENNIX_SSL_PINS=sha256/cqUCZrKa2WzBkuENY5IHCkPgp7uR9Xsb3k2OUw0u3Hs=,sha256/AlSQhgtJirc8ahLyekmtX+Iw+v46yPYRLJt9Cq1GlB0=
```

O para CI / build ad-hoc:
```bash
./gradlew :app:assembleRelease \
  -PSOLENNIX_SSL_PINS="sha256/cqUCZrKa2WzBkuENY5IHCkPgp7uR9Xsb3k2OUw0u3Hs=,sha256/AlSQhgtJirc8ahLyekmtX+Iw+v46yPYRLJt9Cq1GlB0="
```

### Debug builds

Debug builds pueden correr **sin pinning** — dejá `SOLENNIX_SSL_PINS` vacío y `KtorClient` va a loguear un warning en `logcat`:

```
W/KtorClient: SSL pinning DISABLED: BuildConfig.SSL_PINS is empty...
```

Esto es intencional — permite desarrollar contra `http://10.0.2.2:8080` o `https://staging.solennix.com` sin tener que configurar pins separados por ambiente.

### Verificar que funciona

Corré una request desde la app y buscá en `logcat`:

```bash
adb logcat | grep -E "KtorClient|CertificatePinner"
```

Si ves `SSL pinning DISABLED` en release → los pins no llegaron al BuildConfig.
Si ves `javax.net.ssl.SSLPeerUnverifiedException: Certificate pinning failure!` → el pin no matchea el cert real. Re-generá los pins con openssl.

Testear el rechazo (Man-in-the-Middle simulado): corré la app detrás de Charles Proxy o mitmproxy con su root cert instalado — si el pinning funciona, TODAS las requests a api.solennix.com fallan con `ApiError.SecurityError`. Si pasan, el pinning NO está activo.

### Manejo de `SecurityError` en UI

`ApiErrorMapper` mapea `SSLPeerUnverifiedException` y `SSLHandshakeException` a `ApiError.SecurityError`. Los ViewModels deben distinguirlo del `NetworkError` genérico — un `SecurityError` NO se debe reintentar automáticamente y debe mostrar un mensaje del tipo:

> "No pudimos verificar la conexión segura con el servidor. Posible red comprometida. Intentá desde otra red."

---

## Checklist pre-release

Antes de subir una versión a Play Store:

- [ ] `key.properties` existe y tiene passwords fuertes (no `asd123`)
- [ ] `solennix.jks` existe en `android/` o env var `SOLENNIX_KEYSTORE_FILE` apunta a él
- [ ] Passwords del keystore guardados en password manager (no perder)
- [ ] `REVENUECAT_API_KEY` configurado y empieza con `goog_`
- [ ] `SOLENNIX_SSL_PINS` tiene al menos 2 pins separados por coma
- [ ] Probado con Charles/mitmproxy: pinning rechaza requests con root cert falso
- [ ] `./gradlew :app:bundleRelease` genera el AAB sin errores
- [ ] El AAB firmado se valida: `jarsigner -verify -verbose app/build/outputs/bundle/release/app-release.aab`
- [ ] `versionCode` incrementado respecto a la versión anterior publicada

---

## Estado actual (2026-04-11)

> [!warning] Acciones pendientes del usuario
> - [ ] Rotar `asd123` → password fuerte (keytool -storepasswd)
> - [ ] Configurar `REVENUECAT_API_KEY` en `~/.gradle/gradle.properties`
> - [ ] Generar `SOLENNIX_SSL_PINS` con los comandos openssl y ponerlos en `~/.gradle/gradle.properties`
> - [ ] Guardar passwords en password manager
> - [ ] Validar `./gradlew :app:assembleRelease` funciona end-to-end
> - [ ] Testear SSL pinning con Charles/mitmproxy (verificar que rechaza root cert falso)

## Commits del Wave Rescate (rama `super-plan`)

| Commit    | Bloque                                | Descripción corta                                                                 |
| --------- | ------------------------------------- | --------------------------------------------------------------------------------- |
| `f003a0b` | **A**                                 | `chore(android): add fail-fast signing and RevenueCat secret validation`           |
| `3d2a763` | **B**                                 | `feat(android): add SSL certificate pinning with fail-fast release gate`           |
| `b75881c` | **C**                                 | `fix(android): wire upgrade button to real subscription flow`                      |
| `d8c77bd` | **D** (slices 1+2)                    | `fix(android): surface CRUD failures via retryable Snackbar`                      |
| (next)    | **F**                                 | `docs(android): sync Roadmap with Wave Rescate reality`                           |

> [!note] Completado por Claude en los bloques A + B + C + D (parcial) + F
> - [x] **Bloque A** — `build.gradle.kts` soporta env vars + file con fail-fast en release
> - [x] **Bloque A** — `key.properties.example` creado como template
> - [x] **Bloque A** — Validación de `REVENUECAT_API_KEY` antes de compilar release
> - [x] **Bloque A** — Warning en debug si RevenueCat key está vacío
> - [x] **Bloque B** — `CertificatePinner` instalado en `KtorClient` con resolución desde env/gradle property
> - [x] **Bloque B** — `BuildConfig.SSL_PINS` + `BuildConfig.API_HOST` emitidos por `core/network`
> - [x] **Bloque B** — `ApiError.SecurityError` agregado y mapeo de `SSLPeerUnverifiedException`/`SSLHandshakeException`
> - [x] **Bloque B** — Fail-fast en release si faltan <2 pins
> - [x] **Bloque C** — Ruta `pricing` ahora renderea `SubscriptionScreen` real (compra + restore + provider badge)
> - [x] **Bloque C** — `PricingScreen.kt` zombie eliminado (info estática duplicada con precios hardcodeados)
> - [x] **Bloque C** — `AuthViewModel.syncRevenueCat` ahora usa `logInWith` con logs en lugar de `catch (_:)` silencioso
> - [x] **Bloque D** — Framework `UiEvent` + `UiEventSnackbarHandler` en `core:designsystem`
> - [x] **Bloque D** — `ProductListViewModel.deleteProduct` + refresh emiten errores con Snackbar "Reintentar"
> - [x] **Bloque D** — `InventoryListViewModel.deleteItem` + `adjustStock` + `refresh` con Snackbar "Reintentar"
> - [x] **Bloque D** — `EventFormViewModel.loadExistingEvent` — ahora expone `loadError` y el screen renderea card de error con botón "Reintentar" en lugar de un form vacío
> - [ ] **Bloque D slice 3 (pendiente)** — secondary fetches en EventForm (product costs, equipment suggestions) y QuickQuote — no bloquean flujos pero muestran datos incompletos silenciosamente
> - [ ] **Bloque D spinner timeouts (pendiente)** — 12 pantallas con `CircularProgressIndicator` sin fallback si la API cuelga (UX polish, no release blocker)
> - [x] Docs sincronizados con `11_CURRENT_STATUS.md`

---

## Relaciones

- [[Android MOC]]
- [[Roadmap Android]]
- [[Autenticación]] — donde vive la integración con RevenueCat
- [[Módulo Settings]] — PricingScreen usa la API key
- [[../PRD/11_CURRENT_STATUS|Estado actual del proyecto]]
