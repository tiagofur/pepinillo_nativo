# Pepinillo API - VPS Deployment Guide

This guide covers deploying the Pepinillo API to a VPS using Docker Compose and GitHub Actions CI/CD.

## Architecture Overview

```
GitHub Actions (CI/CD)
       ↓
    SSH Deploy
       ↓
IONOS VPS (api.ppn.creapolis.dev)
├── Caddy (Reverse Proxy, HTTPS)
│   └── Port 80, 443
├── API Service (Go/Fiber)
│   └── Port 8080 (internal)
├── PostgreSQL 16
│   └── Port 5432 (internal)
└── Redis 7
    └── Port 6379 (internal)
```

## Prerequisites

- IONOS VPS with Docker pre-installed
- Domain: `api.ppn.creapolis.dev` (pointing to VPS IP)
- SSH access to VPS (deploy user recommended)
- GitHub repository with admin access to configure secrets

## Initial VPS Setup (One-Time)

### Step 1: Prepare SSH Access

On your local machine or deployment machine:

```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t ed25519 -f ~/.ssh/pepinillo-deploy -C "pepinillo-api-deploy"

# Copy public key to VPS
ssh-copy-id -i ~/.ssh/pepinillo-deploy deploy@api.ppn.creapolis.dev
```

### Step 2: Configure GitHub Secrets

Go to GitHub repo → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Value |
|------------|-------|
| `SSH_HOST` | VPS IP or domain (e.g., `api.ppn.creapolis.dev`) |
| `SSH_USER` | SSH username (e.g., `deploy`) |
| `SSH_KEY` | Private key content (`cat ~/.ssh/pepinillo-deploy`) |
| `SSH_PORT` | SSH port (default: `22`) |

**⚠️ IMPORTANT:** Never commit private keys or use HTTP auth tokens.

### Step 3: Run VPS Setup Script

SSH into the VPS:

```bash
ssh deploy@api.ppn.creapolis.dev
```

Clone the repository and run setup:

```bash
# Option A: Using deploy key (GitHub SSH)
git clone git@github.com:creapolis/pepinillo-nativo.git /opt/pepinillo-api
cd /opt/pepinillo-api/backend

# Make setup script executable
chmod +x scripts/vps-setup.sh

# Run setup (requires sudo)
sudo ./scripts/vps-setup.sh
```

Or with GitHub token if you prefer HTTPS:

```bash
sudo ./scripts/vps-setup.sh ghp_YOUR_GITHUB_TOKEN /opt/pepinillo-api
```

The script will:
1. Install Docker and Docker Compose (if needed)
2. Clone the repository
3. Create `.env.production` from template
4. Wait for you to fill in secrets
5. Build and start all services
6. Verify health checks

### Step 4: Configure Production Secrets

After setup script creates `.env.production`, edit it with your production secrets:

```bash
nano /opt/pepinillo-api/backend/.env.production
```

**Essential secrets to configure:**

- `JWT_SECRET` - Generate with: `openssl rand -base64 32`
- `POSTGRES_PASSWORD` - Strong password for database
- `SENDGRID_API_KEY` - Email service
- `GOOGLE_PLAY_*` - Android billing
- `APP_STORE_*` - iOS billing
- All other third-party service credentials

Save and restart services:

```bash
cd /opt/pepinillo-api/backend
sudo docker compose -f docker-compose.prod.yml restart api
```

### Step 5: Verify Deployment

Test the health endpoint:

```bash
curl https://api.ppn.creapolis.dev/api/v1/health
```

Expected response: `{"status":"ok"}`

## Automatic Deployments (GitHub Actions)

### How It Works

1. Push changes to `main` branch affecting `backend/**`
2. GitHub Actions runs tests
3. If tests pass, workflow SSHs into VPS
4. On VPS:
   - Pulls latest code from `main`
   - Builds new Docker image
   - Starts services with new image
   - Runs health checks
5. If health check fails, automatically rolls back
6. Deployment completes in ~2 minutes

### Triggering Deployments

Simply push to main:

```bash
git push origin main
```

The workflow triggers automatically. Monitor progress in GitHub Actions tab.

## Service Management

### View Logs

```bash
cd /opt/pepinillo-api/backend

# API logs
docker compose -f docker-compose.prod.yml logs -f api

# Database logs
docker compose -f docker-compose.prod.yml logs -f db

# Redis logs
docker compose -f docker-compose.prod.yml logs -f redis

# All services
docker compose -f docker-compose.prod.yml logs -f
```

### Restart Services

```bash
cd /opt/pepinillo-api/backend

# Restart all services
docker compose -f docker-compose.prod.yml restart

# Restart specific service
docker compose -f docker-compose.prod.yml restart api
```

### Stop Services

```bash
cd /opt/pepinillo-api/backend
docker compose -f docker-compose.prod.yml down
```

### View Running Services

```bash
cd /opt/pepinillo-api/backend
docker compose -f docker-compose.prod.yml ps
```

### Update Code Manually

```bash
cd /opt/pepinillo-api
git pull origin main

cd backend
docker compose -f docker-compose.prod.yml build api
docker compose -f docker-compose.prod.yml up -d
```

## Database Management

### Access Database

```bash
cd /opt/pepinillo-api/backend
docker compose -f docker-compose.prod.yml exec -it db psql -U pepinillo -d pepinillo
```

### Database Backups

PostgreSQL data is persisted in Docker volume `postgres_data`.

**Manual backup:**

