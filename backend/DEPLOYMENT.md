# Pepinillo Backend — Deployment Guide

## Railway Setup (One-Time)

### 1. Create Railway Project
- Go to [railway.app](https://railway.app) and create a new project
- Add services: **PostgreSQL**, **Redis**, **Empty Service** (for the API)

### 2. Configure API Service
- Connect GitHub repo, set root directory to `backend/`
- Railway will auto-detect the Dockerfile

### 3. Environment Variables
Set these in the Railway API service dashboard:

**Required:**
```
APP_ENV=production
JWT_SECRET=<generate with: openssl rand -hex 64>
CORS_ALLOWED_ORIGINS=https://pepinillo.app
```

**Auto-provided by Railway (link the services):**
```
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
```

**OAuth (when ready):**
```
GOOGLE_CLIENT_IDS=<android-client-id>,<ios-client-id>
APPLE_BUNDLE_ID=dev.creapolis.pepinillo
```

**Push Notifications (when ready):**
```
PUSH_PROVIDER=hybrid
FCM_PROJECT_ID=<from-firebase-console>
FCM_SERVICE_ACCOUNT_EMAIL=<from-firebase>
FCM_SERVICE_ACCOUNT_PRIVATE_KEY=<from-firebase>
APNS_TEAM_ID=<from-apple-developer>
APNS_KEY_ID=<from-apple-developer>
APNS_PRIVATE_KEY=<from-apple-developer>
APNS_TOPIC=dev.creapolis.pepinillo
```

**Billing (when ready):**
```
GOOGLE_PLAY_PACKAGE_NAME=dev.creapolis.pepinillo
APP_STORE_SERVER_API_BUNDLE_ID=dev.creapolis.pepinillo
```

### 4. Custom Domain
- Add `api.pepinillo.app` in Railway's networking settings
- Add CNAME record in DNS pointing to Railway's provided domain

### 5. GitHub Actions Secret
- Generate a Railway token: `railway login` → `railway tokens create`
- Add `RAILWAY_TOKEN` secret in GitHub repo settings

## CI/CD
- **PRs**: `.github/workflows/test.yml` runs tests automatically
- **Push to main**: `.github/workflows/deploy.yml` runs tests + deploys

## Health Check
```
curl https://api.pepinillo.app/api/v1/health
```

## Rollback
Railway keeps deployment history. Click any previous deployment in the dashboard to rollback.
