#!/bin/bash

##
# VPS Setup Script for Pepinillo API
#
# This script initializes a fresh VPS for running Pepinillo API in production.
# Run this once on the VPS to set up Docker, Docker Compose, clone the repo,
# configure environment, and start all services.
#
# Usage: ./vps-setup.sh [GITHUB_TOKEN] [APP_DIR]
# Example: ./vps-setup.sh ghp_xxxxxxxxxxxx /opt/pepinillo-api
##

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_TOKEN="${1:-}"
APP_DIR="${2:-/opt/pepinillo-api}"
REPO_URL="https://github.com/creapolis/pepinillo-nativo"
REPO_BRANCH="main"

echo -e "${BLUE}=== Pepinillo API VPS Setup ===${NC}"
echo "App directory: $APP_DIR"
echo "Repository: $REPO_URL"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use: sudo ./vps-setup.sh)${NC}"
  exit 1
fi

# Create app directory
echo -e "${BLUE}Creating application directory...${NC}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Check if Docker is installed
echo -e "${BLUE}Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
  echo -e "${RED}Docker not found. Installing Docker...${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
else
  echo -e "${GREEN}Docker is installed: $(docker --version)${NC}"
fi

# Check if Docker Compose plugin is installed
echo -e "${BLUE}Checking Docker Compose plugin...${NC}"
if ! docker compose version &> /dev/null; then
  echo -e "${BLUE}Installing Docker Compose plugin...${NC}"
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
else
  echo -e "${GREEN}Docker Compose is installed: $(docker compose version)${NC}"
fi

# Clone or update the repository
echo -e "${BLUE}Setting up repository...${NC}"
if [ -d .git ]; then
  echo "Repository already exists, pulling latest changes..."
  git pull origin "$REPO_BRANCH"
else
  echo "Cloning repository..."
  if [ -n "$GITHUB_TOKEN" ]; then
    git clone "https://$GITHUB_TOKEN@github.com/creapolis/pepinillo-nativo.git" . 2>&1 | sed "s/$GITHUB_TOKEN/****/g"
  else
    git clone "$REPO_URL.git" .
  fi
  git checkout "$REPO_BRANCH"
fi

# Navigate to backend directory
cd backend

# Check if .env.production exists
if [ ! -f .env.production ]; then
  echo -e "${BLUE}Creating .env.production from template...${NC}"
  if [ -f .env.production.example ]; then
    cp .env.production.example .env.production
    echo -e "${RED}IMPORTANT: Edit $APP_DIR/backend/.env.production with your actual secrets${NC}"
    echo -e "${RED}At minimum, set:${NC}"
    echo -e "${RED}  - JWT_SECRET${NC}"
    echo -e "${RED}  - POSTGRES_PASSWORD${NC}"
    echo -e "${RED}  - All service API keys (SendGrid, Google Play, App Store, etc)${NC}"
    exit 1
  else
    echo -e "${RED}Error: .env.production.example not found${NC}"
    exit 1
  fi
fi

# Verify critical environment variables
echo -e "${BLUE}Verifying .env.production...${NC}"
if ! grep -q "JWT_SECRET=" .env.production || grep -q "JWT_SECRET=CHANGEME" .env.production; then
  echo -e "${RED}Error: JWT_SECRET not set in .env.production${NC}"
  exit 1
fi

if ! grep -q "POSTGRES_PASSWORD=" .env.production || grep -q "POSTGRES_PASSWORD=CHANGEME" .env.production; then
  echo -e "${RED}Error: POSTGRES_PASSWORD not set in .env.production${NC}"
  exit 1
fi

echo -e "${GREEN}Environment variables verified${NC}"

# Create Docker network if it doesn't exist
echo -e "${BLUE}Setting up Docker network...${NC}"
docker network create pepinillo-network 2>/dev/null || true

# Build and start services
echo -e "${BLUE}Building and starting Docker services...${NC}"
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
echo -e "${BLUE}Waiting for services to become healthy...${NC}"
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  DB_HEALTH=$(docker compose -f docker-compose.prod.yml exec -T db pg_isready -U pepinillo -d pepinillo 2>/dev/null || echo "not-ready")
  if [ "$DB_HEALTH" = "accepting connections" ]; then
    echo -e "${GREEN}Database is healthy${NC}"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for database... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo -e "${RED}Database failed to become healthy${NC}"
  exit 1
fi

# Wait for API health check
echo -e "${BLUE}Waiting for API to become healthy...${NC}"
RETRY_COUNT=0

while [ $RETRY_COUNT -lt 30 ]; do
  if docker compose -f docker-compose.prod.yml exec -T api wget --quiet --tries=1 --spider http://localhost:8080/api/v1/health 2>/dev/null; then
    echo -e "${GREEN}API is healthy${NC}"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for API... ($RETRY_COUNT/30)"
  sleep 2
done

if [ $RETRY_COUNT -eq 30 ]; then
  echo -e "${RED}API failed to become healthy. Check logs:${NC}"
  docker compose -f docker-compose.prod.yml logs api
  exit 1
fi

# Wait for Proxy (Caddy)
echo -e "${BLUE}Waiting for Proxy (Caddy) to be ready...${NC}"
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 15 ]; do
  # Check if container is running
  if docker compose -f docker-compose.prod.yml ps caddy --format json | grep -q "\"State\":\"running\""; then
    echo -e "${GREEN}Proxy is ready${NC}"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for proxy... ($RETRY_COUNT/15)"
  sleep 1
done

# Summary
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Application directory: $APP_DIR"
echo "Services running:"
docker compose -f docker-compose.prod.yml ps
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Verify API is responding: curl https://api.ppn.creapolis.dev/api/v1/health"
echo "2. Set up automated backups for volumes: postgres_data, redis_data"
echo "3. Configure DNS to point to this VPS IP"
echo "4. Set up monitoring and log aggregation"
echo "5. Enable automatic security updates (apt)"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "View logs:     docker compose -f docker-compose.prod.yml logs -f"
echo "Restart:       docker compose -f docker-compose.prod.yml restart"
echo "Stop:          docker compose -f docker-compose.prod.yml down"
echo "Update code:   cd $APP_DIR && git pull && docker compose -f docker-compose.prod.yml up -d"
