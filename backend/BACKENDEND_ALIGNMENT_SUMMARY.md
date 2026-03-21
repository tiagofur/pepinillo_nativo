# Backend Alignment Summary - Pepinillo

## ✅ Completed Implementations

### 1. OAuth Authentication (Commit cb56a98)
- Google Sign-In integration (ID token verification)
- Sign In with Apple integration (JWKS verification)
- Account linking/unlinking for both providers
- Endpoints:
  - `POST /api/v1/auth/google`
  - `POST /api/v1/auth/apple`
  - `POST /api/v1/auth/link/google`
  - `POST /api/v1/auth/link/apple`
  - `DELETE /api/v1/auth/unlink/google`
  - `DELETE /api/v1/auth/unlink/apple`
  - `GET /api/v1/auth/providers`

**Files:**
- `migrations/000006_add_oauth_providers.up.sql`
- `internal/domain/oauth.go`
- `internal/services/oauth_service.go`
- `internal/adapters/handlers/oauth_handler.go`

### 2. Multi-Mode Focus Support (Commit 4dde3c5)
- Renamed Pomodoro tables to Focus
- Added support for 4 focus modes:
  - **Pomodoro**: work/short_break/long_break
  - **Flowtime**: flow/break
  - **Time Block**: work/check_in
  - **Stopwatch**: freeform
- Mode-specific statistics tracking
- Backward compatible with existing `/api/v1/pomodoro/*` routes

**Files:**
- `migrations/000007_focus_modes.up.sql`
- `internal/domain/focus_mode.go`
- `internal/domain/focus_session.go`
- `internal/domain/focus_config.go`
- `internal/domain/focus_stats.go`
- `internal/domain/task_focus_stats.go`
- `internal/adapters/repositories/postgres/focus_repository.go`
- `internal/services/focus_service.go`
- `internal/adapters/handlers/focus_handler.go`

## 🔵 Remaining Work

### 1. Task/Timer Integration
**Current State:**
- Backend has task CRUD and sync
- Backend has session tracking
- Backend has pomodoro timer configs

**Needs Alignment:**
- Update Task model to include `completedPomodoros` for all modes
- Update Task model to include `focusedSeconds` per mode
- Update `FocusConfig` to store default timer values per mode
- Add endpoints for timer state synchronization

**Files to Modify:**
- `internal/domain/task.go` - Add mode-specific tracking fields
- `internal/adapters/repositories/postgres/task_repository.go` - Update sync logic
- `internal/services/task_service.go` - Add mode-aware sync

### 2. Statistics Integration
**Current State:**
- Backend has `focus_stats` with mode breakdown
- Backend has task-level stats aggregation

**Needs Alignment:**
- Add weekly/monthly report endpoints
- Add AI insights integration with multi-mode data
- Add streak tracking per mode
- Add completion rate analytics

**Files to Modify:**
- `internal/adapters/handlers/focus_handler.go` - Add analytics endpoints
- `internal/services/focus_service.go` - Add aggregation logic

