# VPS Deployment Setup Checklist

Complete this checklist to deploy Pepinillo API to production VPS.

## Phase 1: Pre-Deployment (Local Machine)

- [ ] SSH key pair generated
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/pepinillo-deploy -C "pepinillo-api-deploy"
  ```

- [ ] SSH public key copied to VPS
  ```bash
  ssh-copy-id -i ~/.ssh/pepinillo-deploy deploy@api.ppn.creapolis.dev
  ```

- [ ] SSH connection tested
  ```bash
  ssh -i ~/.ssh/pepinillo-deploy deploy@api.ppn.creapolis.dev
  ```

- [ ] Domain DNS configured
  - Domain: `api.ppn.creapolis.dev`
  - Points to: VPS IP address
  - Verified with: `nslookup api.ppn.creapolis.dev`

- [ ] GitHub repository admin access confirmed

## Phase 2: VPS Initial Setup

- [ ] SSH into VPS as deploy user
  ```bash
  ssh deploy@api.ppn.creapolis.dev
  ```

- [ ] Repository cloned to `/opt/pepinillo-api`
  ```bash
  git clone git@github.com:creapolis/pepinillo-nativo.git /opt/pepinillo-api
  ```

- [ ] Setup script executed
  ```bash
  sudo /opt/pepinillo-api/backend/scripts/vps-setup.sh
  ```

- [ ] `.env.production` file created from template
  ```bash
  ls -l /opt/pepinillo-api/backend/.env.production
  ```

## Phase 3: Environment Configuration

Edit `/opt/pepinillo-api/backend/.env.production` with production values:

### Required Secrets
- [ ] `JWT_SECRET` - Generate with: `openssl rand -base64 32`
- [ ] `POSTGRES_PASSWORD` - Strong, unique password
- [ ] Database URL checked: `postgres://pepinillo:PASSWORD@db:5432/pepinillo?sslmode=disable`
- [ ] Redis URL checked: `redis://redis:6379`

### Email Service
- [ ] `SENDGRID_API_KEY` - From SendGrid dashboard
- [ ] `SENDGRID_FROM_EMAIL` - noreply@pepinillo.app (or your domain)
- [ ] `SENDGRID_FROM_NAME` - Pepinillo

### Android Billing (Google Play)
- [ ] `GOOGLE_PLAY_PACKAGE_NAME` - dev.creapolis.pepinillo
- [ ] `GOOGLE_PLAY_API_TOKEN` - From Google Cloud Console
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` - From service account
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY` - From service account JSON

### iOS Billing (App Store)
- [ ] `APP_STORE_SHARED_SECRET` - From App Store Connect
- [ ] `APP_STORE_SERVER_API_ISSUER_ID` - From App Store Connect
- [ ] `APP_STORE_SERVER_API_KEY_ID` - From App Store Connect
- [ ] `APP_STORE_SERVER_API_PRIVATE_KEY` - From App Store Connect
- [ ] `APP_STORE_SERVER_API_BUNDLE_ID` - dev.creapolis.pepinillo

### RevenueCat (Optional)
- [ ] `REVENUECAT_API_KEY` - From RevenueCat dashboard
- [ ] `REVENUECAT_SECRET_KEY` - From RevenueCat dashboard
- [ ] `REVENUECAT_WEBHOOK_AUTH_TOKEN` - From RevenueCat webhook config

### Push Notifications (Optional)
- [ ] `PUSH_PROVIDER` - noop (or fcm/apns)
- [ ] `FCM_PROJECT_ID` - From Firebase Console (if using FCM)
- [ ] `FCM_SERVICE_ACCOUNT_EMAIL` - From Firebase service account
- [ ] `FCM_SERVICE_ACCOUNT_PRIVATE_KEY` - From Firebase service account
- [ ] `APNS_TEAM_ID` - From Apple Developer (if using APNS)
- [ ] `APNS_KEY_ID` - From Apple Developer
- [ ] `APNS_PRIVATE_KEY` - From Apple Developer
- [ ] `APNS_TOPIC` - dev.creapolis.pepinillo

### Optional Services
- [ ] `LLM_API_KEY` - OpenAI or other LLM provider (if using)
- [ ] `GEMINI_API_KEY` - Google Gemini API key (if using)
- [ ] `MINIO_*` - MinIO credentials (if using external S3)

### Verify Configuration
- [ ] No CHANGEME values remain in `.env.production`
- [ ] All secret values are production-ready
- [ ] Environment file is NOT committed to Git

## Phase 4: Service Startup and Verification

- [ ] Services built and started
  ```bash
  cd /opt/pepinillo-api/backend
  docker compose -f docker-compose.prod.yml build api
  docker compose -f docker-compose.prod.yml up -d
  ```

