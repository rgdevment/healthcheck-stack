# === Global Variables ===
ENV_FILE=.env
ENV_EXAMPLE=.env.example
SERVICE_ENV=healthcheck-api/.env
TUNNEL_STATUS=https://status.apirest.cl/
STACK_NAME := internal-net
APPS_DIR := apps
APPS := retrieve-countries indicadores-chile

# === ENVIRONMENT ===
sync-env:
	@echo "📦 Syncing .env environment..."
	@test -f $(ENV_FILE) || (echo "⚠️  $(ENV_FILE) not found, creating from example"; cp $(ENV_EXAMPLE) $(ENV_FILE))
	@cp $(ENV_FILE) $(SERVICE_ENV)
	@echo "✅ Copied $(ENV_FILE) → $(SERVICE_ENV)"

# === DOCKER ===
up:
	@echo "🚀 Starting services with full build..."
	docker compose up -d --build

down:
	@echo "💥 Stopping services and removing volumes..."
	docker compose down -v

restart-api:
	@echo "🔄 Restarting healthcheck-api..."
	docker compose restart healthcheck-api

clean:
	@echo "🧹 Cleaning Docker system (all unused containers, networks, volumes)..."
	docker system prune -af --volumes

# === STATUS & MONITORING ===
status:
	@echo "📋 Docker container status:"
	docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "$(STACK_NAME)|retrieve-countries|indicadores-chile"

check:
	@echo "🔎 Requesting public service status from $(TUNNEL_STATUS)"
	curl -s $(TUNNEL_STATUS) | jq || curl -s $(TUNNEL_STATUS)

verify-env:
	@echo "🔎 Verifying .env sync with $(SERVICE_ENV)..."
	@cmp --silent $(ENV_FILE) $(SERVICE_ENV) && echo "✅ Files are identical" || echo "❌ Differences found"

ensure-network:
	docker network inspect $(STACK_NAME) >/dev/null 2>&1 || docker network create $(STACK_NAME)

# === APPS ===
up-app-%:
	@echo "🚀 Starting app '$*'..."
	cd $(APPS_DIR)/$* && docker compose up -d --build

down-app-%:
	@echo "🛑 Stopping app '$*'..."
	cd $(APPS_DIR)/$* && docker compose down

logs-app-%:
	@echo "📄 Logs for '$*'..."
	docker logs -f $*

up-all-apps:
	@for app in $(APPS); do \
		$(MAKE) up-app-$$app; \
	done

down-all-apps:
	@for app in $(APPS); do \
		$(MAKE) down-app-$$app; \
	done

# === FULL STACK ===
stack:
	make sync-env && make ensure-network && make up && make up-all-apps && make status
