# === Global Variables ===
ENV_FILE=.env
ENV_EXAMPLE=.env.example
SERVICE_ENV=healthcheck-api/.env
TUNNEL_STATUS=https://status.apirest.cl/
STACK_NAME := internal-net
APPS_DIR := apps
APPS := $(shell find $(APPS_DIR) -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)

# === ENVIRONMENT ===
sync-env:
	@echo "📦 Syncing .env environment..."
	@test -f $(ENV_FILE) || (echo "⚠️  $(ENV_FILE) not found, creating from example"; cp $(ENV_EXAMPLE) $(ENV_FILE))
	@cp $(ENV_FILE) $(SERVICE_ENV)
	@echo "✅ Copied $(ENV_FILE) → $(SERVICE_ENV)"

# === DOCKER ===
up:
	@echo "🚀 Starting base stack..."
	docker compose up -d --build

down:
	@echo "💥 Stopping base stack..."
	docker compose down -v

restart-api:
	@echo "🔄 Restarting healthcheck-api..."
	docker compose restart healthcheck-api

clean:
	@echo "🧹 Cleaning Docker system..."
	docker system prune -af --volumes

ensure-network:
	docker network inspect $(STACK_NAME) >/dev/null 2>&1 || docker network create $(STACK_NAME)

# === STATUS & MONITORING ===
status:
	@echo "📋 Docker container status:"
	docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "$(STACK_NAME)|$(APPS)" || true

check:
	@echo "🔎 Checking $(TUNNEL_STATUS)"
	curl -s $(TUNNEL_STATUS) | jq || curl -s $(TUNNEL_STATUS)

verify-env:
	@echo "🔍 Comparing root .env with $(SERVICE_ENV)..."
	@cmp --silent $(ENV_FILE) $(SERVICE_ENV) && echo "✅ No differences" || echo "❌ Files differ"

# === APP TARGETS (Dynamic) ===
up-app-%:
	@echo "🚀 Starting app '$*'..."
	cd $(APPS_DIR)/$* && docker compose up -d --build

down-app-%:
	@echo "🛑 Stopping app '$*'..."
	cd $(APPS_DIR)/$* && docker compose down

logs-app-%:
	@echo "📄 Logs for app '$*'..."
	docker logs -f $*

restart-app-%:
	@echo "🔄 Restarting app '$*'..."
	cd $(APPS_DIR)/$* && docker compose restart

rebuild-app-%:
	@echo "🔧 Rebuilding app '$*'..."
	cd $(APPS_DIR)/$* && docker compose up -d --build

reset-app-%:
	@echo "💥 Resetting app '$*'..."
	cd $(APPS_DIR)/$* && docker compose rm -fs || true
	cd $(APPS_DIR)/$* && docker compose up -d --build

# === BULK APP ACTIONS ===
up-all-apps:
	@for app in $(APPS); do \
		$(MAKE) up-app-$$app; \
	done

down-all-apps:
	@for app in $(APPS); do \
		$(MAKE) down-app-$$app; \
	done

restart-all-apps:
	@for app in $(APPS); do \
		$(MAKE) restart-app-$$app; \
	done

rebuild-all-apps:
	@for app in $(APPS); do \
		$(MAKE) rebuild-app-$$app; \
	done

reset-all-apps:
	@for app in $(APPS); do \
		$(MAKE) reset-app-$$app; \
	done

# === FULL STACK ===
stack:
	make sync-env && make ensure-network && make up && make up-all-apps && make status

restart-stack:
	@echo "♻️  Restarting full stack (infra + apps)..."
	$(MAKE) restart-api
	@for app in $(APPS); do \
		$(MAKE) restart-app-$$app; \
	done
	$(MAKE) status