- [ ] All services are healthy
  ```bash
  docker compose -f docker-compose.prod.yml ps
  # All services should show "healthy" or "Up"
  ```

- [ ] Database is responding
  ```bash
  docker compose -f docker-compose.prod.yml exec db pg_isready -U pepinillo
  ```

- [ ] Redis is responding
  ```bash
  docker compose -f docker-compose.prod.yml exec redis redis-cli ping
  ```

- [ ] API is responding
  ```bash
  curl http://localhost:8080/api/v1/health
  # Should return: {"status":"ok"}
  ```

- [ ] HTTPS is working
  ```bash
  curl https://api.ppn.creapolis.dev/api/v1/health
  # Should return: {"status":"ok"}
  ```

## Phase 5: GitHub Actions Configuration

- [ ] Go to GitHub repo Settings → Secrets and variables → Actions

- [ ] Add `SSH_HOST` secret
  - Value: `api.ppn.creapolis.dev` or VPS IP

- [ ] Add `SSH_USER` secret
  - Value: `deploy` (or your SSH username)

- [ ] Add `SSH_KEY` secret
  - Value: Contents of `~/.ssh/pepinillo-deploy` (private key)
  - Verify with: `cat ~/.ssh/pepinillo-deploy`

- [ ] Add `SSH_PORT` secret (optional)
  - Value: `22` (default) or your custom SSH port

- [ ] Verify secrets are NOT visible in logs
  - GitHub automatically masks secret values

- [ ] Test workflow trigger
  - Make small change to `backend/` and push
  - Monitor GitHub Actions tab
  - Verify deployment succeeds

## Phase 6: Monitoring and Backups

- [ ] Docker logs rotation configured
  - Checked in `docker-compose.prod.yml`
  - max-size: 10m, max-file: 3

- [ ] Database backup script created
  ```bash
  crontab -e
  # Add: 0 2 * * * backup command
  ```

- [ ] SSL certificate renewal verified
  - Caddy auto-renews Let's Encrypt certs
  - Check logs: `docker compose logs caddy`

- [ ] Monitoring set up (optional)
  - Docker metrics exported
  - Log aggregation configured
  - Alerts configured for downtime

## Phase 7: Security Hardening

- [ ] Firewall configured
  - Port 80: Open to all (HTTP redirect)
  - Port 443: Open to all (HTTPS)
  - Port 22: Open only to deployment IPs
  - Other ports: Closed

- [ ] SSH hardening applied
  - Public key authentication only
  - Password authentication disabled
  - Root login disabled
  - SSH on non-standard port (optional)

- [ ] VPS security updates enabled
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y unattended-upgrades
  ```

- [ ] Docker security reviewed
  - Images scanned for vulnerabilities
  - Network isolated (bridge network)
  - No privileged containers

- [ ] Environment variables secured
  - `.env.production` not in Git
  - Permissions: `chmod 600 .env.production`
  - Owned by: deploy user, not root

## Phase 8: Final Verification

- [ ] Health check endpoint responding
  ```bash
  curl -v https://api.ppn.creapolis.dev/api/v1/health
  ```

- [ ] Service logs reviewed for errors
  ```bash
  docker compose logs api | tail -50
  ```

- [ ] Deployment tested with new code push
  - Push small change to `backend/`
  - Verify workflow passes
  - Verify API remains healthy during deploy

- [ ] Rollback procedure tested
  - Review: `git log --oneline -5`
  - Know how to: `git checkout COMMIT` and rebuild

- [ ] Backup procedure tested
  - Manual backup created
  - Backup can be restored

- [ ] On-call documentation completed
  - Saved this checklist
  - Saved DEPLOYMENT.md
  - Know emergency contacts

## Post-Deployment Maintenance

### Weekly
- [ ] Review application logs for errors
- [ ] Monitor VPS disk space
- [ ] Check certificate expiration (should auto-renew)

### Monthly
- [ ] Update Docker images
- [ ] Review security logs
- [ ] Test backup restoration

### Quarterly
- [ ] Full security audit
- [ ] Database optimization review
- [ ] Capacity planning

## Troubleshooting Quick Links

If deployment fails, refer to:

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Full deployment guide
- `docker compose logs` - Service logs
- GitHub Actions workflow output
- VPS system logs: `/var/log/`

## Emergency Contacts

- IONOS Support: [support.ionos.com](https://support.ionos.com)
- GitHub Status: [www.githubstatus.com](https://www.githubstatus.com)
- Let's Encrypt Status: [letsencrypt.status.io](https://letsencrypt.status.io)

---

**Deployment completed on:** _____________ (date)

**Deployed by:** _________________________ (person)

**Notes:** _________________________________________________________________