```bash
cd /opt/pepinillo-api/backend
docker compose -f docker-compose.prod.yml exec db \
  pg_dump -U pepinillo -d pepinillo \
  > /backups/pepinillo-$(date +%Y%m%d-%H%M%S).sql
```

**Automated backups recommendation:**

Set up a cron job:

```bash
# Edit crontab
crontab -e

# Add backup job (daily at 2 AM)
0 2 * * * cd /opt/pepinillo-api/backend && \
  docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U pepinillo -d pepinillo \
  | gzip > /backups/pepinillo-$(date +\%Y\%m\%d-\%H\%M\%S).sql.gz
```

### Database Restore

```bash
cd /opt/pepinillo-api/backend

# Stop the API service
docker compose -f docker-compose.prod.yml stop api

# Restore from backup
docker compose -f docker-compose.prod.yml exec -T db \
  psql -U pepinillo -d pepinillo < /path/to/backup.sql

# Restart services
docker compose -f docker-compose.prod.yml up -d
```

## Monitoring and Health Checks

### Health Endpoint

The API exposes a health check endpoint:

```bash
curl https://api.ppn.creapolis.dev/api/v1/health
```

### Docker Health Status

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Example output:
```
NAME                    STATUS
pepinillo-api           Up 2 hours (healthy)
pepinillo-db            Up 2 hours (healthy)
pepinillo-redis         Up 2 hours (healthy)
pepinillo-caddy         Up 2 hours
```

### Log Aggregation

All services log to stdout/stderr with JSON formatting (where applicable). You can aggregate logs using:

- **Docker logs driver**: Configured with max-size and max-file for rotation
- **ELK Stack**: Set up Elasticsearch, Logstash, Kibana
- **Datadog/NewRelic**: Configure Docker metrics export
- **CloudWatch**: AWS log aggregation

## Troubleshooting

### API Not Responding

1. Check service status:
   ```bash
   docker compose -f docker-compose.prod.yml ps
   ```

2. View API logs:
   ```bash
   docker compose -f docker-compose.prod.yml logs api
   ```

3. Check health endpoint:
   ```bash
   curl -v http://localhost:8080/api/v1/health
   ```

4. Restart service:
   ```bash
   docker compose -f docker-compose.prod.yml restart api
   ```

### Database Connection Error

1. Check database is running:
   ```bash
   docker compose -f docker-compose.prod.yml exec db pg_isready -U pepinillo
   ```

2. Verify DATABASE_URL in `.env.production`:
   ```bash
   grep DATABASE_URL backend/.env.production
   ```

3. Check database logs:
   ```bash
   docker compose -f docker-compose.prod.yml logs db
   ```

### HTTPS Certificate Issues

Caddy automatically provisions Let's Encrypt certificates. If issues occur:

1. Check Caddy logs:
   ```bash
   docker compose -f docker-compose.prod.yml logs caddy
   ```

2. Verify domain DNS:
   ```bash
   nslookup api.ppn.creapolis.dev
   ```

3. Check certificate:
   ```bash
   docker compose -f docker-compose.prod.yml exec caddy \
     cat /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/api.ppn.creapolis.dev/api.ppn.creapolis.dev.crt | \
     openssl x509 -text -noout
   ```

### Deployment Failed - Rollback

If GitHub Actions deployment fails and the API is unhealthy:

The workflow automatically attempts rollback to the previous image.

To manually rollback:

```bash
cd /opt/pepinillo-api
git log --oneline -5

# Checkout previous commit
git checkout PREVIOUS_COMMIT_SHA

# Rebuild and restart
cd backend
docker compose -f docker-compose.prod.yml build api
docker compose -f docker-compose.prod.yml up -d
```

## Security Considerations

1. **SSH Keys**: Use Ed25519 keys, not RSA
2. **Firewall**: Open only ports 80, 443 to public; SSH on non-standard port recommended
3. **Environment Variables**: Never commit `.env.production`; use GitHub Secrets
4. **Docker Image Scanning**: Scan images for vulnerabilities before pushing
5. **Log Retention**: Monitor disk space; configure log rotation
6. **Database Access**: PostgreSQL only accessible within Docker network, not exposed
7. **Updates**: Regularly update base images (postgres, redis, caddy, golang)

## Performance Tuning

### PostgreSQL Optimization

Edit `docker-compose.prod.yml` to add performance parameters:

```yaml
db:
  environment:
    POSTGRES_INITDB_ARGS: |
      -c max_connections=200
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
```

### Redis Optimization

Adjust memory limits in `docker-compose.prod.yml`:

```yaml
redis:
  command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

### API Scaling

For high traffic, consider:

1. Load balancing multiple API instances
2. CDN for static assets
3. Database read replicas
4. Connection pooling (PgBouncer)

## Useful Commands

```bash
# SSH into VPS
ssh deploy@api.ppn.creapolis.dev

# Navigate to app directory
cd /opt/pepinillo-api/backend

# View all running containers
docker ps

# View all images
docker images | grep pepinillo

# Prune unused Docker resources
docker system prune -a

# View Docker disk usage
docker system df

# Check VPS resources
free -h        # Memory
df -h          # Disk space
top            # CPU usage
```

## Support and Troubleshooting

For issues:

1. Check logs: `docker compose logs -f`
2. Test locally: `cd backend && docker compose -f docker-compose.yml up`
3. Review GitHub Actions workflow output
4. Check IONOS VPS console for system issues

## Related Documentation

- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [PostgreSQL Container](https://hub.docker.com/_/postgres)
- [GitHub Actions](https://docs.github.com/en/actions)