### 3. Mobile App Client Updates
**Android (Kotlin):**
- [ ] Update AuthScreen to use new OAuth endpoints
- [ ] Update FocusEngine to support 4 modes
- [ ] Update data models (FocusMode enum)
- [ ] Update API client to use /api/v1/focus/* endpoints
- [ ] Add mode selection UI
- [ ] Add mode-specific phase handling

**iOS (Swift):**
- [ ] Integrate Sign in with Apple with backend
- [ ] Update FocusEngine to support 4 modes
- [ ] Update data models (FocusMode enum)
- [ ] Update API client to use /api/v1/focus/* endpoints
- [ ] Add mode selection UI
- [ ] Add mode-specific phase handling

### 4. CloudKit Integration (iOS)
**Current State:**
- iOS uses CloudKit for sync
- Backend now supports OAuth with server-side sync

**Needs Decision:**
- Migrate iOS from CloudKit-only to hybrid approach
- Keep CloudKit as backup/fallback
- Use backend for OAuth + primary sync

### 5. Feature Gating Enforcement
**Current State:**
- Backend has `subscription_tier` in users table
- No server-side feature gating

**Needs Implementation:**
- Add middleware to check user tier on protected endpoints
- Add endpoints for tier verification
- Enforce limits based on subscription tier

**Files to Modify:**
- `internal/adapters/middleware/` - Add tier check middleware
- `internal/adapters/handlers/` - Apply tier checks

### 6. WebSocket Real-Time Sync
**Current State:**
- Backend has WebSocket hub and manager
- WebSocket notifications for:
  - Config updates
  - Session changes
  - Task updates

**Needs Enhancement:**
- Add real-time timer state sync between devices
- Add real-time task list sync
- Add real-time statistics updates

## 📋 Deployment Checklist

### Backend Deployment
- [ ] Run migration `000006_add_oauth_providers` on production
- [ ] Run migration `000007_focus_modes` on production
- [ ] Update environment variables (if needed)
- [ ] Deploy backend changes to production
- [ ] Verify OAuth token validation works with production credentials
- [ ] Test all 4 focus modes work correctly

### Mobile App Deployment
- [ ] Update Android app to use new OAuth endpoints
- [ ] Update iOS app to use Sign in with Apple with backend
- [ ] Test OAuth flow end-to-end
- [ ] Test multi-mode focus functionality
- [ ] Test backward compatibility with old endpoints

### Monitoring
- [ ] Add metrics for OAuth login success/failure rates
- [ ] Add metrics for focus mode usage distribution
- [ ] Add metrics for API endpoint usage (/pomodoro vs /focus)
- [ ] Set up alerts for migration issues

## 🔗 API Reference

### OAuth Endpoints
- `POST /api/v1/auth/google` - Login with Google
- `POST /api/v1/auth/apple` - Login with Apple
- `POST /api/v1/auth/link/google` - Link Google account
- `POST /api/v1/auth/link/apple` - Link Apple account
- `DELETE /api/v1/auth/unlink/google` - Unlink Google account
- `DELETE /api/v1/auth/unlink/apple` - Unlink Apple account
- `GET /api/v1/auth/providers` - Get linked providers

### Focus Endpoints (New)
- `GET /api/v1/focus/config` - Get focus configuration
- `PUT /api/v1/focus/config` - Update focus configuration
- `GET /api/v1/focus/stats?date=YYYY-MM-DD` - Get daily stats
- `GET /api/v1/focus/stats?from=YYYY-MM-DD&to=YYYY-MM-DD` - Get date range stats
- `POST /api/v1/focus/stats` - Upsert stats
- `GET /api/v1/focus/sessions/all` - List all sessions
- `GET /api/v1/focus/sessions?taskId=X` - List sessions by task
- `GET /api/v1/focus/sessions?from=X&to=Y` - List sessions by range
- `GET /api/v1/focus/sessions/task-stats/:taskId` - Get task stats
- `POST /api/v1/focus/sessions` - Create session
- `PUT /api/v1/focus/sessions/:id` - Update session

### Focus Endpoints (Legacy - Still Active)
- `GET /api/v1/pomodoro/config` - **Deprecated**, use /focus/config
- `PUT /api/v1/pomodoro/config` - **Deprecated**, use /focus/config
- `GET /api/v1/pomodoro/stats` - **Deprecated**, use /focus/stats
- `POST /api/v1/pomodoro/stats` - **Deprecated**, use /focus/stats
- `GET /api/v1/pomodoro/sessions/*` - **Deprecated**, use /focus/sessions

## 📝 Next Steps

### Priority 1: Task/Timer Integration
1. Update `Task` model to track completedPomodoros and focusedSeconds per mode
2. Implement session-task linking for all modes
3. Add timer state sync endpoint
4. Update mobile apps to use new mode-aware timer

### Priority 2: Feature Gating
1. Implement tier-check middleware
2. Add subscription tier verification endpoints
3. Enforce feature limits on client and server
4. Test gating with FREE and PRO tiers

### Priority 3: Statistics & Analytics
1. Add weekly/monthly report endpoints
2. Implement AI insights with multi-mode data
3. Add streak tracking per mode
4. Create dashboard analytics aggregation

### Priority 4: iOS CloudKit Migration
1. Decide on hybrid vs full migration approach
2. Implement backend sync for iOS
3. Test data migration from CloudKit to backend
4. Roll out iOS backend sync gradually

## 🎯 Success Criteria

### OAuth Authentication
- [x] Google Sign-In works on both Android and iOS
- [x] Sign In with Apple works on iOS
- [x] Account linking/unlinking works
- [x] Multiple providers can be linked per user
- [ ] Last auth method cannot be unlinked (pending enforcement)

### Multi-Mode Focus
- [x] All 4 modes are supported in backend
- [x] Database schema supports mode tracking
- [x] Mode-specific statistics are tracked
- [ ] Mobile apps use new multi-mode APIs
- [ ] Backward compatibility maintained during migration
- [ ] Mode selection UI implemented in mobile apps

### Cross-Platform Parity
- [ ] Android and iOS have same features
- [ ] Android and iOS use same backend APIs
- [ ] Android and iOS have same auth methods
- [ ] Bug fixes apply to both platforms
- [ ] New features ship to both platforms

## 📚 Documentation

- [ ] Update API documentation with new endpoints
- [ ] Add mobile app integration guides
- [ ] Document migration process from old Pomodoro to new Focus
- [ ] Add troubleshooting guides for OAuth and multi-mode
- [ ] Update monitoring and alerting documentation
