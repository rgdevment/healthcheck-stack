# === Global Variables ===
ENV_FILE = .env
ENV_EXAMPLE = .env.example
SERVICE_ENV = healthcheck-api/.env
STACK_NAME = internal-net
SHARED_LIBS_DIR = shared-libs

# === ENVIRONMENT ===
sync-env:
	@echo "📦 Syncing .env environment..."
	@test -f $(ENV_FILE) || (echo "⚠️  $(ENV_FILE) not found, creating from example"; cp $(ENV_EXAMPLE) $(ENV_FILE))
	@cp $(ENV_FILE) $(SERVICE_ENV)
	@echo "✅ Environment ready."

shared-libs:
	@echo "📦 Compiling shared libraries under $(SHARED_LIBS_DIR)/ ..."
	@for lib in $$(find $(SHARED_LIBS_DIR) -mindepth 1 -maxdepth 1 -type d); do \
		echo "🔧 Building $$lib..."; \
		cd $$lib && pnpm install --frozen-lockfile && pnpm run build && cd - >/dev/null; \
	done
	@echo "✅ Shared libraries compiled successfully!"

# === DOCKER INFRASTRUCTURE ===
ensure-network:
	docker network inspect $(STACK_NAME) >/dev/null 2>&1 || docker network create $(STACK_NAME)

up:
	@echo "🚀 Starting infrastructure stack..."
	docker compose up -d --build

down:
	@echo "💥 Stopping infrastructure stack..."
	docker compose down -v

restart-api:
	@echo "🔄 Restarting healthcheck-api and mariadb..."
	docker compose restart mariadb healthcheck-api

clean:
	@echo "🧹 Cleaning Docker system..."
	docker system prune -af --volumes

logs:
	docker logs -f healthcheck-api

# === STATUS & MONITORING ===
status:
	@echo "📋 Docker container status:"
	docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "healthcheck-api|mariadb|redis|grafana|prometheus|cloudflared" || true

check:
	@echo "🔎 Checking health endpoint..."
	curl -s https://status.apirest.cl/ | jq || curl -s https://status.apirest.cl/

verify-env:
	@echo "🔍 Comparing .env files..."
	@cmp --silent $(ENV_FILE) $(SERVICE_ENV) && echo "✅ No differences" || echo "❌ Files differ"

# === OPTIONAL ADMINER ===
adminer:
	@echo "🧪 Starting Adminer at http://localhost:8080"
	docker run -d --rm \
		--name adminer \
		--network $(STACK_NAME) \
		-p 8080:8080 adminer

adminer-down:
	@echo "🧹 Stopping Adminer..."
	docker rm -f adminer

# === FULL STACK ===
stack:
	make sync-env
	make ensure-network
	make up
	make status

restart-stack:
	@echo "♻️  Restarting infrastructure stack..."
	$(MAKE) restart-api
	$(MAKE) status

.PHONY: sync-env shared-libs ensure-network up down restart-api clean status check verify-env stack restart-stack adminer adminer-down logs