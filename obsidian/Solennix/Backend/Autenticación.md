# Autenticación

#backend #auth #seguridad

> [!abstract] Resumen
> Autenticación basada en **JWT HS256** con tres tipos de token: access (24h), refresh (7d), password-reset (1h). Sin ORM, Sin sesiones en DB. Cookies httpOnly para web, Bearer header para mobile.

---

## Flujo de Registro

```mermaid
sequenceDiagram
    participant U as Usuario
    participant F as Frontend/Mobile
    participant B as Backend

    U->>F: Email + Password
    F->>B: POST /api/auth/register
    B->>B: Hash password (bcrypt)
    B->>B: Generar TokenPair (access + refresh)
    B-->>F: { access_token, refresh_token, expires_at }
    F-->>U: Redirect → /dashboard
```

## Flujo de Login

```mermaid
sequenceDiagram
    participant U as Usuario
    participant F as Frontend/Mobile
    participant B as Backend

    U->>F: Email + Password
    F->>B: POST /api/auth/login
    B->>B: CheckPassword (bcrypt compare)
    B->>B: Generar TokenPair
    B-->>F: Set-Cookie: auth_token (httpOnly, Secure)
    B-->>F: { access_token, refresh_token }
    F-->>U: Redirect → /dashboard
```

## Tres Tipos de Token

| Tipo | Subject | Duración | Uso |
|------|---------|----------|-----|
| **Access Token** | `access` | Configurable (default 24h) | Autenticar requests API |
| **Refresh Token** | `refresh` | 7 días | Renovar access tokens sin re-login |
| **Reset Token** | `password-reset` | 1 hora | Restablecer contraseña |

## Token Claims

```go
type TokenClaims struct {
    UserID uuid.UUID `json:"user_id"`
    Email  string    `json:"email"`
    jwt.RegisteredClaims  // exp, iat, iss, sub
}
```

| Claim | Valor | Descripción |
|-------|-------|-------------|
| `iss` | `"solennix-backend"` | Issuer — identifica el emisor del token |
| `sub` | `"access"` / `"refresh"` / `"password-reset"` | Subject — tipo de token |
| `user_id` | UUID | ID del usuario |
| `email` | string | Email del usuario |

> [!important] Validación estricta por tipo
 token
> `ValidateToken()` rechaza tokens con subject `refresh` o `password-reset`.
> `ValidateRefreshToken()` solo acepta subject `refresh`.
> `ValidateResetToken()` solo acepta subject `password-reset`.
> **Previene** que un refresh token se use como access token y viceversa.

## OAuth (Google y Apple) ✅

### Google Sign-In ✅

```go
// handlers/auth_handler.go
func (h *AuthHandler) GoogleSignIn(w http.ResponseWriter, r *http.Request) {
    var req struct {
        IDToken  string  `json:"id_token"`
        FullName *string `json:"full_name,omitempty"`
    }
    
    // Validar Google ID token contra GOOGLE_CLIENT_IDS
    claims, err := validateGoogleIDToken(r.Context(), req.IDToken, h.cfg.GoogleClientIDs)
    
    // Buscar o crear usuario
    user := h.userRepo.GetByGoogleID(ctx, claims.Subject)
    if user == nil {
        user = CreateUser(claims.Email, claims.Name)
        user.GoogleUserID = claims.Subject
    }
    
    // Generar TokenPair y setear cookie httpOnly
    tokens, _ := h.authService.GenerateTokenPair(user.ID, user.Email)
    setAuthCookie(w, r, tokens.AccessToken)
    
    writeJSON(w, http.StatusOK, TokenResponse{
        AccessToken:  tokens.AccessToken,
        RefreshToken: tokens.RefreshToken,
        User:         user,
    })
}
```

**Validación:**
- Verifica `audience` contra `GOOGLE_CLIENT_IDS` (comma-separated: iOS, Android, Web)
- Busca usuario existente por `google_user_id`
- Si no existe → crea usuario con password nullable
- Genera JWT tokens + setea httpOnly cookie
- Status: ✅ Completado y en producción

### Apple Sign-In ✅

