# OAuth Integration for Pepinillo Backend

## Summary

This document describes the changes made to align the Go backend with mobile app requirements for Google Sign-In and Sign In with Apple.

## Changes Made

### 1. Database Migration

**File:** `migrations/000006_add_oauth_providers.up.sql`
- Added OAuth fields to `users` table:
  - `google_id` (VARCHAR 255, UNIQUE)
  - `google_email` (VARCHAR 255)
  - `google_name` (VARCHAR 255)
  - `google_picture` (TEXT)
  - `apple_id` (VARCHAR 255, UNIQUE)
  - `apple_email` (VARCHAR 255)
  - `apple_name` (VARCHAR 255)
- Created indexes for `google_id` and `apple_id`

**File:** `migrations/000006_add_oauth_providers.down.sql`
- Rollback script to remove OAuth fields and indexes

### 2. Domain Layer

**File:** `internal/domain/user.go`
- Added OAuth fields to `User` struct:
  ```go
  GoogleID      *string `json:"googleId,omitempty" gorm:"uniqueIndex"`
  GoogleEmail   *string `json:"googleEmail,omitempty"`
  GoogleName    *string `json:"googleName,omitempty"`
  GooglePicture *string `json:"googlePicture,omitempty"`
  AppleID       *string `json:"appleId,omitempty" gorm:"uniqueIndex"`
  AppleEmail    *string `json:"appleEmail,omitempty"`
  AppleName     *string `json:"appleName,omitempty"`
  ```

**File:** `internal/domain/oauth.go` (NEW)
- Added domain types for OAuth:
  - `LinkedProviders` - shows which providers are linked to user
  - `OAuthProvider` - info about linked OAuth provider
  - `GoogleUserInfo` - decoded Google ID token data
  - `AppleUserInfo` - decoded Apple ID token data

### 3. Repository Layer

**File:** `internal/ports/repositories.go`
- Added OAuth methods to `UserRepository` interface:
  ```go
  GetByGoogleID(ctx context.Context, googleID string) (*domain.User, error)
  GetByAppleID(ctx context.Context, appleID string) (*domain.User, error)
  LinkGoogleAccount(ctx context.Context, userID, googleID, email, name, picture string) error
  UnlinkGoogleAccount(ctx context.Context, userID string) error
  LinkAppleAccount(ctx context.Context, userID, appleID, email, name string) error
  UnlinkAppleAccount(ctx context.Context, userID string) error
  ```

**File:** `internal/adapters/repositories/postgres/user_repository.go`
- Implemented OAuth methods for PostgreSQL repository

### 4. Service Layer

**File:** `internal/services/oauth_service.go` (NEW)
- Implemented `OAuthService` with:
  - `LoginWithGoogle` - verify Google ID token, login or create user
  - `LoginWithApple` - verify Apple ID token, login or create user
  - `LinkGoogleAccount` - link Google account to existing user
  - `UnlinkGoogleAccount` - unlink Google account (safety: requires other auth method)
  - `LinkAppleAccount` - link Apple account to existing user
  - `UnlinkAppleAccount` - unlink Apple account (safety: requires other auth method)
  - `GetLinkedProviders` - get list of linked OAuth providers
- Token verification:
  - Google: calls Google's `oauth2.googleapis.com/tokeninfo` endpoint
  - Apple: fetches JWKS from Apple and validates ID token signature
- Account linking:
  - Automatic linking when email matches existing user
  - Manual linking via protected endpoints
  - Prevents unlinking last auth method

### 5. Handler Layer

**File:** `internal/adapters/handlers/oauth_handler.go` (NEW)
- Implemented `OAuthHandler` with endpoints:
  - `POST /api/v1/auth/google` - Login with Google
  - `POST /api/v1/auth/apple` - Login with Apple
  - `POST /api/v1/auth/link/google` - Link Google account
  - `POST /api/v1/auth/link/apple` - Link Apple account
  - `DELETE /api/v1/auth/unlink/google` - Unlink Google account
  - `DELETE /api/v1/auth/unlink/apple` - Unlink Apple account
  - `GET /api/v1/auth/providers` - Get linked providers

