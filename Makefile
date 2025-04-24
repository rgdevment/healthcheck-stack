# === Global Variables ===
ENV_FILE=.env
ENV_EXAMPLE=.env.example
SERVICE_ENV=healthcheck-api/.env
TUNNEL_STATUS=https://status.apirest.cl/
STACK_NAME := internal-net

# === ENVIRONMENT ===
# Sync root .env with example and copy to healthcheck-api
sync-env:
	@echo "📦 Syncing .env environment..."
	@test -f $(ENV_FILE) || (echo "⚠️  $(ENV_FILE) not found, creating from example"; cp $(ENV_EXAMPLE) $(ENV_FILE))
	@cp $(ENV_FILE) $(SERVICE_ENV)
	@echo "✅ Copied $(ENV_FILE) → $(SERVICE_ENV)"

# === DOCKER ===
# Build and start all services
up:
	@echo "🚀 Starting services with full build..."
	docker-compose up -d --build

# Stop and remove all services and volumes
down:
	@echo "💥 Stopping services and removing volumes..."
	docker-compose down -v

# Restart healthcheck-api container
restart-api:
	@echo "🔄 Restarting healthcheck-api..."
	docker-compose restart healthcheck-api

# Remove unused Docker resources (⚠️ destructive)
clean:
	@echo "🧹 Cleaning Docker system (all unused containers, networks, volumes)..."
	docker system prune -af --volumes

# === STATUS & MONITORING ===
# Show running containers relevant to the stack
status:
	@echo "📋 Docker container status:"
	docker ps --filter name=healthcheck-api --filter name=mariadb --filter name=redis --filter name=mongo-db --filter name=grafana --format "table {{.Names}}\t{{.Status}}"

# Query the public healthcheck endpoint
check:
	@echo "🔎 Requesting public service status from $(TUNNEL_STATUS)"
	curl -s $(TUNNEL_STATUS) | jq || curl -s $(TUNNEL_STATUS)

# Compare .env files between root and service folder
verify-env:
	@echo "🔎 Verifying .env sync with $(SERVICE_ENV)..."
	@cmp --silent $(ENV_FILE) $(SERVICE_ENV) && echo "✅ Files are identical" || echo "❌ Differences found"

ensure-network:
	docker network inspect $(STACK_NAME) >/dev/null 2>&1 || docker network create $(STACK_NAME)

# Full stack setup (env + up + status)
stack:
	make sync-env && make ensure-network && make up && make status