```go
// handlers/auth_handler.go
func (h *AuthHandler) AppleSignIn(w http.ResponseWriter, r *http.Request) {
    var req struct {
        IdentityToken     string  `json:"identity_token"`
        AuthorizationCode string  `json:"authorization_code"`
        FullName          *string `json:"full_name,omitempty"`
        Email             *string `json:"email,omitempty"`
    }
    
    // Validar Apple identity token
    claims, err := validateAppleIDToken(req.IdentityToken, h.cfg.AppleClientIDs)
    
    // Buscar o crear usuario
    user := h.userRepo.GetByAppleID(ctx, claims.Subject)
    if user == nil {
        email := claims.Email
        if email == "" && req.Email != nil {
            email = *req.Email
        }
        user = CreateUser(email, *req.FullName)
        user.AppleUserID = claims.Subject
    }
    
    // Generar TokenPair
    tokens, _ := h.authService.GenerateTokenPair(user.ID, user.Email)
    setAuthCookie(w, r, tokens.AccessToken)
    
    writeJSON(w, http.StatusOK, TokenResponse{
        AccessToken:  tokens.AccessToken,
        RefreshToken: tokens.RefreshToken,
        User:         user,
        EmailIsPrivateRelay: claims.IsPrivateRelay,
    })
}
```

**Validación:**
- Verifica `audience` contra `APPLE_CLIENT_IDS` (Apple Team ID + Bundle ID)
- Busca usuario existente por `apple_user_id`
- Soporta optional `authorization_code` para future refresh token rotation
- Detecta Private Relay emails en response
- Genera JWT tokens + setea httpOnly cookie
- Status: ✅ Completado y en producción

### Account Linking (Futuro)

| Proveedor | Method | Description |
|-----------|--------|-------------|
| Google | `LinkGoogleAccount()` | Si usuario ya autenticado → vincular google_user_id |
| Apple | `LinkAppleAccount()` | Si usuario ya autenticado → vincular apple_user_id |

> [!note] Password nullable
> Migración 029 hace que `password_hash` sea nullable (`*string`). Esto permite cuentas OAuth-only sin password.

## Token Refresh

1. Cliente envía refresh token a `POST /api/auth/refresh`
2. Backend valida que sea tipo `refresh` (no `access`, no `reset`)
3. Genera nuevo `TokenPair` (access + refresh)
4. Retorna ambos tokens al cliente

## Token Blacklist (Logout)

- Al hacer logout, el token se hashea con SHA-256 y se agrega a `AccessTokenBlacklist` (`sync.Map`)
- El middleware Auth verifica blacklist antes de validar el JWT
- **Limitación**: Blacklist en memoria — se pierde al reiniciar el servidor

> [!warning] Mejora pendiente
> Migrar blacklist a Redis o tabla `revoked_tokens` en DB para persistencia entre reinicios.

## Password Hashing

- **Algoritmo**: bcrypt con `bcrypt.DefaultCost` (cost factor 10)
- **Nunca expuesto**: `PasswordHash` tiene tag `json:"-"`
- `HashPassword()` — genera hash al registrar o cambiar contraseña
- `CheckPassword()` — compara password plana con hash

## Cookies httpOnly (Web)

```go
// Login exitoso:
http.SetCookie(&http.Cookie{
    Name:     "auth_token",
    Value:    tokenPair.AccessToken,
    Path:     "/",
    HttpOnly: true,
    Secure:   cfg.Environment == "production",
    SameSite: http.SameSiteLaxMode,
    MaxAge:   cfg.JWTExpiryHours * 3600,
})

// Logout:
http.SetCookie(&http.Cookie{
    Name:     "auth_token",
    Value:    "",
    Path:     "/",
    HttpOnly: true,
    Secure:   cfg.Environment == "production",
    SameSite: http.SameSiteLaxMode,
    MaxAge:   -1,  // Delete
})
```

## Endpoints

| Metodo | Ruta | Handler | Descripción |
|--------|------|---------|-------------|
| `POST` | `/api/auth/register` | `Register` | Registro email/password |
| `POST` | `/api/auth/login` | `Login` | Login con credenciales |
| `POST` | `/api/auth/logout` | `Logout` | Limpia cookie + blacklist token |
| `POST` | `/api/auth/refresh` | `RefreshToken` | Renueva access token |
| `POST` | `/api/auth/forgot-password` | `ForgotPassword` | Email de recuperación |
| `POST` | `/api/auth/reset-password` | `ResetPassword` | Nueva contraseña con token |
| `POST` | `/api/auth/google` | `GoogleSignIn` | OAuth Google |
| `POST` | `/api/auth/apple` | `AppleSignIn` | OAuth Apple |
| `GET` | `/api/auth/me` | `Me` | Perfil del usuario actual |
| `POST` | `/api/auth/change-password` | `ChangePassword` | Cambio desde perfil |

> Rate limit: **5 requests/minuto** por IP en endpoints de auth.

## Relaciones

- [[Middleware Stack]] — Auth middleware en detalle
- [[Seguridad]] — JWT blacklist, bcrypt, cookies
- [[Arquitectura General]] — Servicios de auth