**File:** `internal/adapters/handlers/routes.go`
- Updated `RouteHandlers` struct to include `OAuth *OAuthHandler`
- Added public OAuth login routes
- Added protected OAuth account linking routes

### 6. Dependency Injection

**File:** `cmd/api/main.go`
- Created `OAuthService` instance
- Added `OAuthHandler` to `RouteHandlers`

### 7. Test Updates

**Files:**
- `internal/services/mocks_test.go` - Added OAuth methods to `MockUserRepository`
- `internal/services/auth_service_test.go` - Added OAuth methods to `fakeUserRepo`
- `internal/adapters/handlers/auth_handler_test.go` - Added OAuth methods to `fakeUserRepository`
- `tests/integration/email_verification_flow_test.go` - Added OAuth methods to `integrationUserRepo`

### 8. Dependencies

**File:** `go.mod`
- Added:
  - `github.com/lestrrat-go/jwx/v2/jwk` - for Apple JWKS fetching
  - `github.com/lestrrat-go/jwx/v2/jwt` - for Apple ID token validation

## API Endpoints

### Public (No Authentication Required)

#### Login with Google
```
POST /api/v1/auth/google
Content-Type: application/json

Request:
{
  "idToken": "google-id-token-string"
}

Response:
{
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "name": "User Name",
    "googleId": "google-sub",
    "googleEmail": "user@example.com",
    "googleName": "User Name",
    "googlePicture": "https://...",
    "subscriptionTier": "free"
  },
  "tokens": {
    "accessToken": "jwt-access-token",
    "refreshToken": "jwt-refresh-token",
    "expiresIn": 900
  }
}
```

#### Login with Apple
```
POST /api/v1/auth/apple
Content-Type: application/json

Request:
{
  "idToken": "apple-id-token-string"
}

Response: (same as Google login)
```

### Protected (Requires JWT Access Token)

#### Link Google Account
```
POST /api/v1/auth/link/google
Authorization: Bearer <access-token>
Content-Type: application/json

Request:
{
  "idToken": "google-id-token-string"
}

Response:
{
  "message": "google_account_linked",
  "user": { /* updated user object */ }
}
```

#### Link Apple Account
```
POST /api/v1/auth/link/apple
Authorization: Bearer <access-token>
Content-Type: application/json

Request:
{
  "idToken": "apple-id-token-string"
}

Response:
{
  "message": "apple_account_linked",
  "user": { /* updated user object */ }
}
```

#### Unlink Google Account
```
DELETE /api/v1/auth/unlink/google
Authorization: Bearer <access-token>

Response:
{
  "message": "google_account_unlinked"
}
```

#### Unlink Apple Account
```
DELETE /api/v1/auth/unlink/apple
Authorization: Bearer <access-token>

Response:
{
  "message": "apple_account_unlinked"
}
```

#### Get Linked Providers
```
GET /api/v1/auth/providers
Authorization: Bearer <access-token>

Response:
{
  "hasPassword": true,
  "google": {
    "id": "google-sub",
    "email": "user@gmail.com",
    "name": "User Name",
    "picture": "https://..."
  },
  "apple": {
    "id": "apple-sub",
    "email": "user@icloud.com",
    "name": "User Name"
  }
}
```

## Security Considerations

1. **Token Verification**: Both Google and Apple ID tokens are verified server-side
2. **Account Linking Safety**: Users cannot unlink their last authentication method
3. **Email Matching**: When logging in with OAuth, if the email matches an existing user, the account is automatically linked
4. **Rate Limiting**: OAuth login endpoints use the same rate limits as email/password login (5 requests per minute)
5. **JWT Security**: All tokens use HMAC-SHA256 with configurable secret

## Mobile App Integration

### Android (Google Sign-In)

The Android app should:
1. Use `CredentialManager` to get Google ID token
2. Send the ID token to `POST /api/v1/auth/google`
3. Store and use the returned JWT tokens for authenticated requests
4. For account linking, send the Google ID token to `POST /api/v1/auth/link/google`

Example flow:
```kotlin
val credentialManager = CredentialManager.create(context)
val googleIdOption = GetGoogleIdOption.Builder()
    .setServerClientId(GOOGLE_CLIENT_ID)
    .setFilterByAuthorizedAccounts(true)
    .build()

val result = credentialManager.getCredential(request, googleIdOption)
val googleIdToken = result.credential.data?.getString(CredentialData.KEY_ID_TOKEN)

// Send to backend
val response = apiService.loginWithGoogle(LoginWithGoogleRequest(googleIdToken))
```

### iOS (Sign In with Apple)

The iOS app should:
1. Use `AuthenticationServices` to get Apple ID token
2. Send the ID token to `POST /api/v1/auth/apple`
3. Store and use the returned JWT tokens for authenticated requests
4. For account linking, send the Apple ID token to `POST /api/v1/auth/link/apple`

Example flow:
```swift
let request = ASAuthorizationAppleIDProvider().createRequest()
request.requestedScopes = [.fullName, .email]

let authorizationController = ASAuthorizationController(authorizationRequests: [request])
authorizationController.performRequests { authorization, error in
    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
        let appleIDToken = appleIDCredential.identityToken
        
        // Send to backend
        Task {
            try await apiService.loginWithApple(LoginWithAppleRequest(appleIDToken))
        }
    }
}
```

## Environment Variables

No new environment variables are required for OAuth integration:
- Google token verification uses the public Google endpoint (no API key needed)
- Apple token verification uses the public Apple JWKS endpoint (no credentials needed)

## Testing

### Manual Testing

To manually test the OAuth flow:

1. **Google Sign-In**:
   - Create a test Google OAuth 2.0 client in Google Cloud Console
   - Use a client like Postman to send a valid Google ID token
   - Verify that a new user is created or an existing user is logged in
   - Test account linking with an existing email/password user

2. **Sign In with Apple**:
   - Create a test app in Apple Developer account
   - Generate a valid Apple ID token
   - Verify the same flow as Google Sign-In

### Automated Testing

OAuth methods have been added to all test repositories:
- `MockUserRepository` in `internal/services/mocks_test.go`
- `fakeUserRepo` in `internal/services/auth_service_test.go`
- `fakeUserRepository` in `internal/adapters/handlers/auth_handler_test.go`
- `integrationUserRepo` in `tests/integration/email_verification_flow_test.go`

## Deployment Notes

1. **Database Migration**: Run migration `000006_add_oauth_providers` on production database
2. **No External Dependencies**: OAuth verification uses public endpoints, no external credentials needed
3. **Backward Compatible**: Existing email/password authentication continues to work unchanged
4. **CloudKit Migration**: iOS users currently using CloudKit will need to update to use the backend for OAuth login

## Future Enhancements

1. **iOS Hybrid Authentication**: Currently iOS uses CloudKit only; future work to combine Sign in with Apple with backend JWT tokens
2. **OAuth2 Refresh Tokens**: Store Google/Apple refresh tokens for silent renewal
3. **Web OAuth**: Add support for web-based Google/Apple login
4. **Multiple Google Accounts**: Support linking multiple Google accounts per user
5. **Profile Picture Sync**: Automatically sync profile pictures from Google/Apple

## Troubleshooting

### Google Token Verification Fails

- Check that the Google ID token is not expired
- Verify the Google Client ID matches the one configured in the backend
- Ensure the token was generated for the correct audience (your Google Client ID)

### Apple Token Verification Fails

- Check that the Apple ID token is not expired (Apple tokens expire quickly)
- Verify the bundle ID in the token matches your app's bundle ID
- Ensure the Apple developer account is active

### Account Linking Fails

- If linking fails with "already linked to another user", check for duplicate emails
- If unlinking fails with "no other authentication method", user must set a password first
- Use `GET /api/v1/auth/providers` to check current linked providers
